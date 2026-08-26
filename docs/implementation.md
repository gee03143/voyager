# Voyage — Implementation

> 인수인계/컨텍스트 파악용 기술 문서. **상태**를 기록한다(지금 코드에 실제로 있는 것). 계획·백로그는 사용자가 별도 관리(repo 문서 없음), 의도·방향성은 `README.md` 참고.

## 1. 개요

- **엔진**: Godot 4.6 (GDScript)
- **저장소**: `C:\Users\NHN\Documents\voyager`
- **진입점**: `World.tscn`. 좌측 도크(`ButtonGroupNav`)에서 도구 패널을 열고 닫는 구조.
- **디렉터리 구조**:
  - `scripts/` — 도메인별 하위 폴더(`data/`, `timer/`, `todo/`, `habittracker/`, `commonui/`, `util/`, `audio/`, `record/`, `letter/`, `discovery/`, `option/`, `display/`). 일부는 2단계로 더 나뉨 — `record/timeline/`(하루 타임라인·노트 편집기), `record/journal/`(저널·무드·감사일지), `record/graph/`, `timer/focushistory/`
  - `scenes/` — `.tscn` 씬 파일, `scripts/`와 대응하는 하위 구조
  - `localization/` — `translations.csv`
  - `assets/` — `sounds/`, `placeholder/`

## 2. 데이터 계층

### 저장 파일 (6개로 분리, `user://` 하위)
| 파일 | version | 담당 필드 |
|---|---|---|
| `save.json` | 8 | `settings`, `alarms`, `habit_defs`, `habit_weeks`, `voyage`, `letters`, `lexicon` |
| `records.json` | 2 | `activity_log` |
| `journal.json` | 1 | `journal`(`groups`, `docs`) |
| `todo.json` | 1 | `todo_groups` |
| `gratitude.json` | 1 | `gratitude`(`entries`) |
| `mood.json` | 1 | `mood`(`entries`) |

`Save`(autoload, `scripts/data/save.gd`)가 6개 파일을 전부 소유. 파일별로 `save_*()`/`load_*()` 쌍이 독립적으로 존재(`save_game`/`load_game`, `save_records`/`load_records`, `save_journal`/`load_journal`, `save_todo`/`load_todo`, `save_gratitude`/`load_gratitude`, `save_mood`/`load_mood`).

### 저장 트리거
- **시그널 기반**: `settings.changed`/`voyage.changed`/`lexicon.changed`/`letters.changed` → `save_game()`, `activity_log.changed` → `save_records()`, `journal.changed` → `save_journal()`, `gratitude.changed` → `save_gratitude()`, `mood.changed` → `save_mood()`
- **뷰 디바운스 기반**: `todo_view.gd`/`habit_tracker_view.gd`/`alarm_view.gd`가 각자 `SAVE_DEBOUNCE = 0.5`(초)짜리 `one_shot Timer`를 갖고, 변경마다 타이머를 재시작(`start()`) → 만료 시 `Save.save_todo()`(todo) 또는 `Save.save_game()`(habit·alarm) 직접 호출. `journal_view.gd`도 동일 디바운스 상수(0.5)를 가짐.

### 구버전 마이그레이션
`load_game()`에 로직 있음: `todo_groups` 키가 있으면 "todo.json 분리 전" 구버전으로 간주해 마이그레이션(구버전엔 `is_default` 필드가 없어서 첫 그룹을 기본으로 지정). 그마저 없고 `todos`(평평 리스트) 키만 있으면 더 오래된 구조로 취급해 변환.

### 데이터 모델 (`scripts/data/`, 전부 `RefCounted` + `changed` 시그널)
- **`AppSettings`**: 포모(`focus_seconds`/`short_break_seconds`/`long_break_seconds`/`total_focus_count`/`timer_seconds`), 화면(`window_mode`/`window_size`/`fps_focused`/`fps_unfocused`/`always_on_top`), 사운드(`master_volume`/`sound_set`), HUD(`hud_position`/`hud_scale`), 컴패니언 모드 관련(`auto_minimize`/`auto_exit_companion`/`companion_position`) 필드 보유. 키 없으면 기본값 유지하도록 `from_dict`가 설계됨(스키마 진화 대응).
- **`Voyage`**: `total_play_seconds`/`total_focus_seconds`/`voyage_distance`. `add_focus(seconds)`가 `total_focus_seconds` 누적 + `changed` 발신.
- **`ActivityLog`**: `events`(자동 수집 스트림 — `id`/`type`/`ts` + 타입별 payload, 타입 확인됨: `todo`/`pomodoro_session`/`timer`/`journal`/`gratitude`/`mood`) + `play_days`(일자별 누적 플레이초). **습관 완료는 여기 저장 안 함** — `habit_weeks`에서 파생(단일 진실 원칙 실제 적용 사례).
  - `ts` = **완료 시각**. 세션 계열(`pomodoro_session`/`timer`)만 `start_ts`(시작 시각)를 추가로 가짐 — **`start_ts` 유무가 "구간이냐 순간이냐"의 판정 기준**이라, 없는 이벤트에 키를 만들면 안 됨(`from_dict`가 `has()` 가드를 두는 이유).
  - `ts - start_ts` = 일시정지·휴식을 포함한 **실제 벽시계 스팬**. `seconds`는 그와 별개로 **계획된 집중 시간 합계**(`focus_seconds × total_focus_count`)이며 그래프 통계 전용 — 두 값이 다른 게 정상.
  - `from_dict`가 `id`/`ts`/`start_ts`를 int로 정규화(JSON은 숫자를 float으로 돌려줌).
  - **`note`(선택)** — 사용자가 나중에 붙이는 짧은 회고. 이 스트림에서 **유일한 사용자 편집 대상**이며, 통계·그래프 계산엔 절대 안 씀(README의 "뽀모도로 로그 = reflection의 객관적 근거" 원칙 유지 — 객관 수치와 자기보고를 같은 이벤트에 담되 필드로 분리).
	- 읽기/쓰기는 `note_of(id)`/`set_note(id, text)`로만. 빈 노트는 `""`로 저장하지 않고 **키째 제거**(`start_ts`와 같은 "키 유무가 의미" 규칙 — 파일에 빈 문자열이 쌓이지 않게).
	- `set_note`는 값이 이전과 같으면 `changed`를 **안 쏨**. `changed` 한 번이 곧 파일 쓰기인데 노트는 자동 저장이라 호출이 잦기 때문.
	- 습관 파생 이벤트는 `id` 키 자체가 없으므로(아래 "이벤트의 날짜 소속" 참고) 노트 대상이 아님. `_find()`가 `id == 0`에서 즉시 빠져나옴.
  - `add()`는 만들어진 이벤트의 **id를 반환**함(`Journal.add_doc()`과 같은 형태). 현재 소비자는 없고, 컴패니언이 "방금 끝난 세션"을 지목할 때 쓸 자리.
