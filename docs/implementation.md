# Voyage — Implementation

> 인수인계/컨텍스트 파악용 기술 문서. **상태**를 기록한다(지금 코드에 실제로 있는 것). 계획·백로그는 사용자가 별도 관리(repo 문서 없음), 의도·방향성은 `README.md` 참고.

## 1. 개요

- **엔진**: Godot 4.6 (GDScript)
- **저장소**: `C:\Users\NHN\Documents\voyager`
- **진입점**: `World.tscn`. 좌측 도크(`ButtonGroupNav`)에서 도구 패널을 열고 닫는 구조.
- **디렉터리 구조**:
  - `scripts/` — 도메인별 하위 폴더(`data/`, `timer/`, `todo/`, `habittracker/`, `commonui/`, `util/`, `audio/`, `record/`, `letter/`, `discovery/`, `option/`, `display/`)
  - `scenes/` — `.tscn` 씬 파일, `scripts/`와 대응하는 하위 구조
  - `localization/` — `translations.csv`
  - `assets/` — `sounds/`, `placeholder/`

## 2. 데이터 계층

### 저장 파일 (4개로 분리, `user://` 하위)
| 파일 | version | 담당 필드 |
|---|---|---|
| `save.json` | 8 | `settings`, `alarms`, `habit_defs`, `habit_weeks`, `voyage`, `letters`, `lexicon` |
| `records.json` | 1 | `activity_log` |
| `journal.json` | 1 | `journal`(`groups`, `docs`) |
| `todo.json` | 1 | `todo_groups` |

`Save`(autoload, `scripts/data/save.gd`)가 4개 파일을 전부 소유. 파일별로 `save_*()`/`load_*()` 쌍이 독립적으로 존재(`save_game`/`load_game`, `save_records`/`load_records`, `save_journal`/`load_journal`, `save_todo`/`load_todo`).

### 저장 트리거
- **시그널 기반**: `settings.changed`/`voyage.changed`/`lexicon.changed`/`letters.changed` → `save_game()`, `activity_log.changed` → `save_records()`, `journal.changed` → `save_journal()`
- **뷰 디바운스 기반**: `todo_view.gd`/`habit_tracker_view.gd`/`alarm_view.gd`가 각자 `SAVE_DEBOUNCE = 0.5`(초)짜리 `one_shot Timer`를 갖고, 변경마다 타이머를 재시작(`start()`) → 만료 시 `Save.save_todo()`(todo) 또는 `Save.save_game()`(habit·alarm) 직접 호출. `journal_view.gd`도 동일 디바운스 상수(0.5)를 가짐.

### 구버전 마이그레이션
`load_game()`에 로직 있음: `todo_groups` 키가 있으면 "todo.json 분리 전" 구버전으로 간주해 마이그레이션(구버전엔 `is_default` 필드가 없어서 첫 그룹을 기본으로 지정). 그마저 없고 `todos`(평평 리스트) 키만 있으면 더 오래된 구조로 취급해 변환.

### 데이터 모델 (`scripts/data/`, 전부 `RefCounted` + `changed` 시그널)
- **`AppSettings`**: 포모(`focus_seconds`/`short_break_seconds`/`long_break_seconds`/`total_focus_count`/`timer_seconds`), 화면(`window_mode`/`window_size`/`fps_focused`/`fps_unfocused`/`always_on_top`), 사운드(`master_volume`/`sound_set`), HUD(`hud_position`/`hud_scale`), 컴패니언 모드 관련(`auto_minimize`/`auto_exit_companion`/`companion_position`) 필드 보유. 키 없으면 기본값 유지하도록 `from_dict`가 설계됨(스키마 진화 대응).
- **`Voyage`**: `total_play_seconds`/`total_focus_seconds`/`voyage_distance`. `add_focus(seconds)`가 `total_focus_seconds` 누적 + `changed` 발신.
- **`ActivityLog`**: `events`(자동 수집 스트림 — `id`/`type`/`ts` + 타입별 payload, 타입 확인됨: `todo`/`pomodoro_session`/`timer`/`journal`) + `play_days`(일자별 누적 플레이초). **습관 완료는 여기 저장 안 함** — `habit_weeks`에서 파생(단일 진실 원칙 실제 적용 사례).
- **`Journal`**: `groups`(`id`/`name`, `group_id 0`=미분류) + `docs`(`id`/`title`/`body`/`group_id`/`ts`) 평평 구조. CRUD 메서드(`add_doc`/`update_doc`/`remove_doc`/`add_group`/...) 보유.
- **`LetterArchive`**: `entries`(`id`/`template_idx`/`subject`/`fact`/`state`/`author`/`ts` — 전보체 형식). `author` 빈 문자열=보낸 것, 아니면 받은 것.
- **`Lexicon`**: `subjects`(해금된 subject key 배열, 영구·안 줄어듦).

