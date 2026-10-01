---
status: planned
---
# 개발자 콘솔과 샌드박스

디버그 실행에서만 열리는 명령 입력 창과, 실제 기록에 닿지 않는 테스트 저장 폴더. 저장 파일을 손으로 고치지 않고 테스트 상태를 만든다.

## 동작

### 샌드박스

- 실행 인자 셋 중 하나로 고른다. 저장 위치가 실제 폴더 대신 `user://sandbox/`가 된다
  - `--sandbox-empty` — 기록 없이 시작한다. 온보딩은 본 것으로 치고 바로 평소 화면으로 뜬다
  - `--sandbox-copy` — 지금 실제 기록의 복사본으로 시작한다
  - `--sandbox-onboarding` — 기록 없이 시작하고 온보딩부터 재생한다
- **실행할 때마다 새로 시작한다.** 앞선 샌드박스 실행에서 바꾼 것은 다음 실행에 이어지지 않는다(2026-10-01 유저 결정)
- 여럿 주면 `--sandbox-onboarding`, `--sandbox-empty`, `--sandbox-copy` 순으로 앞의 것을 따른다. 실제 기록을 읽지 않는 쪽이 앞이다
- 예전 인자 `--sandbox`는 `--sandbox-copy`로 읽는다. 모르는 인자로 두면 아무 표시 없이 실제 폴더로 뜨기 때문이다
- 인자를 비우면 평소처럼 실제 폴더를 쓴다
- 에디터에서는 디버그 메뉴의 「여러 인스턴스 실행」(Customize Run Instances) 창 맨 위 「메인 실행 인자」에 적는다. 프로젝트 설정 `editor/run/main_run_args`와 같은 값이다
- 에디터 상단 툴바(실행 버튼 옆)의 실행 모드 드롭다운으로 고를 수도 있다. 「샌드박스 · 빈 상태 / 샌드박스 · 복사본 / 온보딩부터」 셋이다
- 드롭다운에는 실제 기록으로 띄우는 항목이 없다(2026-10-01 유저 결정). 실제 기록으로 띄우려면 「여러 인스턴스 실행」 창의 메인 실행 인자를 비운다
  - 고르면 메인 실행 인자가 그 값으로 바뀐다. 인자가 비어 있으면 「실제 기록 (인자 없음)」, 다른 값이면 「직접 입력」을 보여준다
  - 에디터 플러그인이라 처음 한 번은 프로젝트 설정 → 플러그인 탭에서 켜야 한다
- ⚠️ 이 값은 F5를 누르는 순간 읽힌다. 이미 떠 있는 실행에는 나중에 바꾼 값이 적용되지 않는다(엔진 소스 `run_instances_dialog.cpp`의 `get_argument_list_for_instance`)
- 디버그 실행에서만 동작한다. 내보낸 빌드는 인자를 무시하고 실제 폴더를 쓴다
- 실제 파일은 복사할 때 읽기만 한다. 샌드박스 동안 실제 폴더의 저장 파일은 한 번도 쓰이지 않는다
- 샌드박스 동안 셸 창 제목에 `[샌드박스 · 빈 상태]`, `[샌드박스 · 복사본]`, `[샌드박스 · 온보딩]` 중 하나가 붙는다. 날짜를 옮겼으면 그 날짜도 붙는다

### 콘솔 열기

- 디버그 실행(에디터 F5·F6)에서만 있다. 내보낸 빌드에는 없다
- 셸 창에서 `F12`를 누르면 열리고 닫힌다
- 셸 창 아래쪽에 입력 줄 하나와 출력 몇 줄이 겹쳐 뜬다. 뒤의 도구는 그대로 보인다
- 열리면 입력 줄에 바로 쓸 수 있다. `Enter`로 실행하고 `Esc`로 닫는다
- 위·아래 화살표로 앞서 친 명령을 다시 부른다

### 명령