- **`Journal`**: `groups`(`id`/`name`, `group_id 0`=미분류) + `docs`(`id`/`title`/`body`/`group_id`/`ts`) 평평 구조. CRUD 메서드(`add_doc`/`update_doc`/`remove_doc`/`add_group`/...) 보유.
- **`LetterArchive`**: `entries`(`id`/`template_idx`/`subject`/`fact`/`state`/`author`/`ts` — 전보체 형식). `author` 빈 문자열=보낸 것, 아니면 받은 것.
- **`Lexicon`**: `subjects`(해금된 subject key 배열, 영구·안 줄어듦).
- **`Gratitude`**: `entries`(`id`/`date_iso`/`items`(문자열 배열)/`ts`). 하루 1건·항목 수 자유. **날짜 유일성은 뷰(`entry_for_date`)가 보장하고 모델은 미강제** — `Journal`이 중복을 모델에서 막지 않는 것과 같은 원칙.
- **`Mood`**: `entries`(`id`/`ts`/`level`(1~5)/`memo`). 로그형이라 하루 여러 건 허용. `add_entry`/`update_entry`가 `level`을 1~5로 clamp.

⚠️ 이 두 모델과 저널 탭(`scripts/record/journal/` — `JournalDashboard`/`MoodView`/`GratitudeView` 등)의 **뷰 구조는 아직 이 문서에 반영되지 않음**. 데이터 계층 사실(파일·필드·저장 트리거)만 최신화한 상태이고, 탭 구조 서술은 별도 작업으로 남김.

⚠️ **참고**: `letters`/`lexicon`/`voyage.voyage_distance`는 README.md 기준으론 컨셉상 폐기 대상이지만, 이 데이터 모델·저장 경로는 **코드에 아직 그대로 남아있음**(제거 안 됨) — 스키마 정리·마이그레이션은 의도적으로 안 함(letters/lexicon은 편지 UI 제거 후 방치, `voyage_distance`는 `CompanionMode.gd`가 계속 적립해서 쓰는 값이라 죽은 필드 아님).

### 이벤트의 날짜 소속
`Save.activity_entries_for(date_iso)`는 **구간 겹침** 기준으로 고름: `start_day <= date_iso <= end_day`(ISO 문자열 비교 = 날짜순). 자정을 넘긴 세션은 시작일·종료일 **양쪽 목록에 모두** 나옴.

- `start_ts`가 없는 구버전 세션은 `start_day = end_day`로 취급 — 근사 역산값(`ts - seconds`)으로 날짜 소속을 바꾸지 않음(부정확한 값이 소속을 결정하면 안 되므로).
- `record_calendar._recount()`도 같은 기준으로 걸친 날 모두 +1. 다만 **별도 구현**임 — `activity_entries_for`를 안 거치고 `events`를 직접 순회하고, 습관 파생 처리도 두 곳에 중복돼 있음.

⚠️ **반환값은 `events` 안 dict의 참조**(복사 아님, `out.append(e)`). 뷰에서 `e["note"] = ...`처럼 직접 쓰면 값은 바뀌는데 `changed`가 안 나가서 **저장이 누락됨** — 쓰기는 반드시 `ActivityLog`의 메서드를 경유할 것.
⚠️ 습관 파생 이벤트는 여기서 즉석 생성되며 `{ts, type, title}`뿐이라 **`id` 키가 없음**. id로 지목하는 기능(노트 등)의 대상이 될 수 없고, 각 뷰가 `id == 0` 가드를 둬야 함.

### 공통 유틸리티
- **`IdGen`**(`scripts/util/id_gen.gd`): `randi()` 기반 안정 ID 생성기. `fresh(used: Dictionary) -> int`가 `used`(사용 중 id 집합)와 충돌 안 나는 새 id를 반환(0도 제외). `ActivityLog`/`Journal`/`LetterArchive`/`Gratitude`/`Mood`/습관(`Habit._generate_new_id`)이 공통으로 씀.
- **`ActivityFormat`**(`scripts/util/activity_format.gd`, static 전용): 활동 이벤트의 **표시용 포맷 단일 출처**. `ACCENT`(타입별 색)/`accent_of()`, `start_ts_of()`(구버전은 `ts - seconds` 역산, 불가하면 0)/`is_approx()`, `span_text(start_ts, end_ts, day_iso)`(자정 걸침 표기 포함), `session_label()`(포모/타이머 요약), `mmss()`.
  - **`Save`를 봐야 하는 타입(`journal`/`mood`/`gratitude`)은 일부러 안 넣음** — 각 뷰가 자기 문맥에서 처리. 덕분에 이 유틸은 `DateUtil`/`ActivityVocab`에만 의존하는 순수 static으로 유지됨.
  - `DayTimeline`과 `FocusHistory`가 공유. 타이머 히스토리를 만들면서 세션 포맷이 세 벌째가 될 상황이라 그 시점에 추출함.

## 3. 타이밍 인프라

### `TimerManager` (`scripts/timer/timer_manager.gd`, `class_name TimerManager`)
범용 클럭 기반 지속시간 타이머. 내부 `_timers: Dictionary`(id → `{end_ms, remaining_ms, paused, on_finished}`), id는 단순 증가 카운터.

- **`set_timer(duration, on_finished: Callable) -> TimerHandle`**: `end_ms = Time.get_ticks_msec() + duration*1000` 저장.
- **`_process`**: 매 프레임 `now >= end_ms`인 타이머를 찾아 **콜백 실행 전에 먼저 `_timers`에서 제거**(재진입·취소 안전) 후 콜백 호출.
- **`pause`/`resume`**: `pause`는 남은 시간을 `remaining_ms`로 굳히고 플래그만 세움. `resume`은 그 `remaining_ms`로 `end_ms`를 다시 계산. 즉 일시정지 구간은 모노토닉 클럭 계산에서 제외됨.
- 클럭 소스는 전부 `Time.get_ticks_msec()`(모노토닉) — delta 누적 없음.