⚠️ **참고**: `letters`/`lexicon`/`voyage.voyage_distance`는 README.md 기준으론 컨셉상 폐기 대상이지만, 이 데이터 모델·저장 경로는 **코드에 아직 그대로 남아있음**(제거 안 됨) — 스키마 정리·마이그레이션은 의도적으로 안 함(letters/lexicon은 편지 UI 제거 후 방치, `voyage_distance`는 `CompanionMode.gd`가 계속 적립해서 쓰는 값이라 죽은 필드 아님).

### 공통 유틸리티
- **`IdGen`**(`scripts/util/id_gen.gd`): `randi()` 기반 안정 ID 생성기. `fresh(used: Dictionary) -> int`가 `used`(사용 중 id 집합)와 충돌 안 나는 새 id를 반환(0도 제외). `ActivityLog`/`Journal`/`LetterArchive`/습관(`Habit._generate_new_id`)이 공통으로 씀.

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
- **`CONTENT_SCENES`**: `1: TodoListView.tscn`, `2: HabitTrackerView.tscn`, `3: TimerDashboard.tscn`, `4: RecordDashboard.tscn`(이번 세션 추가). NavList 순번은 Home(0)/Todo(1)/Habit(2)/Timer(3)/Record(4) — **Home(0)만 아직 매핑 안 됨**(빈 화면).
- **`SettingsButton`(⚙)**: `NavList` 바깥의 별도 형제 노드라 `_nav`에 안 묶여 있음 — **클릭해도 아직 아무 동작 안 함**(미배선).

### `TimerDashboard` (`scenes/timer/TimerDashboard.tscn`) — 카드형 타이머 페이지
`ClockTab.tscn`(팝업용 4탭: 세션/타이머/알람/설정) 전체를 대체하는 게 아니라 **그중 세션·타이머 둘만** 카드 형태로 MainShell용으로 새로 구성한 씬. 스크립트 없음(정적 배치).

- 루트 `HBoxContainer`(가로 배치, 카드 폭은 콘텐츠 기준 자연 크기 — 강제 50/50 아님), 카드 2장(`PomoCard`/`TimerCard`, `PanelContainer` + `panel_bg.tres` 스타일) 각각 헤더(아이콘+제목) + 기존 `PromoTimer.tscn`/`NormalTimer.tscn` 인스턴스를 그대로 재사용(뷰 스크립트 변경 없이 씬 구성만으로 이식됨).
- **알람·설정(옵션 3종: 자동 최소화/컴패니언 자동 복귀/카운트다운 숨김)은 의도적으로 카드화 안 함** — 기존 `AlarmView`/`SettingsView`·`Save.settings` 필드는 그대로 살아있고 기능도 안 끊김(설정 3종은 향후 폐기 후보로 판단돼 옮길 위치 미정, 보류).
- `card_bg.tres`(화이트+테두리 스타일, `assets/`)는 초안으로 만들었으나 최종적으로 `panel_bg.tres`(사이드바 MiniTimer와 동일 스타일)로 교체되어 **현재 미사용 상태**로 남아있음.

### `RecordDashboard` (`scenes/record/RecordDashboard.tscn`) — 카드형 기록 페이지
`RecordPanel.tscn`(팝업용 3탭: 활동/그래프/일지) 전체를 대체하는 게 아니라 **그중 활동·그래프 둘만** MainShell용으로 새로 구성한 씬(일지는 이번 세션 범위 밖 — 여전히 구 `RecordPanel.tscn` 서브탭으로만 존재, MainShell 최상위 nav엔 없음).

- **구조**: `panel_bg.tres` 카드 하나 안에 `TabNavSlot`(활동/그래프 전환, 외부 주입 없이 직접 소유) + 우측 "한눈에 보기" 요약 레일. 우측 레일은 README 와이어프레임(`docs/app-shell-wireframe.svg`)의 점선 우측 패널 개념을 실제 적용한 첫 사례.

