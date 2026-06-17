# Voyage 아키텍처 / 현재 상태 메모

> 컨텍스트 압축 후에도 이어가기 위한 핵심 정리. 상세는 코드와 `roadmap.md` 참고.

## 프로젝트
- **Voyage**: Godot 4.6 생산성 앱 (포모도로/Todo + 항해 테마, 데스크톱 컴패니언)
- 경로: `C:\Users\NHN\Documents\voyager`
- 루트 `CLAUDE.md` = 이 프로젝트(Voyage) 규칙. 세션 시작 시 함께 읽을 것
- 사용자: Unreal/C++ 경험 많음, Godot 입문

## 작업 규칙
- 코드는 **사용자가 직접 타이핑** → 코드는 *텍스트로 제시*, `.gd`/`.tscn` 직접 편집 안 함
  (docs/roadmap/에셋 파일은 생성·편집 OK)
- 검토 요청 시 **항상 현재 파일을 다시 읽고** 판단 (캐시 사용 X)
- 한국어 존댓말, 간결, 차근차근(작은 단위), 빌드 전 설계 논의 선호

## 아키텍처 원칙 (확립됨)
- **메커니즘 vs 뷰/컨트롤러 분리**
  - 메커니즘(`Pomodoro`, `SimpleTimer`, `AlarmClock`; 지속시간 타이밍은 `TimerManager`)은 `Save`/전역을 **모름** — 재사용·테스트 가능. (`CountDown`은 `TimerManager`로 대체·삭제됨, Week 4)
  - 뷰/컨트롤러가 `Save` 를 알고 배선
- **공통 뷰 동작은 `ClockToolView`** (베이스, `extends Control`): `_apply_settings`(카운트다운 표시), `_try_minimize`, `_play_alert`, `_is_active`(virtual override)
- **저장 정책**
  - 세션 duration = **save-on-start** (시작=커밋, "돌린 설정만 저장")
  - 전역 설정 = **save-on-change** (`AppSettings.changed` → `Save` 자동저장 + 뷰 라이브 전파)
  - 알람 = 변경 시 **디바운스 저장(0.5s)**
- **"하나만 보고 일반화 안 함"** → 두 번째 사례에서 베이스 추출
- **틱(`_process`)엔 연출만**: 데스크톱 컴패니언이라 백그라운드/최소화에서 `_process`가 throttle/pause될 수 있다. **시간·카운트 등 측정/누적 로직을 틱에서 하지 말 것**(delta 합산 X) → 모노토닉 클럭(`Time.get_ticks_msec()`) 차이로 계산. `ticked` 같은 표시 갱신만 틱 허용. 콜백 발화 자체는 루프 재개 시점에 일어남(지연은 불가피하나 측정값은 클럭이라 정확).
  - **클럭 선택**: 지속시간(duration) 타이머 = **모노토닉**(`Time.get_ticks_msec`, OS 수면 중 멈춤=집중 아님이라 맞음). 벽시계 시각 도달(알람) = **시스템 시각**(`Time.get_time_dict_from_system`).
  - **틱-안전 감사(Week 4 착수 시)**: ① `CountDown`(countdown.gd) = delta 누적형 → **전역 `TimerManager`로 대체**(노드 폐기, 클럭 타이밍은 매니저 코어로 흡수 — 아래 "타이밍 인프라"). ② `AlarmClock` = 클럭 읽기라 드리프트 없으나 1초 폴링이 "매 분 최소 1회 실행" 가정 → 서스펜드로 분 건너뛰면 그 분 알람 유실. **갭 catch-up은 "알람 전역화"에 fire-late 정책과 함께** 보강(지금 아님).