### `TimerHandle` (`scripts/timer/timer_handle.gd`, `RefCounted`)
`TimerManager` + id를 들고 있는 얇은 래퍼. `remaining()`/`is_valid()`/`pause()`/`is_paused()`/`resume()`/`cancel()`이 전부 매니저 메서드로 위임. 단일 진실은 매니저, 핸들은 편의용 키.

### `Clock` (`scripts/timer/clock.gd`, autoload)
세션 컨트롤러. `Pomodoro`/`SimpleTimer` 인스턴스를 **자식 노드로 상주 소유**(`_ready()`에서 생성, `Save.settings` 값으로 초기화). `current_activity`(Subject key, 휘발성)도 여기서 보유.

- **`active_kind()`**: 포모 우선 → 타이머. `started and not finished`가 진행 중 판정 기준.
- **`is_focusing()`**: 타이머 작동 중이거나, 포모가 FOCUS 구간을 돌리는 중일 때 true.
- **HUD 폴링용 읽기**: `active_time_left()`/`active_total()`/`active_paused()`.
- **HUD 제어용**: `active_toggle()`/`active_skip()`/`active_reset()`.
- **세션 시작 시각 캡처**: `pomodoro.session_started`/`timer.timer_started`를 구독해 `_pomo_start_ts`/`_timer_start_ts`에 보관(휘발성), 완료 시 payload에 `start_ts`로 실어 보내고 0으로 클리어. 두 시그널 모두 **첫 시작에서만 발신**되고 재개는 다른 분기라 세션당 1회가 보장됨. `Pomodoro`/`SimpleTimer`는 무수정 — 메커니즘이 `Save`를 모르는 원칙 유지.
- **완료 시 부수효과** (`_on_focus_finished`/`_on_timer_finished`/`_on_session_completed`):
  - `Save.voyage.add_focus(...)` — 집중 통계 적립
  - `Save.lexicon.unlock_subject(current_activity)` — 활동 어휘 해금
  - `Save.activity_log.add("pomodoro_session" | "timer", {...})` — 기록 시스템에 이벤트 적재
  - `Sound.play_set(Save.settings.sound_set)` — 완료음, 자동 대기 복귀(`build_plan()`/`timer.reset()`)

⚠️ **참고**: `_on_focus_finished`/`_on_timer_finished`가 **`Save.lexicon.unlock_subject()`와 `Save.voyage.add_focus()`를 직접 호출**함 — lexicon/voyage_distance는 데이터만 남아있는 게 아니라 세션 완료 흐름에 실제로 배선되어 있음. 셸 리팩토링 때 이 두 시스템을 걷어내려면 `Clock`의 이 두 콜백도 같이 손봐야 함(단순 방치 불가).

### `Pomodoro` / `SimpleTimer` (`scripts/timer/pomo/`, `scripts/timer/normaltimer/`)
- **`Pomodoro`**: `SegmentType{FOCUS, SHORT_BREAK, LONG_BREAK}` 순서로 계획을 짬(`build_plan()`), 구간마다 `Timers.set_timer()`로 개별 타이머 실행. 시그널: `segment_changed`/`running_changed`/`focus_finished`(구간 종료·스킵 둘 다 발신)/`session_started`/`session_completed`/`plan_built`.
- **`SimpleTimer`**: 단일 구간 카운트다운. 시그널: `timer_started`/`timer_finished`/`running_changed`.
- 둘 다 일시정지/재개 시 `TimerHandle.pause()`/`resume()`으로 위임, 자체 클럭 로직 없음.

### `Alarm` / `AlarmClock` (`scripts/timer/alarm/`)
- **`Alarm`**(데이터, ID 없음·스냅샷): `{hour, minute, enabled, label}`.
- **`AlarmClock`**(autoload로 추정, 전역 상주): 1초 주기 `Timer`로 벽시계 분(`Time.get_time_dict_from_system`)을 폴링. `_last_minute`과 비교해 지난 분 수(`elapsed`)를 계산(자정 넘김도 `%1440`으로 안전 처리). `elapsed`가 `MAX_CATCHUP_MINUTES(2)` 이하면 **놓친 분까지 늦게라도 발화**(fire-late), 그보다 크면 발화 없이 동기화만(묵은 알람 무시). 발화 시 `Sound.play_set()` + `alarm_triggered` 시그널.

## 4. 셸 인프라

### `PopupFrame` (`scripts/commonui/popup_frame.gd`)
`show_scene(scene: PackedScene)`: `PanelPool.get_instance()`로 인스턴스 획득 → `nav_slot` 배선(`attach_nav()`) → `content_box`로 reparent → `on_shown()` 호출(있으면). `close()`: `on_hidden()` 호출(있으면) → `PanelPool`로 다시 reparent(파괴 안 함) → 숨김.

### `PanelPool` (`scripts/util/panel_pool.gd`, autoload)
`_pool: Dictionary`(scene → 인스턴스). 처음 요청 시에만 `instantiate()` + `add_child`, 이후엔 캐시 반환. 파괴/재생성 없음.

### `TabNavSlot` / `ButtonGroupNav` (`scripts/commonui/`)
`TabNavSlot.set_tabs(labels)`가 매번 버튼을 새로 만들고 `ButtonGroupNav`(새 인스턴스)로 묶음. `clear()`가 시그널 연결 해제 + 버튼 파괴 + `ButtonGroupNav` 재생성까지 함께 처리(연결 중복 방지). `ButtonGroupNav`는 Godot `ButtonGroup` 기반, `allow_close`(=`allow_unpress`)로 "재클릭 시 전부 해제" 지원.

### `world.gd` — 현재 루트 씬
`World.tscn`의 루트 스크립트. **현재 코드 기준으로 패럴랙스·배·`voyage_distance` 구동 로직이 그대로 살아있음**:
- `_process`에서 `Clock.is_focusing()`이면 배 속도를 가속, `Save.voyage.voyage_distance`를 매 프레임 적분, 그 값으로 패럴랙스 레이어 `motion_offset` 계산 + 배 bob/rock 애니메이션 + "N leagues" 라벨 갱신.
- 도크 버튼(`dock` 자식 + `voyage_button`/`gear_button`)을 `ButtonGroupNav`로 묶어 `_on_nav_selected`에서 `DYNAMIC_SCENES` 딕셔너리(인덱스→씬, 하드코딩)로 `popup_frame.show_scene()` 호출.
- `companion_button` 클릭 또는 `Save.settings.auto_minimize`가 켜진 상태에서 포커스 세션 시작 시 `_enter_companion()` 자동 호출.