- `help` — 명령 목록
- `clear` — 출력을 지운다
- `onboarding reset` / `onboarding done` — 온보딩을 안 본·본 상태로 저장한다. 재시작하면 적용된다. 샌드박스에서는 다음 실행이 새로 시작되므로 남지 않는다
- `nickname <이름>` / `nickname clear` — 호칭을 바꾸거나 지운다. 재시작하면 적용된다. 샌드박스에서는 남지 않는다
- `backup` — 지금 쓰는 저장 파일 여섯 개를 시각 이름의 폴더에 복사하고 경로를 출력한다
- `date` — 앱이 보는 오늘과 옮긴 일수를 출력한다
- `date +<n>` / `date -<n>` — 오늘을 n일 뒤·앞으로 옮긴다
- `date <YYYY-MM-DD>` — 오늘을 그 날짜로 옮긴다
- `date off` — 실제 오늘로 돌아온다
- `sandbox` — 샌드박스 종류, 저장 위치, 앱이 받은 실행 인자를 출력한다
- `room shelf <n>` / `room bundles <n>` / `room shelf off` / `room bundles off` — 방의 책장 수첩 수와 트렁크 위 묶음 수를 그 값으로 그려 본다. 92칸·8묶음 상한 확인용이다
- `react todo` / `react habit` — 할 일 완료·습관 체크 반응을 흉내 낸다. 쪽지와 시메지의 수첩 적기 확인용이다

### 날짜 옮기기

- 날짜는 하루 단위로만 옮긴다. 시각은 그대로다. 알람은 영향을 받지 않는다
- 옮긴 날짜는 앱 전체가 본다. 할 일 마감, 습관 주·요일, 기록 달력, 방의 계절, 만난 날, 새로 생기는 기록의 시각 전부다
- ⚠️ **샌드박스에서만 동작한다.** 샌드박스가 아니면 `date`는 지금 날짜만 출력하고, 옮기는 명령은 "샌드박스에서만 됩니다"를 출력한다
- 옮긴 날짜는 그 실행 동안에만 유지된다. 재시작하면 실제 오늘로 돌아온다
- 집중 세션이나 타이머가 도는 동안에는 옮기지 않는다. 시작 시각과 지금이 어긋나기 때문이다
- 이미 열려 있는 화면은 다시 열어야 새 날짜로 그려질 수 있다. 확실히 보려면 재시작한다

### 지켜야 할 것

- `room ...`과 `react ...`는 아무것도 저장하지 않는다. 미리보기는 재시작하면 사라진다
- `onboarding`·`nickname`·`backup`은 샌드박스가 아니면 실제 저장 파일에 적용된다. 실제 기록(활동 로그·일지 등)은 건드리지 않는다
- 모르는 명령이나 틀린 인자에는 사용법 한 줄을 출력하고 아무것도 하지 않는다

## 범위 아님

- 실행 중에 온보딩을 바로 다시 재생하는 것. 셸·배너·시메지·할 일 도구를 온보딩 직전 상태로 되돌리는 초기화가 따로 필요하다
- 실행 중에 샌드박스를 켜고 끄는 것. 시작할 때 실행 인자로만 정한다
- 샌드박스를 실행 사이에 이어 쓰는 것
- 재시작을 넘어 날짜를 유지하는 것
- 날짜를 시·분 단위로 옮기는 것
- 날짜를 옮겼을 때 열려 있는 모든 화면을 즉시 다시 그리는 것
- 시메지 창에서 콘솔을 여는 것
- 명령 자동완성, 출력 기록을 파일로 남기는 것

## 메커니즘 영향

### 날짜의 단일 출처

- 앱이 벽시계를 읽는 곳은 `DateUtil`을 거친다. `DateUtil.today_dict()`(로컬 날짜, 요일 포함)와 `DateUtil.now_unix()`(유닉스 초) 둘이다
- 지금 `Time.get_date_dict_from_system()`·`Time.get_unix_time_from_system()`을 직접 부르는 곳(15개 파일, 29곳)을 이 둘로 바꾼다. 시각만 읽는 곳(`get_time_dict_from_system`, 알람)과 시간대(`get_time_zone_from_system`)는 그대로 둔다
- `DateUtil`에 옮긴 일수 `day_offset`(정적 값)을 둔다. 0이면 지금과 똑같이 엔진 값을 그대로 돌려준다
- 옮겼을 때의 로컬 날짜는 `Time.get_date_dict_from_unix_time(now_unix + bias)`로 구한다. 이 함수는 UTC 기준이라 시간대 `bias`(분)를 더해야 한다(2026-10-01 실행 확인)

### 샌드박스

