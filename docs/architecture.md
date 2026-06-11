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
  - 메커니즘(`CountDown`, `Pomodoro`, `SimpleTimer`, `AlarmClock`)은 `Save`/전역을 **모름** — 재사용·테스트 가능
  - 뷰/컨트롤러가 `Save` 를 알고 배선
- **공통 뷰 동작은 `ClockToolView`** (베이스, `extends Control`): `_apply_settings`(카운트다운 표시), `_try_minimize`, `_play_alert`, `_is_active`(virtual override)
- **저장 정책**
  - 세션 duration = **save-on-start** (시작=커밋, "돌린 설정만 저장")
  - 전역 설정 = **save-on-change** (`AppSettings.changed` → `Save` 자동저장 + 뷰 라이브 전파)
  - 알람 = 변경 시 **디바운스 저장(0.5s)**
- **"하나만 보고 일반화 안 함"** → 두 번째 사례에서 베이스 추출
- 알람: UI **12시간+오전/오후**, 내부 **24시간**
- 다국어: 원본문자열=키, 나중에 일괄 `tr()`; 지금은 문장 통째 포맷 유지(조각 연결 금지)
- 미래 서버/sync 대비: 단일 진실(`Save`)·JSON·`version` 필드.
- **안정 ID/타임스탬프는 도입 보류** (Week 2 결정): Todo 도입 시점엔 목적이 가설(sync·참조)에 기대 희미하다고 판단 → 알람처럼 스냅샷 방식으로 간다.
  진짜 도입 트리거 = **항목을 정체성으로 다뤄야 할 때** (① 다른 컨텐츠가 항목을 참조 ② 시간/이벤트 너머 추적: 데일리 반복 리셋·활동로그·서버 sync).
  가장 가까운 트리거는 **Week 3 데일리 체크리스트의 반복 정체성** — 그때 Todo+데일리 두 사례 보고 ID 컨벤션 확정("두 번째 사례에서 추출").
  - **결정(Week 2)**: 항해 일지(Week 6)는 완료 todo를 **스냅샷 복사**(제목·완료·마감일)로 보관, 라이브 태스크 참조 X → 태스크 삭제와 무관, "참조" 트리거 발생 안 함 → ID 계속 불필요. 칸반 보드는 불필요(이력 열람은 일지가 담당).

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
- 씬: `scenes/timer/*.tscn`
- 에셋: `assets/sounds/Piano_Ui_Set{1,2}.wav`, `assets/placeholder/*.svg`

## 다음 작업 (Week 2 · Todo — 레퍼런스 프론트 전체)
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
- **공통 리스트 베이스 추출**: Todo 완성 후 알람과 두 사례 보고 추출("두 번째 사례에서 추출").

> 교훈(Week 2 중반): 범위를 "최소/권장"으로 자꾸 깎아 목업+추후로 미룬 뒤 완료 판정 → 잘못.
> Week N = 그 주에 **착수**하고 분량도 그만큼 걸린다는 의미. 레퍼런스가 곧 산출물 정의다.

## 미룬 항목 (roadmap.md "미룬 항목" 섹션)
- 타이머 스타일 Circle / 자동 최소화 실제 효과(Week 7) / 총 집중시간 추적(Week 4, `focus_finished` 연결) / 알람 전역화(autoload) / 리스트 패턴 추출