⚠️ **README.md 기준 컴패니언 셸(고정 배너, 배경 없음)과 지금 코드는 다름** — `World.tscn`(현재 `run/main_scene`)엔 패럴랙스·배·항해 거리가 여전히 살아있음. 다만 셸 전환 자체는 착수됨 — 아래 `MainShell` 항목에 Todo/Habit/Timer/Record가 이미 이전됐고, World.tscn의 구 팝업 경로(`ClockTab` 등)도 병행 존재. 아직 `MainShell`이 실제 진입점으로 전환되진 않음(에디터에서 `MainShell.tscn`을 직접 "현재 씬 실행"해서 확인하는 단계).

### `MainShell` (`scripts/main_shell.gd`, `scenes/MainShell.tscn`) — 셸 전환 목표 씬
README.md 기준 새 셸(고정 배너 + 사이드바 + 콘텐츠 영역, NavSlot 없는 콘텐츠 스왑)의 실제 구현체.

- **구조**: `Sidebar`(로고 + `NavList` + 하단 `SettingsButton`·`MiniTimer`) + `MainColumn`(`Banner`(컴패니언 아바타+말풍선) + `BodyRow/ContentArea`). `MiniTimer`는 `Clock` 상태 따라 제목·아이콘·시간·상태 자동 갱신(`mini_timer.gd`) + 아래 미니 위젯 토글 겸함.
- **콘텐츠 스왑**: `_nav`(`ButtonGroupNav`)가 `NavList` 버튼을 인덱스로 관리, `_on_nav_selected(index)`가 `CONTENT_SCENES[index]`를 `PanelPool.get_instance()`로 얻어 `content_area`에 reparent. `PopupFrame`의 `NavSlot`(서브탭) 패턴은 의도적으로 안 씀(롤백 이력 있음).
- **`CONTENT_SCENES`**: `1: Todo`, `2: Habit`, `3: Timer`, `4: Journal`, `5: Record`. NavList 순번은 Home(0)/Todo(1)/Habit(2)/Timer(3)/Journal(4)/Record(5) — **Home(0)만 아직 매핑 안 됨**(빈 화면). 저널이 최상위 nav로 올라오면서 Record의 인덱스가 4→5로 밀렸음.
- **`SettingsButton`(⚙)**: `NavList` 바깥의 별도 형제 노드라 `_nav`에 안 묶여 있음 — **클릭해도 아직 아무 동작 안 함**(미배선).

### `TimerDashboard` (`scenes/timer/TimerDashboard.tscn`) — 카드형 타이머 페이지
`ClockTab.tscn`(팝업용 4탭: 세션/타이머/알람/설정) 전체를 대체하는 게 아니라 **그중 세션·타이머 둘만** 카드 형태로 MainShell용으로 새로 구성한 씬. 루트 자체엔 스크립트 없음(정적 배치).

- 루트 `VBoxContainer` → `Cards`(HBoxContainer, 카드 2장) + `FocusHistory`(아래 항목, 세로 Expand로 남는 공간 전부). 히스토리를 아래에 붙이면서 구 루트(`HBoxContainer`)에서 바뀐 구조.
- 카드 2장(`PomoCard`/`TimerCard`, `PanelContainer` + `panel_bg.tres` 스타일) 각각 헤더(아이콘+제목) + 기존 `PromoTimer.tscn`/`NormalTimer.tscn` 인스턴스를 그대로 재사용(뷰 스크립트 변경 없이 씬 구성만으로 이식됨). 카드 폭은 콘텐츠 기준 자연 크기 — 강제 50/50 아님.
- **카드 높이는 세로 Fill로 통일** — 뽀모 카드가 스피너가 하나 더 많아 원래 더 길었는데, 아래 히스토리와 맞닿는 하단 라인이 어긋나 보여서 높은 쪽에 맞춤. 짧은 타이머 카드엔 그만큼 빈 공간이 생김(향후 프리셋 등이 들어갈 자리).
- **알람·설정(옵션 3종: 자동 최소화/컴패니언 자동 복귀/카운트다운 숨김)은 의도적으로 카드화 안 함** — 기존 `AlarmView`/`SettingsView`·`Save.settings` 필드는 그대로 살아있고 기능도 안 끊김(설정 3종은 향후 폐기 후보로 판단돼 옮길 위치 미정, 보류).
- `card_bg.tres`(화이트+테두리 스타일, `assets/`)는 초안으로 만들었으나 최종적으로 `panel_bg.tres`(사이드바 MiniTimer와 동일 스타일)로 교체되어 **현재 미사용 상태**로 남아있음.

### `FocusHistory` (`scenes/timer/FocusHistory.tscn`, `scripts/timer/focushistory/focus_history.gd`) — 오늘의 집중 목록
`TimerDashboard` 하단에서 **오늘 완료한 세션만** 최근 순으로 나열하고, 각 행에서 노트를 바로 달 수 있는 카드. `Save.activity_entries_for(today)`를 `pomodoro_session`/`timer`로 걸러 쓰므로 신규 데이터는 없음.

- **세션만 올라옴** — Todo·저널·무드는 안 보임. "노트 유도는 세션에만"이라는 정책이 필터 하나로 구조에 박혀 있는 셈(Todo 완료는 하루 수십 번이라 프롬프트 대상이 아님).
- 정렬은 `activity_entries_for`가 시각 오름차순으로 주는 것을 `reverse()` — 최근 것이 위.
- 헤더 우측에 `{n}세션 · {총 집중시간}`. 합계는 `seconds`(계획된 집중 시간) 누계.
- 행 프리팹 `FocusHistoryRow`: 좌측 고정폭 시각열(`span`/`label`) + 우측 노트열. 노트가 없으면 "눌러서 추가" 안내가 흐리게 뜨고, 행 아무 곳이나 클릭하면 `TextEdit`이 열림. 스타일박스는 `note_stream_row.tres`를 공유(코드가 `duplicate()` 후 `border_color`만 accent로 덮음).
- **저장은 `focus_exited` → `note_committed` → `ActivityLog.set_note()`**. Enter=커밋 / Shift+Enter=줄바꿈은 `mood_view.gd`의 관용구를 그대로 따름(`set_input_as_handled()` 후 `insert_text_at_caret("\n")` 또는 `release_focus()`).