⚠️ **프리팹 인스턴스 `setup()` 호출 순서 주의**: `scene.instantiate()`로 만든 노드는 트리에 들어가기 전엔 `@onready var`가 아직 비어있음(null). `add_child()`로 먼저 트리에 넣은 뒤에 `setup()`을 불러야 함 — 순서를 반대로 하면 `@onready` 참조가 null이라 런타임 에러. `RecordLogRow` 도입 초기에 이 순서를 반대로 해서 크래시가 난 적 있음(`PomoSegmentChip`/`JournalDocRow`는 이미 이 순서를 지키고 있었음).

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
- **`DateUtil`**(`scripts/util/due_date_util.gd`, static 전용): 요일정렬(`month_grid`, 월요일 시작), 마감일 상대 표기(`format_due`: 오늘/내일/월-일), 기록용 상대 표기(`format_day`: 오늘/어제), 주 시작일(`monday_iso`), UTC→로컬 변환(`local_day_iso`, 타임존 bias 적용) 등. Todo·기록 캘린더·습관 트래커·그래프뷰 4곳이 공유.
- **`PeriodNav`**(`scripts/commonui/period_nav.gd`): 주/월/년 단위 이전·다음·오늘 네비게이션. 두 모드 지원 — 산술 계산(`_step_arithmetic`, `DateUtil`로 날짜 가감) 또는 **유효 시작일 목록 안에서만 이동**(`set_valid_starts`, 예: 습관처럼 실제 데이터가 있는 주만 넘나들 때). 미래로는 "현재" 이상 못 감(`is_current`면 다음 버튼 비활성).

### 입력 보조 — `LineEditAutoBlur`
바깥 클릭 시 포커스 해제. `LineEdit`이 포커스 잡았을 때만 `_input` 처리를 켜서(`set_process_input`), 평소엔 전역 입력 감시 안 함.

### 시각화
- **`BarChart`**(`scripts/commonui/bar_chart.gd`, `Control`, `_draw()` 기반): 여러 시리즈(`{values, color}`)를 그룹 막대로. `series`/`axis_max` setter가 `queue_redraw()` 트리거. 그래프뷰(플레이시간 vs 집중시간)에서 사용.
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
원본 문자열을 UPPER_SNAKE_CASE 키로 관리(`localization/translations.csv`, 실제 CSV는 이번 확인 범위 밖 — 경로만 참고). 코드에서 발견되는 키 네이밍 패턴: 도메인 접두사 + 용도. 예: `DATE_MONTH_LABEL`, `RECORD_EVENT_TODO`, `TODO_SORT_MANUAL`, `CLOCK_POMO_FOCUS`, `HABIT_NEW_NAME`, `PERIOD_NAV_THIS_WEEK`. 동적 값은 문장 전체를 키로 갖고 `.format({...})`로 채움(조각을 이어붙이지 않음).

### `TranslationServer.translate()` vs `tr()` — 실제 사용 분포
- **`TranslationServer.translate()`**: 15개 파일에서 확인됨. `DateUtil`(static 전용 유틸)·`TodoSort`처럼 **static 함수/`RefCounted`(비-Node) 클래스**에서 특히 이 방식을 씀 — `tr()`은 `Object` 인스턴스 메서드라 이런 컨텍스트에서 쓸 수 없기 때문(호출 주체가 없음).
- **`tr()`**: 6개 파일(`voyage_panel.gd`, `tab_nav_slot.gd`, `timer_view.gd`, `pomodoro_view.gd`, `todo_view.gd`, `due_popup.gd`)에서 여전히 직접 사용됨. 전부 `Node`/`Control` 파생 뷰라 인스턴스 메서드 호출이 유효한 컨텍스트.

⚠️ **일관성 참고**: 코드베이스 전체가 `TranslationServer.translate()`로 통일된 건 아니고, Node 컨텍스트에서는 `tr()`도 섞여 쓰이고 있음. 기능상 문제는 없어 보이나(둘 다 Node 컨텍스트에선 동작), 신규 코드 작성 시 어느 쪽을 기본으로 할지는 정해진 규칙이 안 보임 — 필요하면 컨벤션으로 확정할 것.

### `.tscn` 정적 텍스트
정적 `text` 프로퍼티(버튼 라벨 등)는 키 문자열을 그대로 넣어 엔진 auto-translate에 위임하는 방식으로 추정 — `.tscn` 파일 자체는 이번 확인 범위 밖이라 직접 검증은 못 함.