- `Save`의 경로 상수 여섯 개를 파일 이름으로 바꾸고, 폴더는 함수 하나가 정한다. 샌드박스면 `user://sandbox/`, 아니면 `user://`
- 샌드박스 판단은 정적 클래스 `Sandbox`(`scripts/dev/sandbox.gd`)가 한다. 인자는 `OS.get_cmdline_args()`와 `OS.get_cmdline_user_args()`를 둘 다 본다. 인자만 주면 앞쪽, `--` 뒤에 주면 뒤쪽으로 들어온다(실행 확인)
- `Save._ready`가 파일을 읽기 **전에** `Sandbox.prepare()`를 부른다. 샌드박스 폴더의 저장 파일을 지우고, `--sandbox-copy`면 실제 파일을 복사한다
- `--sandbox-empty`의 온보딩 건너뛰기는 `Save._ready`가 파일을 다 읽은 뒤 `settings.onboarded`를 참으로 두는 것이다. 첫 `save_game()`이 그대로 적는다
- 지우는 것은 샌드박스 폴더의 저장 파일 여섯 개뿐이다. `backup`이 만든 폴더는 남는다
- 옮긴 날짜는 `DateUtil.day_offset`(메모리)에만 있다. 파일에 남기지 않는다
- 저장 파일의 구성·형식·`version`은 바뀌지 않는다

### 실행 모드 드롭다운

- 에디터 플러그인 `addons/run_mode/`(`plugin.cfg`, `plugin.gd`)이다. 게임 코드에 들어가지 않는다
- 하는 일은 프로젝트 설정 `editor/run/main_run_args` 값을 바꾸고 저장하는 것뿐이다
- 「여러 인스턴스 실행」 창의 「메인 실행 인자」 칸은 프로젝트 설정의 `settings_changed`를 받아 이 값을 다시 읽는다. 그래서 드롭다운과 창이 어긋나지 않는다(엔진 소스 `run_instances_dialog.cpp`의 `_fetch_main_args`)
- 드롭다운도 `settings_changed`를 받아, 창에서 손으로 바꾼 값을 따라간다
- 프리셋은 `plugin.gd` 맨 위 표 하나다

### 콘솔

- autoload를 추가하지 않는다. 시메지 루트가 셸을 만든 직후, 디버그 실행일 때만 콘솔을 만들어 셸을 넘긴다
  - 콘솔이 필요한 곳은 셸 창뿐이다. autoload로 두면 `project.godot`을 고쳐야 하는데, 에디터가 열려 있으면 에디터가 그 파일을 다시 써서 변경이 사라질 수 있다
- 명령은 `scripts/dev/dev_console.gd`(시메지 루트의 자식), 화면과 키 입력은 `scripts/dev/dev_console_view.gd`(셸 창의 자식)가 맡는다
- 화면을 셸 창의 자식으로 붙이는 이유는 셸 창의 키 입력은 셸 창 안의 노드가 받기 때문이다. `_input`으로 받아 입력 줄에 포커스가 있어도 `F12`·`Esc`가 먹는다
- 셸 창 제목의 샌드박스 표시는 콘솔이 붙을 때 단다. 날짜를 옮기면 다시 단다
- `hazel_room.gd`에 디버그 미리보기 값(책장 수·묶음 수)을 정적 값으로 둔다. 모든 방 인스턴스가 같은 값을 읽는다. 값이 없으면 지금과 같다
- 방은 그룹 `hazel_room`에 든다. 콘솔이 날짜나 미리보기 값을 바꾸면 그룹 전체에 `refresh`를 부른다
- `onboarding`·`nickname`은 `Save.settings`를 바꾸고 `changed`를 쏜다. 전역 설정의 save-on-change 그대로다
- `react`는 `Companion`의 기존 시그널을 가짜 내용으로 쏜다. 활동 로그에 쓰지 않는다(`event_id` 0)

## 관련 파일

- `scripts/dev/dev_console.gd`
- `scripts/dev/dev_console_view.gd`
- `scripts/dev/sandbox.gd`
- `addons/run_mode/plugin.cfg`, `addons/run_mode/plugin.gd` — 실행 모드 드롭다운
- `scripts/shimeji_root.gd` — 콘솔을 붙인다
- `scripts/util/due_date_util.gd` — `DateUtil`
- `scripts/data/save.gd`
- `scripts/room/hazel_room.gd`
- 날짜를 읽는 곳: `scripts/companion/companion.gd`, `scripts/data/activity_log.gd`, `scripts/data/gratitude.gd`, `scripts/data/journal.gd`, `scripts/data/letter_archive.gd`, `scripts/data/mood.gd`, `scripts/habittracker/habit_tracker_view.gd`, `scripts/record/record_calendar.gd`, `scripts/timer/clock.gd`, `scripts/todo/due_calendar.gd`, `scripts/todo/todo.gd`