⚠️ **편집 중 재빌드 보류**: `activity_log.changed`를 구독해 목록을 다시 그리는데, 노트 저장 자체가 `changed`를 유발하므로 입력 중인 노드가 파괴될 수 있음. `_editing`(행의 `edit.focus_entered`로 세움)이 참이면 `_dirty`만 남기고 재빌드를 미뤘다가, 커밋 후 한 번에 갱신함.

**세션 완료 직후 "메모 남길래?" 유도는 의도적으로 구현하지 않음** — 여기까지가 노트를 *달 수 있는* 기능이고, *유도*는 README의 컴패니언 3축 중 **함께 있음**(세션 방금 종료 → 말 걸기)에 속한다. 카드 안 프롬프트를 만들었다가 컴패니언이 붙으면 같은 일을 하는 UI가 둘이 되므로, 배너가 생길 때 그 자리에서 열도록 남겨둠. 접합점은 `ActivityLog.add()`의 반환 id — `Clock`의 두 완료 콜백에서 그 값을 시그널로 흘리면 됨(구현 중 실제로 넣었다가, 유도를 컴패니언 몫으로 되돌리면서 걷어냄).

### `RecordDashboard` (`scenes/record/RecordDashboard.tscn`) — 카드형 기록 페이지
`RecordPanel.tscn`(팝업용 3탭: 활동/그래프/일지) 전체를 대체하는 게 아니라 **그중 활동·그래프 둘만** MainShell용으로 새로 구성한 씬. 일지는 그 뒤 별도 최상위 탭(`JournalDashboard`)으로 독립했고, 구 `RecordPanel.tscn`의 서브탭도 그대로 남아 있음.

- **구조**: `panel_bg.tres` 카드 하나 안에 `TabNavSlot`(활동/그래프 전환, 외부 주입 없이 직접 소유) + 우측 레일. 우측 레일은 README 와이어프레임(`docs/app-shell-wireframe.svg`)의 점선 우측 패널 개념을 실제 적용한 첫 사례.
- 활동 탭은 좌측 `RecordCalendar` + 우측 `DayTimeline`(구 `RecordView` 평평 리스트를 대체 — 아래 항목).

**우측 레일 = 노트 스트림 ↔ 편집기 두 상태** (구 "한눈에 보기" 요약 타일 3종을 대체):
- 고른 항목이 없으면 `NoteStream`(그날 노트가 달린 활동만 시각순 나열), 타임라인 행을 고르면 `NoteEditor`(그 이벤트 하나의 노트 편집)로 전환. `record_dashboard.gd`의 `_show_editor()`가 둘의 표시를 맞바꿈.
- 구 타일이 하던 일의 행선지: **오늘 활동 건수 → `DayTimeline` 헤더로 흡수**(`render_day` 안에서 계산되므로 선택 날짜와 자동 일치 — 구 타일은 `today_iso()` 고정이라 다른 날을 봐도 안 바뀌는 불일치가 있었음), **오늘 활동 시간 → 타임라인 헤더에 이미 있던 값이라 폐기**, **누적 집중시간 → Graph 탭 상단 타일로 이사**(`graph_view.gd`가 `Save.voyage.changed` 구독).
- `NoteStream`은 `DayTimeline.entries_with_notes()`로 데이터를 받음 — 타임라인이 이미 만들어둔 라벨·색·시각을 재사용해 포맷을 두 번 짜지 않음. 갱신은 `DayTimeline.rendered` 시그널 구독(`render_day` 호출부가 세 곳이라 하나를 빠뜨리지 않도록 시그널로 묶음).
- 스트림 행 클릭 → `view.select_entry(id)`로 타임라인 하이라이트만 동기화하고 `entry_selected`를 재발신하지 않음(되돌아오는 루프 방지).

⚠️ **레일 폭은 라벨의 `custom_minimum_size.x`가 결정함**: Godot Label의 autowrap은 최소 폭이 지정돼야 동작하므로, `Summary`(240)에서 마진·행 여백·스크롤바를 뺀 값을 각 라벨에 직접 박아둠(`TitleLabel` 212 / 스트림 행 라벨 184 / `EmptyLabel` 212). 폭을 바꾸면 **이 값들을 같이 고쳐야 하고**, 하나라도 `Summary`를 넘으면 그 라벨이 레일을 밀어내 타임라인이 좁아짐. autowrap은 반드시 **Arbitrary** — Word는 최소 폭이 "가장 긴 단어"라 공백 없는 긴 한글 제목이 오면 다시 밀려남.

⚠️ **프리팹 인스턴스 `setup()` 호출 순서 주의**: `scene.instantiate()`로 만든 노드는 트리에 들어가기 전엔 `@onready var`가 아직 비어있음(null). `add_child()`로 먼저 트리에 넣은 뒤에 `setup()`을 불러야 함 — 순서를 반대로 하면 `@onready` 참조가 null이라 런타임 에러. `RecordLogRow` 도입 초기에 이 순서를 반대로 해서 크래시가 난 적 있음(`PomoSegmentChip`/`JournalDocRow`는 이미 이 순서를 지키고 있었음). `TimelineBlock`/`TimelinePointRow`/`TimelineHabitChip`/`NoteStreamRow`/`FocusHistoryRow`도 같은 순서를 따름.

### `DayTimeline` (`scenes/record/Timeline/DayTimeline.tscn`) — 하루 타임라인
0~24시 세로 축에 그날 활동을 배치. 구 `RecordView`(평평한 리스트)를 대체하며, `render_day(date_iso)` 인터페이스가 같아서 `RecordDashboard` 쪽은 노드 경로만 바뀌었음.