- 알람: UI **12시간+오전/오후**, 내부 **24시간**
- 다국어: 원본문자열=키, 나중에 일괄 `tr()`; 지금은 문장 통째 포맷 유지(조각 연결 금지)
- 미래 서버/sync 대비: 단일 진실(`Save`)·JSON·`version` 필드.
- **안정 ID/타임스탬프는 도입 보류** (Week 2 결정): Todo 도입 시점엔 목적이 가설(sync·참조)에 기대 희미하다고 판단 → 알람처럼 스냅샷 방식으로 간다.
  진짜 도입 트리거 = **항목을 정체성으로 다뤄야 할 때** (① 다른 컨텐츠가 항목을 참조 ② 시간/이벤트 너머 추적: 데일리 반복 리셋·활동로그·서버 sync).
  가장 가까운 트리거는 **Week 3 데일리 체크리스트의 반복 정체성** — 그때 Todo+데일리 두 사례 보고 ID 컨벤션 확정("두 번째 사례에서 추출").
  - **결정(Week 2)**: 항해 일지(Week 6)는 완료 todo를 **스냅샷 복사**(제목·완료·마감일)로 보관, 라이브 태스크 참조 X → 태스크 삭제와 무관, "참조" 트리거 발생 안 함 → ID 계속 불필요. 칸반 보드는 불필요(이력 열람은 일지가 담당).
  - **결정(Week 3)**: 트리거 발생(습관의 주간 반복 정체성·정의 단일출처) → **ID 도입**. 컨벤션 = `randi()` 정수 + 충돌 가드, `Save.habit_defs`의 키. Todo·알람은 계속 스냅샷(ID 없음). 향후 sync 시 로그 항목에도 동일 패턴 검토.

## 현재 상태 — 시계 탭 완성
- **ClockTab**: 좌측 커스텀 nav(`ButtonGroup`) + `TabContainer`(탭바 숨김). `clock_tab.gd` 가 버튼↔페이지를 인덱스로 매핑
- **세션**: `Pomodoro`(유한 계획·skip·타임라인 칩 `PomoSegmentChip`·인라인 설정·save-on-start)
- **타이머**: `SimpleTimer`(시/분/초·영속화)
- **알람**: `Alarm` + `AlarmRow` + `AlarmView`(CRUD·디바운스 저장) + `AlarmClock`(분 단위 벽시계 발화) + `Sound` 재생
- **설정**: `SettingsView`(소리 세트·자동 최소화·카운트다운 숨기기)
- **데이터**: `Save`(autoload, `user://save.json`, version), `AppSettings`(데이터 백), `Sound`(autoload, AudioStreamPlayer)

## 주요 파일
- 데이터: `scripts/data/{save.gd, app_settings.gd}`
- 오디오: `scripts/audio/sound.gd`
- 공통: `scripts/timer/{clock_tool_view.gd, clock_tab.gd, countdown.gd, countdown_display.gd}`
- 포모: `scripts/timer/pomo/{pomodoro.gd, pomodoro_view.gd, pomo_segment_chip.gd}`
- 타이머: `scripts/timer/normaltimer/{simple_timer.gd, timer_view.gd}`
- 알람: `scripts/timer/alarm/{alarm.gd, alarm_clock.gd, alarm_row.gd, alarm_view.gd}`
- Todo: `scripts/todo/{todo.gd, todo_group.gd, todo_view.gd, todo_row.gd, todo_sort.gd, due_popup.gd, group_edit_popup.gd}`
- 공통UI: `scripts/commonui/{drag_handle.gd, reorder_list.gd, line_edit_auto_blur.gd}` · 유틸: `scripts/util/due_date_util.gd`(`DateUtil`)
- 씬: `scenes/timer/*.tscn`, `scenes/todo/*.tscn`
- 에셋: `assets/sounds/Piano_Ui_Set{1,2}.wav`, `assets/placeholder/*.svg`

## Todo (Week 2 — ✅ 완료) — 레퍼런스 프론트 전체
> 상태: ①~⑧ 전 슬라이스 F6 동작. 드래그는 재사용 `DragHandle`/`ReorderList`(`scripts/commonui`)로 추출해 태스크·그룹·알람 3사례 적용. 마감일 표기=`DateUtil`(`scripts/util`), 편집칸 바깥클릭 포커스해제=`LineEditAutoBlur`(`commonui`).
범위 = 레퍼런스 이미지의 **거의 모든 기능이 프론트엔드에서 실제 동작**(백엔드/sync 제외). 한 주 분량.
- **데이터(그룹 기반)**: `Save.todo_groups: Array[TodoGroup]` + `current_group_index`.
  `TodoGroup {name, tasks: Array[Todo], sort_key, sort_desc}` · `Todo {text, done, due_date}`.
  due_date = `"YYYY-MM-DD"` or `""`(없음) — 정렬·표시용 **도메인 필드**(ID/타임스탬프 인프라와 무관).
  ※ 초기엔 평평 리스트로 갈 뻔했으나 다중 그룹이 Week 2에 포함되며 그룹 모델로 정정. 빌드/저장 전이라 마이그레이션 비용 0.