- **구조**: `Header`(날짜·플레이시간·활동 건수) + `HabitBand`(종일 칩) + `EmptyLabel` + `Scroll/Track`. `Track`은 컨테이너가 아닌 순수 `Control`이라 자식을 앵커·오프셋으로 절대 배치할 수 있음 — `_stretch()`가 폭은 앵커로 트랙에 묶고(빌드 시점 `size`가 0이어도 안전) 세로만 절대값으로 줌.
- **스케일**: `TimelineTrack.HOUR_PX = 60`, 즉 **1분 = 1px**. 24시간 = 1440px. 첫 활동의 정시 눈금으로 스크롤(한 프레임 대기 후 적용).
- **세 가지 표현**: 세션(구간을 아는 것) = 블록 / 나머지 = 점 행 / 습관 = 상단 고정 칩. 습관을 축에 안 올리는 이유는 `habit_weeks`에 날짜만 있고 시각이 없어서(파생 이벤트의 `ts`는 정렬용 센티널 `1 << 62`).
- **인셋**: 점 이벤트의 시각이 어떤 블록 구간 안이면 22px 들여쓰기 — "그 세션 중에 완료했다"를 위치로 표현.
- **밀어내기**: 점 행이 겹치면 아래로 밀어냄(한 행 = `ROW_H` 18px = 18분). 블록 상단 라벨(`LABEL_H`) 구간도 회피 대상.
- **자정 클램프**: 시작이 전날이면 축 상단(0분), 끝이 다음날이면 축 하단(1440분)으로 자름. 잘린 쪽 모서리를 각지게 해 이어짐을 표시하고, 라벨에는 그쪽 날짜를 붙임.
- **근사 블록**: `start_ts` 없는 구버전 세션은 `ts - seconds`로 역산해 그리되 배경·테두리를 옅게 하고 `≈`를 붙임. **파일은 안 고침** — 휴식·일시정지가 빠진 부정확한 값을 영구히 굳히지 않기 위해.

**노트 연동** (활동 노트의 주 진입점):
- 블록·점 행을 클릭하면 `entry_selected(event_id, meta, title)` 발신 → `RecordDashboard`가 레일을 편집기로 전환. 라벨 텍스트(`meta`/`title`)를 시그널에 실어 보내므로 **대시보드가 포맷을 다시 만들지 않음**.
- 노트가 있는 항목은 라벨 앞에 `NOTE_MARK`(`✎`) 접두사. 행에 아이콘 노드를 새로 넣는 대신 텍스트로 처리한 이유는, 점 행이 `text_overrun_behavior`로 끝을 자르고 블록은 라벨이 하나뿐이라 구조를 바꿔야 했기 때문.
- `_entries`(event_id → 노드·라벨·색·ts)를 들고 `_apply_selection()`으로 하이라이트 관리. `entries_with_notes()`가 레일 스트림용 데이터를 만들고, `select_entry(id)`는 외부(스트림)에서 부르는 하이라이트 전용 경로.
- `render_day` 끝에 **`rendered` 시그널** — 레일 스트림 갱신을 여기에 물려둠.
- **같은 날 재빌드면 스크롤 위치 보존**(`keep_scroll`). 노트를 저장할 때마다 `changed` → `render_day`가 돌기 때문에, 없으면 매번 그날 첫 활동으로 튐. 날짜가 바뀔 때만 `_scroll_to_first()`.

**프리팹 3종**(`TimelineBlock`/`TimelinePointRow`/`TimelineHabitChip`, `scenes/record/Timeline/`): `RecordLogRow` 관용구(씬이 구조를 갖고 `setup()`이 값을 채움)를 따름. 스타일박스는 **씬 리소스를 `duplicate()`한 뒤 색만 덮음** — 복제 없이 쓰면 모든 인스턴스가 한 리소스를 공유해 마지막 색이 전부에 적용됨. 여백·모서리·테두리는 씬(인스펙터)에 남아 코드로 새지 않음.

⚠️ **클릭을 받으려면 Mouse Filter를 손봐야 함**: 두 프리팹 모두 원래 루트가 입력을 무시하도록 되어 있어서 Stop으로 바꿨고, `TimelinePointRow`의 자식 `Dot`(Panel)은 기본값이 클릭을 먹는 쪽이라 Ignore로 내려야 함(안 그러면 도트를 정확히 누를 때만 선택이 안 됨). `TimeLabel`/`TextLabel`은 Label 기본값이 무시라 그대로 둠.

⚠️ **현재 코드의 알려진 성질**:
- 블록 최소 높이가 `LABEL_H`(라벨 한 줄, 약 24분)라 **그보다 짧은 세션은 실제보다 길게 보임**. 라벨을 블록 안에 두는 구조의 대가.
- 점 행 밀어내기에 **상한이 없음** — 짧은 시간에 여러 건이 몰리면 축이 그만큼 늘어남.
- 구 `RecordView`가 `RecordPanel.tscn`에 **여전히 인스턴스로 남아 있음**. 자정 걸친 세션이 그 평평한 리스트에는 이틀 모두에 나옴. `_format_event`는 **세션 부분만** `ActivityFormat`으로 합쳐졌고 나머지 타입(todo/journal/mood/gratitude)은 여전히 두 벌 — 구 뷰가 죽은 경로라 의도적으로 안 건드림.
- 블록끼리 시간대가 겹칠 때 **나란히 배치하는 처리가 없음**. 점 행에는 밀어내기가 있지만 블록은 항상 트랙 전체 폭을 쓰므로, 뽀모와 타이머를 겹쳐 돌리면 뒤에 그려진 블록이 앞 블록 위에 올라가 라벨이 뭉개짐.

### 포모도로 타임라인 — 4칩 슬라이딩 윈도우 (`pomodoro_view.gd`)
반복 횟수(N, 최대 12)가 늘어나면 세그먼트 수가 `2N`(FOCUS+SHORT_BREAK 교대 반복 + 마지막 LONG_BREAK)이 되어, 칩을 전부 나열하면 카드 폭을 넘어서는 문제가 있었음 — `_build_window()`가 항상 최대 4칩만 그리도록 재설계됨(구 `_rebuild_timeline`+`_update_chip_states` 대체):

- **슬라이딩 구간**(남은 세그먼트 ≥2): 현재+다음+다다음 실칩 3개 + 나머지 개수를 나타내는 "+N" 칩(`PomoSegmentChip.setup_count()`, 상태 없는 텍스트 전용 칩).
- **꼬리 고정 구간**(끝까지 4개 이하로 남으면): 마지막 4개 세그먼트를 고정 표시, active 표시만 왼쪽→오른쪽으로 이동(칩이 슬라이드/축소되지 않음).
- 진행 중인 칩 추적은 배열 인덱스(`_chips[pomodoro.index]`) 대신 `_active_chip` 참조로 변경(윈도우가 더 이상 세그먼트 인덱스와 1:1이 아니므로).
- `plan_built` 시그널 구독은 제거됨(`build_plan()`이 항상 `segment_changed(0)`를 동반 발신하므로 중복 리빌드 방지 — `pomodoro.gd` 자체는 미수정).

### 미니 위젯 / 컴패니언 모드 (`scripts/main_shell.gd` + `scripts/display/screen.gd`)
**`MainShell` 자체 기능으로 구현됨** — 씬 전환(`change_scene_to_file`) 없이, `MainShell` 안에서 사이드바 콘텐츠만 숨기고 `MiniTimer`만 남기는 방식(구 `CompanionMode.tscn` 씬 전환 방식과 다름).

- **트리거**: `MiniTimer` 안 `ToggleButton`(`HoverReveal`로 호버 시에만 노출) 클릭 → `_on_mini_toggle_pressed()`가 `_mini_mode` 보고 `_enter_mini_widget()`/`_exit_mini_widget()` 중 선택 호출.
- **`_enter_mini_widget()`/`_exit_mini_widget()`**: `MINI_WIDGET_GROUP` 그룹에 없는 `Sidebar` 직계 자식(Logo/NavList/Spacer/SettingsButton)을 일괄 토글(`_set_sidebar_normal_visible`), `MainColumn` 숨김, `Sidebar`를 확장(`size_flags_horizontal`)+가운데 정렬(`alignment`)로 전환. `Sidebar`가 엔진 기본 테마 Panel 스타일에 의존하고 있어서(자체 스타일 없음) 미니 모드일 때만 `StyleBoxEmpty`로 임시 오버라이드(평소 모드 외형은 안 건드림).
- **`Screen.enter_companion()`/`exit_companion()`**: 기존 컴패니언 모드가 쓰던 OS 창 변형 로직(WINDOWED 전환, 280×200 고정, `ALWAYS_ON_TOP`/`BORDERLESS`)을 그대로 재사용 — 씬 종류와 무관한 순수 창 조작이라 재사용 가능했음. clear color 알파 0 / `TRANSPARENT` 플래그(구 배 비주얼용 트릭)는 미니 위젯엔 안 씀 — MiniTimer는 애초에 불투명 사각 위젯이라 필요 없음.
- **듀얼 모니터 대응**: `window_get_current_screen()`은 `window_set_min_size()`/`window_set_size()` 등 크기 변경 직후엔 이미 커진(모니터 경계 넘어간) 창 기준으로 답하므로, 반드시 크기 변경 전에 모니터 인덱스를 미리 캡처해서 이후 재사용해야 함(`enter_companion()`/`exit_companion()` 둘 다 이 패턴). `_restore_companion_position()`은 저장된 위치가 현재 모니터 범위 밖이면(`rect.has_point()`) 폐기하고 기본 위치(현재 모니터 우하단) 사용.
- **위치 저장은 `Screen._save_companion_position()` 한 곳에서만**(퇴장 시점) — `MiniTimer` 자체의 드래그 입력 핸들러에서는 저장 안 함(토글 버튼 클릭이 `HoverReveal`의 `mouse_filter=PASS`로 인해 `MiniTimer.gui_input`에도 같이 전달되는데, 여기서도 저장하면 클릭만 해도 위치가 엉뚱하게 덮어써지는 문제가 있었음).
- **구 `CompanionMode.tscn`/`companion_mode.gd`/`world.gd`의 `_enter_companion()`은 이제 죽은 코드** — `MainShell`에서 도달하는 경로가 없음. 삭제는 안 함(정리는 별도 작업으로 보류).

## 5. 공통 유틸/컴포넌트

### 드래그 재정렬 — `DragHandle` + `ReorderList` (`scripts/commonui/`)
- **`DragHandle`**(`Label`): 행 좌측에 두는 "⋮⋮" 핸들. `_get_drag_data`가 이 노드에만 있어 **핸들에서 시작한 드래그만 허용**(행 전체가 아님). `token`(StringName)으로 어떤 리스트용인지 식별. `enabled=false`면 드래그 비활성 + 숨김(수동 정렬 모드가 아닐 때).
- **`ReorderList`**(`VBoxContainer`): 드롭 대상 컨테이너. 커서 y좌표로 "어느 행의 위/아래 절반"인지 판정해 삽입 인덱스 계산, 파란 인디케이터 선으로 드롭 위치 표시. `token`이 일치하는 드래그만 받음(`_can_drop_data`). **`Save`를 모름** — `reordered(from, to)` 시그널만 쏘고 실제 배열 반영은 호출부(각 뷰) 책임.
- 적용 사례: Todo(태스크·그룹), 알람, 습관 4곳.

### 날짜/기간 — `DateUtil` + `PeriodNav`
- **`DateUtil`**(`scripts/util/due_date_util.gd`, static 전용): 요일정렬(`month_grid`, 월요일 시작), 마감일 상대 표기(`format_due`: 오늘/내일/월-일), 기록용 상대 표기(`format_day`: 오늘/어제), 주 시작일(`monday_iso`), UTC→로컬 변환(`local_day_iso`, 타임존 bias 적용), 로컬 자정 기준 경과 분(`local_minutes`, 타임라인 y좌표용) 등. Todo·기록 캘린더·습관 트래커·그래프뷰 4곳이 공유.
- **`PeriodNav`**(`scripts/commonui/period_nav.gd`): 주/월/년 단위 이전·다음·오늘 네비게이션. 두 모드 지원 — 산술 계산(`_step_arithmetic`, `DateUtil`로 날짜 가감) 또는 **유효 시작일 목록 안에서만 이동**(`set_valid_starts`, 예: 습관처럼 실제 데이터가 있는 주만 넘나들 때). 미래로는 "현재" 이상 못 감(`is_current`면 다음 버튼 비활성).

### 입력 보조 — `LineEditAutoBlur`
바깥 클릭 시 포커스 해제. `LineEdit`이 포커스 잡았을 때만 `_input` 처리를 켜서(`set_process_input`), 평소엔 전역 입력 감시 안 함.