- **기능 전체**: 과제 추가/체크(완료=취소선)/삭제·영속화 / 마감일 설정·표시 / 정렬(조건+오름내림) /
  다중 그룹 전환·CRUD(그룹 편집 팝업, 이미지4) / 드래그 정렬 / 호버 버튼 노출 / 진행도 바 / 스크롤.
- **빌드 순서(가장 작은 슬라이스부터, 각 단계 F6 검증)**: ①평평 데이터(`Save.todos`, `Todo{text,done}`) → ②TodoRow(체크/취소선/삭제) → ③TodoView 단일리스트(추가/영속화/진행도)
  → ④마감일(`Todo.due_date`) → ⑤정렬(조건+방향) → ⑥**다중그룹**(여기서 `Save.todos`→`todo_groups` **리팩토링**, 전환+CRUD 팝업) → ⑦드래그 정렬 → ⑧호버/스크롤.
  ※ 그룹 모델은 도착지이되, 슬라이스 ⑥에서 도입(필요 발생 시 리팩토링 원칙). 슬라이싱=빌드 순서지 범위 축소 아님.
- 뷰는 독립 실행 씬으로 개발, 앱 셸 편입은 Week 4. 저장은 알람과 동일 **스냅샷+디바운스(0.5s)**.
- **패널은 자기 크기를 정의**(`custom_minimum_size`), 앱 창(Window Viewport)과 무관. TodoView는 인게임의 여러 팝업 중 하나 — 전역 창 크기를 바꾸지 말 것. 컴포넌트 조립은 Week 4 앱 셸에서.
- ID/타임스탬프: 여전히 미도입. "추가순 정렬"이 필요해지면 그때 created 도입 검토.
- **데일리 체크리스트(요일 활성화·자정 리셋)는 Week 3 유지** — Todo와 별개 기능.
- **공통 리스트 베이스 추출**: 드래그/재정렬·포커스해제는 `commonui`로 추출 완료(3사례). 추가/삭제·진행도 등 **CRUD 리스트 베이스**는 아직 미추출(TodoView/AlarmView 각자 보유) — 추후 필요 시.

> 교훈(Week 2 중반): 범위를 "최소/권장"으로 자꾸 깎아 목업+추후로 미룬 뒤 완료 판정 → 잘못.
> Week N = 그 주에 **착수**하고 분량도 그만큼 걸린다는 의미. 레퍼런스가 곧 산출물 정의다.

## 습관 트래커 (Week 3 — ✅ 완료) = 데일리 체크리스트
- **UI**: 주간 그리드(요일 열 × 습관 행, 헤더에 요일별 달성도 원형 `RadialProgress`). 셀 좌클릭=완료, **우클릭=요일 활성/비활성**(비활성=흐림+달성도 분모 제외, 체크 이력 보존·재활성 복원). 주 페이지네이션(◀/▶/오늘), 과거 주 **백필** 가능.
- **데이터(엔티티 모델, ID 도입)**:
  - `Save.habit_defs: Array[{id,title,active_days}]` — 습관 **단일출처**(멤버십·순서·이름·활성, 전역) + **표시 주체**(이 목록이 모든 주의 행 결정; 기록 없어도 row 생성 / 목록에 없으면 미표시).
  - `Save.habit_weeks: Array[{week_start, checks:{id:[7]}}]` — **주별 희소 체크**(체크 있는 것만).
  - **id = `randi()` + 충돌 가드**(무상태·재사용 없음). 이름/활성 편집 = `habit_defs` 한 곳만 → 전 주 자동 반영(동기화 루프 없음).
  - 롤오버 = 뷰 열림 시 `DateUtil.monday_iso()` 비교(지연) → 다르면 빈 새 주 append.
- **삭제 = 전역**(defs 제거 → 모든 주에서 사라짐). 정의 주도 표시의 귀결.
- **파일**: `scripts/habittracker/{habit, habit_grid, habit_row, habit_tracker_view, radial_progress}.gd`, `scenes/habittracker/{HabitRow,HabitTrackerView}.tscn`.