### 시각화
- **`BarChart`**(`scripts/commonui/bar_chart.gd`, `Control`, `_draw()` 기반): 여러 시리즈(`{values, color}`)를 그룹 막대로. `series`/`axis_max` setter가 `queue_redraw()` 트리거. 그래프뷰(플레이시간 vs 집중시간)에서 사용.
- **`TimelineTrack`**(`scripts/record/timeline_track.gd`, `Control`, `_draw()` 기반): 0~24시 눈금선과 시각 라벨만 그림. `HOUR_PX`/`MIN_PX`/`GUTTER`의 **단일 출처**이고, `_ready()`에서 `custom_minimum_size.y`를 24시간분으로 잡음(스케일을 바꾸면 트랙 높이가 따라옴). `resized`에 `queue_redraw`를 걸어 폭 변화에 대응.
- **`SegmentTimeline`**(`scripts/commonui/segment_timeline.gd`): 포모도로 구간(FOCUS/SHORT_BREAK/LONG_BREAK)을 폭이 다른 "필"들로 그림, 완료/현재/대기 상태별 색상. `Pomodoro.SegmentType`에 직접 의존(포모 전용이라 완전 범용은 아님).

### 인터랙션 보조
- **`HoldButton`**(`Button`): 누르고 있으면 게이지가 차오르다 다 차면 `held` 발신, 도중에 떼면 취소. 시간 측정은 `Time.get_ticks_msec()` 기반(틱은 게이지 표시만 — "틱엔 연출만" 원칙 적용 사례). 삭제 확인 등 실수 방지용 인터랙션에 사용.
- **`HoverReveal`**(`RefCounted`, static): 호스트에 마우스 올렸을 때만 지정 컨트롤(보통 버튼)을 노출. 숨김 상태는 `mouse_filter IGNORE`로 클릭이 호스트로 통과하게 함(행 선택 등 하위 동작 유지).

### 알림 — `Notice` (`scripts/commonui/notice.gd`)
`PanelContainer`, `show_notice(text, duration)`로 텍스트 배너를 띄우고 `duration`초 뒤 자동 숨김.

### 위젯 이동/리사이즈 — `WidgetMover` (`scripts/commonui/widget_mover.gd`)
지정한 `target` Control을 `drag_handle`로 드래그 이동, `resize_grip`으로 스케일 조정(`min_scale`~`max_scale`). 화면 밖으로 안 나가게 매 프레임 클램프. `moved`/`resized` 시그널로 최종 값만 알림(저장은 호출부 책임 — 예: HUD 위치/크기를 `AppSettings.hud_position`/`hud_scale`에 반영).

## 6. 다국어(i18n) 구현

### 원칙
원본 문자열을 UPPER_SNAKE_CASE 키로 관리. `localization/translations.csv`는 `keys,ko,en` 3열이며, Godot이 이를 임포트해 `translations.ko/en.translation`을 생성한다 — **CSV만 고치고 리임포트를 안 하면 화면에 키가 그대로 노출됨**(증상으로 바로 알 수 있음). 코드에서 발견되는 키 네이밍 패턴: 도메인 접두사 + 용도. 예: `DATE_MONTH_LABEL`, `RECORD_EVENT_TODO`, `TODO_SORT_MANUAL`, `CLOCK_POMO_FOCUS`, `HABIT_NEW_NAME`, `PERIOD_NAV_THIS_WEEK`. 동적 값은 문장 전체를 키로 갖고 `.format({...})`로 채움(조각을 이어붙이지 않음).

활동 노트 관련 키군: `RECORD_NOTE_BACK`/`RECORD_NOTE_CLEAR`/`RECORD_NOTE_PLACEHOLDER`(레일 편집기), `RECORD_NOTE_STREAM_TITLE`/`RECORD_NOTE_STREAM_EMPTY`(레일 스트림), `RECORD_DAY_COUNT`(타임라인 헤더 건수), `TIMER_HISTORY_*`(오늘의 집중 목록). `At a glance` 해체로 `RECORD_SUMMARY_TITLE`/`RECORD_TODAY_COUNT`/`RECORD_TODAY_COUNT_VALUE`/`RECORD_TODAY_TIME`은 **미사용**이 됨(`RECORD_TOTAL_FOCUS`는 Graph 탭 타일에서 계속 씀).

자정을 넘긴 구간 표기는 **다른 날인 쪽에만 날짜를 붙임** — `RECORD_SPAN_CROSSDAY`(`{day} {start}–{end}`, 시작이 다른 날), `RECORD_SPAN_CROSSDAY_END`(`{start}–{day} {end}`, 끝이 다른 날). 같은 날 안에서 끝나는 구간은 키 없이 `%s–%s`로 조립함(대시 하나는 언어 무관, 날짜와 시각의 어순은 언어 의존이라 그쪽만 키로 뺌).

### `TranslationServer.translate()` vs `tr()` — 실제 사용 분포
- **`TranslationServer.translate()`**: 15개 파일에서 확인됨. `DateUtil`(static 전용 유틸)·`TodoSort`처럼 **static 함수/`RefCounted`(비-Node) 클래스**에서 특히 이 방식을 씀 — `tr()`은 `Object` 인스턴스 메서드라 이런 컨텍스트에서 쓸 수 없기 때문(호출 주체가 없음).
- **`tr()`**: 6개 파일(`voyage_panel.gd`, `tab_nav_slot.gd`, `timer_view.gd`, `pomodoro_view.gd`, `todo_view.gd`, `due_popup.gd`)에서 여전히 직접 사용됨. 전부 `Node`/`Control` 파생 뷰라 인스턴스 메서드 호출이 유효한 컨텍스트.

⚠️ **일관성 참고**: 코드베이스 전체가 `TranslationServer.translate()`로 통일된 건 아니고, Node 컨텍스트에서는 `tr()`도 섞여 쓰이고 있음. 기능상 문제는 없어 보이나(둘 다 Node 컨텍스트에선 동작), 신규 코드 작성 시 어느 쪽을 기본으로 할지는 정해진 규칙이 안 보임 — 필요하면 컨벤션으로 확정할 것.

### `.tscn` 정적 텍스트
정적 `text` 프로퍼티(버튼 라벨 등)는 키 문자열을 그대로 넣어 엔진 auto-translate에 위임하는 방식으로 추정 — `.tscn` 파일 자체는 이번 확인 범위 밖이라 직접 검증은 못 함.