## 앱 셸 — 상주 월드 셸 (Week 4, 확정)
> "상주 월드 셸" = **월드가 바탕에 상주하고 도구는 그 위에 뜨는 팝업**인 셸 구조. (이번 논의에서 후보 셋 중 채택안.)
> 4주차에 처음으로 "앱 하나"가 생긴다. 그간 각 뷰는 독립 F6 씬이었고 메인 씬(`GameTitle.tscn`)은 빈 `Node2D`였다.

- **결정 = 상주 월드 셸**: 앱은 "생산성 앱 + 탭"이 아니라 **상주 게임 월드 + 도구 팝업**.
  루트 = 항구·바다·배가 있는 월드 씬(`GameTitle` 교체, 메인 씬). 도구(시계/할일/습관/항해)는 그 위에 뜨는 패널.
  → 기존 "TodoView는 인게임의 여러 팝업 중 하나" 노트(Todo 섹션)의 **공식화**.
  - 검토한 후보 셋: ⑴ **탭 앱**(생산성 앱 + 항해 탭 — 배가 한 탭에만 보임), ⑵ **탭 + 상단 항해 띠**(탭 셸이되 진행이 상단에 상시), ⑶ **상주 월드 셸**(채택). 채택 이유 = 데스크톱 컴패니언 정체성(곁에 상주하며 집중하면 배가 나아가는 세계). Week 7 미니 모드의 실체가 이 월드다.
- **런처**: **좌측 세로 도크**(아이콘 4). 도크의 아이콘↔패널 show/hide 매핑 = `clock_tab.gd` 버튼↔페이지 매핑의 **두 번째 사례** → commonui로 추출해 공용(시계 서브 nav가 첫 사례).
- **패널 정책**: **한 번에 하나**(다른 아이콘=전환). 닫기 = **free 아님, hide 토글** → 돌아가는 타이머·세션 상태 보존.
  패널은 자기 크기 정의(전역 창 크기 안 건드림 — Week 2 결정의 보상). 기존 뷰가 월드 위에 자기 크기로 그대로 떨어진다.
- **상시 타이머 HUD**: 돌아가는 카운트다운은 패널과 **별개로 월드에 상시 표시**(시계 패널 닫아도 째깍). 이게 배 항해의 근거. Todo/습관은 상시 표시 없음(열렸을 때만).
- **active 세션 개념**: 포모·일반 타이머가 동시에 있을 수 있으니, HUD·배를 구동하는 하나 = active. (비전 아님, 슬라이스 3~4 배선 디테일)
- **데이터(슬라이스 ⓪ 범위)**: `Save.voyage` = **`total_play_seconds`(누적 플레이) + `total_focus_seconds`(누적 집중)** 2개만 + **version 4** 마이그레이션. (거리·섬은 지금 미설정 — 슬라이스 ⑤/⑥에서 같은 객체에 추가)
  - `total_focus_seconds` 누적 = **포모 `focus_finished`(집중 단계) + 일반 타이머 완료** 시 (사용자 결정). 메커니즘은 `Save` 모름 유지 → `Save` 아는 뷰/컨트롤러가 배선. 드문 사건 → **즉시 저장**(`changed`→save, save-on-start와 같은 결). 이게 Week 1 미뤄둔 "총 집중시간 persist"의 실체.
  - `total_play_seconds` 누적 = **클럭 기반, `Save`(autoload)가 소유**. 세션 시작 시 `_play_base_seconds=total_play_seconds`·`_session_start_ms=Time.get_ticks_msec()` 기록 → `save_game()` 직전 `total_play_seconds = base + (now-start)/1000` 갱신. 매 프레임 `delta` 누적(X) → 백그라운드/최소화에서 `_process` throttle 돼도 클럭 차이로 정확. 종료 시 `NOTIFICATION_WM_CLOSE_REQUEST`로 마지막 저장.
  - **거리(파생)·발견 섬**: 슬라이스 ⑤/⑥에서 도입. distance = `total_focus_seconds × 환산율`(파생, 단일 진실), 섬 = 지도·도감이 참조 → 안정 ID(`randi` 패턴).
- **빌드 순서(각 단계 F6 검증, 범위 축소 아님)**: **T1**(`Timers`=`TimerManager`+`TimerHandle` autoload) → **T2**(`Clock` autoload + `Pomodoro`→`Timers`·PomodoroView 바인딩·`CountDown` 제거) → **T3**(`SimpleTimer`→`Timers`·TimerView 바인딩) → ⓪데이터 → ①월드 루트 → ②도크+패널 호스트 → ③집중 누적(`focus_finished`+타이머 완료→`total_focus_seconds`) → ④상시 타이머 HUD → ⑤배 반응 + 거리(`distance()` 파생) 도입·해리 배지 → ⑥발견.
  - 배의 "항해 중 라이브 연출"은 폴리시 — Week 4 산출물은 **완료 시 누적**까지. 라이브 애니는 나중.
- **발견 테마 보류(사용자 명시)**: 섬 발견 **트리거·카탈로그·연출**은 게임 테마 논의가 필요 → **슬라이스 ⓪~⑤(월드·도크·항해 누적) 끝낸 뒤 재논의**. Week 4 내 진행 예정이나 지금 착수 작업과는 무관.
- **부수 정리 기회**: 월드가 상주하므로 미뤄둔 **알람 전역화**(autoload 발화)·**데일리 라이브 롤오버**(주 경계 즉시 갱신)의 자리가 생김 — Week 4에 꼭 다 할 필욘 없으나 훅 위치 확보.

## 타이밍 인프라 (TimerManager / Clock — Week 4 foundation)
> 셸의 전제: 진행 중인 타이머가 뷰(패널)와 무관하게 살아있어야 한다. 기존엔 메커니즘이 뷰 자식(`PomodoroView.$Pomodoro`, `TimerView`가 `SimpleTimer` 생성, `AlarmView`가 `AlarmClock` 생성)이라 부적합 → 전역으로 올린다. (사용자=Unreal `FTimerManager` 착안 제안)

- **`Timers` (autoload, `TimerManager extends Node`)** — 범용 클럭 기반 지속시간 타이머 프리미티브.
  - API: `set_timer(duration, on_finished: Callable) -> TimerHandle` / `get_remaining(id)` / `pause·resume·clear(id)` / `is_active(id)`. `TimerHandle`(RefCounted)이 `.remaining()/.pause()/.resume()/.cancel()/.is_valid()`를 매니저에 위임(단일 진실=매니저, 핸들=얇은 키+편의).
  - 타이밍 = 모노토닉(`Time.get_ticks_msec`), **delta 누적 X**. `_process`는 "`now>=end_ms`면 콜백 발화 후 제거"만(클럭 비교; 콜백 발화엔 루프 필요 = 복귀 시 발화하나 측정은 정확). → `CountDown` 노드 폐기, 그 역할이 매니저 코어로.
  - 표시 갱신 = **뷰가 `handle.remaining()` 폴링**(연출=틱 허용). 매니저는 완료 콜백만 — "틱엔 연출만" 유지.
  - **메커니즘 계층**: `Save`/도메인 모름(재사용·테스트 가능). 내장 `Timer`/`SceneTreeTimer`는 클럭-안전 조회·핸들 일시정지/취소가 없어 부적합 → 커스텀 정당.
- **`Clock` (autoload, 세션 컨트롤러)** — `Pomodoro`/`SimpleTimer` 인스턴스 **소유**(뷰에서 분리). `Timers`로 타이밍, active 세션 추적, `focus_finished`/타이머완료 → `Save.voyage.add_focus`(슬라이스 ③). 뷰는 `Clock.pomodoro` 등에 **바인딩**(생성·소유 X), 표시는 폴링. **컨트롤러 계층**: `Save` 앎.
- **영속성 경계(사용자 결정)**: 진행 중 포모/타이머 세션 = **휘발성**(프로세스 종료 시 소멸, Save 직렬화 X). 알람 = **영속**(`Save.alarms`) → 성격이 달라 **`TimerManager`에 귀속 안 함**. `AlarmClock`(벽시계 폴링)은 별도로 두고 "알람 전역화"로 autoload화 + 갭 catch-up.
- **autoload 등록 순서**: `Save`, `Sound`, **`Timers`**, **`Clock`**(Clock이 Timers·Save 참조하므로 뒤).

## 미룬 항목 (roadmap.md "미룬 항목" 섹션)
- 타이머 스타일 Circle / 자동 최소화 실제 효과(Week 7) / 총 집중시간 추적(Week 4, `focus_finished` 연결) / 알람 전역화(autoload) / CRUD 리스트 베이스 추출 / **데일리 라이브 롤오버**(앱 켜둔 채 주 경계 — Week 4 앱 셸 열림 훅).
