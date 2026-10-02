extends Node

## 개발자 콘솔의 명령(docs/specs/dev-console.md). 디버그 실행일 때만 시메지 루트가 만들어 셸 창을 넘긴다.
## 화면과 키 입력은 dev_console_view.gd 가 셸 창 안에서 맡는다. 여기는 줄을 받아 명령을 실행한다.
##
## 저장 값을 바꾸는 명령(onboarding·nickname)은 재시작해야 화면에 반영된다.
## 미리보기 명령(room·react)은 아무것도 저장하지 않는다. 날짜는 샌드박스에서만 옮긴다.

const VIEW_SCRIPT := preload("res://scripts/dev/dev_console_view.gd")
const SANDBOX := preload("res://scripts/dev/sandbox.gd")
const ROOM_SCRIPT := preload("res://scripts/room/hazel_room.gd")
const TASKBAR_PROBE := preload("res://scripts/dev/taskbar_probe.gd")
const SHELL_TITLE := "Voyager"

const HELP := """help · clear
onboarding reset|done        — 재시작하면 적용
nickname <이름>|clear        — 재시작하면 적용
backup                       — 저장 파일 여섯 개를 복사
date [+n|-n|YYYY-MM-DD|off]  — 샌드박스에서만, 이번 실행 동안만
sandbox                      — 샌드박스 종류·저장 위치·받은 실행 인자
room shelf|bundles <n>|off   — 방 미리보기(저장 안 함)
react todo|habit             — 완료 반응 흉내(저장 안 함)
taskbar [status|hide|dance|restore] — 시메지 창의 작업 표시줄 버튼(이번 실행만)"""

var _view: VIEW_SCRIPT
var _shell: Window


func setup(shell: Window) -> void:
	_shell = shell
	_view = VIEW_SCRIPT.new()
	shell.add_child(_view)                       # 셸 창의 키 입력은 셸 창 안의 노드가 받는다
	_view.submitted.connect(_run)
	_update_title()
	if SANDBOX.active():
		_view.print_line("%s · %s" % [_mode_label(), ProjectSettings.globalize_path(SANDBOX.DIR)])


func _run(line: String) -> void:
	var a := line.split(" ", false)
	var cmd := a[0].to_lower()
	var rest := a.slice(1)
	match cmd:
		"help":
			_out(HELP)
		"clear":
			_view.clear_log()
		"onboarding":
			_onboarding(rest)
		"nickname":
			_nickname(line.substr(line.find(" ") + 1).strip_edges() if rest.size() > 0 else "")
		"backup":
			_backup()
		"date":
			_date(rest)
		"sandbox":
			_sandbox(rest)
		"room":
			_room(rest)
		"react":
			_react(rest)
		"taskbar":
			_taskbar(rest)
		_:
			_out("모르는 명령입니다. help 를 쳐보세요")


func _out(text: String) -> void:
	_view.print_line(text)


# ── 저장 값 ──

func _onboarding(rest: Array) -> void:
	if rest.size() != 1 or not (rest[0] in ["reset", "done"]):
		_out("사용법: onboarding reset|done")
		return
	Save.settings.onboarded = rest[0] == "done"
	Save.settings.changed.emit()                 # 전역 설정은 save-on-change
	_out("onboarded = %s 저장했습니다. 재시작하면 적용됩니다%s" % [Save.settings.onboarded, _sandbox_note()])


func _nickname(name: String) -> void:
	if name == "":
		_out("사용법: nickname <이름>|clear")
		return
	Save.settings.nickname = "" if name == "clear" else name
	Save.settings.changed.emit()
	_out("호칭 = \"%s\" 저장했습니다. 재시작하면 적용됩니다%s" % [Save.settings.nickname, _sandbox_note()])


## 샌드박스는 실행마다 새로 시작하므로 "재시작하면 적용"이 성립하지 않는다. 그걸 알린다
func _sandbox_note() -> String:
	return " · 샌드박스라 다음 실행에는 남지 않습니다" if SANDBOX.active() else ""


## 지금 쓰는 폴더(샌드박스면 샌드박스)의 저장 파일 여섯 개를 시각 이름의 폴더에 복사한다.
## 밀린 쓰기가 있을 수 있어 먼저 전부 저장한다
func _backup() -> void:
	Save.save_game()
	Save.save_records()
	Save.save_journal()
	Save.save_todo()
	Save.save_gratitude()
	Save.save_mood()
	var stamp := Time.get_datetime_string_from_system().replace(":", "").replace("T", "-")
	var to := SANDBOX.dir() + "backup/" + stamp + "/"
	DirAccess.make_dir_recursive_absolute(to)
	var n := 0
	for f in SANDBOX.SAVE_FILES:
		if FileAccess.file_exists(SANDBOX.dir() + f) and SANDBOX.copy_file(SANDBOX.dir() + f, to + f):
			n += 1
	_out("%d개 복사했습니다: %s" % [n, ProjectSettings.globalize_path(to)])


# ── 날짜 ──

func _date(rest: Array) -> void:
	if rest.is_empty():
		_out("오늘 = %s (옮긴 일수 %+d)%s" % [DateUtil.today_iso(), DateUtil.day_offset, "" if SANDBOX.active() else " · 샌드박스 아님"])
		return
	if not SANDBOX.active():
		_out("날짜는 샌드박스에서만 옮깁니다. 툴바의 실행 모드에서 샌드박스를 고르세요")
		return
	if Clock.is_active():
		_out("세션이나 타이머가 도는 동안에는 옮기지 않습니다")
		return
	var arg := str(rest[0])
	var days := 0
	if arg == "off":
		days = 0
	elif arg.begins_with("+") or arg.begins_with("-"):
		if not arg.substr(1).is_valid_int():
			_out("사용법: date +n|-n|YYYY-MM-DD|off")
			return
		days = DateUtil.day_offset + int(arg.substr(1)) * (1 if arg.begins_with("+") else -1)
	else:
		var target := _iso_unix(arg)
		if target < 0:
			_out("사용법: date +n|-n|YYYY-MM-DD|off")
			return
		var t := Time.get_date_dict_from_system()   # 옮기기 전의 실제 오늘이 기준이다
		var real := Time.get_unix_time_from_datetime_dict({"year": t.year, "month": t.month, "day": t.day, "hour": 0, "minute": 0, "second": 0})
		days = int(round((target - real) / 86400.0))
	DateUtil.day_offset = days                   # 이번 실행 동안만. 파일에 남기지 않는다
	_update_title()
	get_tree().call_group(ROOM_SCRIPT.GROUP, "refresh")
	_out("오늘 = %s (옮긴 일수 %+d). 열려 있는 화면은 다시 열면 반영됩니다. 재시작하면 오늘로 돌아옵니다" % [DateUtil.today_iso(), days])


## "YYYY-MM-DD" → 그날 0시의 유닉스 초. 형식이 틀리면 -1
func _iso_unix(iso: String) -> int:
	var p := iso.split("-")
	if p.size() != 3 or not (p[0].is_valid_int() and p[1].is_valid_int() and p[2].is_valid_int()):
		return -1
	var y := int(p[0])
	var m := int(p[1])
	var d := int(p[2])
	if m < 1 or m > 12 or d < 1 or d > DateUtil.days_in_month("%04d-%02d-01" % [y, m]):
		return -1
	return Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": d, "hour": 0, "minute": 0, "second": 0})


# ── 샌드박스 ──

func _sandbox(rest: Array) -> void:
	if not rest.is_empty():
		_out("사용법: sandbox")
		return
	_out("%s · 저장 위치 %s" % [_mode_label(), ProjectSettings.globalize_path(SANDBOX.dir())])
	# 에디터의 실행 인자가 실제로 들어왔는지 본다. 오타나 설정 위치 문제를 여기서 가린다
	_out("받은 실행 인자: %s / 사용자 인자: %s" % [OS.get_cmdline_args(), OS.get_cmdline_user_args()])


func _mode_label() -> String:
	match SANDBOX.mode():
		SANDBOX.Mode.EMPTY:
			return "샌드박스 · 빈 상태"
		SANDBOX.Mode.COPY:
			return "샌드박스 · 복사본"
		SANDBOX.Mode.ONBOARDING:
			return "샌드박스 · 온보딩"
	return "샌드박스 아님"


func _update_title() -> void:
	if not SANDBOX.active():
		return
	var tag := _mode_label()
	if DateUtil.day_offset != 0:
		tag += " · " + DateUtil.today_iso()
	_shell.title = "%s [%s]" % [SHELL_TITLE, tag]


# ── 미리보기 ──

func _room(rest: Array) -> void:
	if rest.size() != 2 or not (rest[0] in ["shelf", "bundles"]) or not (rest[1] == "off" or str(rest[1]).is_valid_int()):
		_out("사용법: room shelf|bundles <n>|off")
		return
	var v := -1 if rest[1] == "off" else maxi(int(rest[1]), 0)
	if rest[0] == "shelf":
		ROOM_SCRIPT.preview_shelf = v
	else:
		ROOM_SCRIPT.preview_bundles = v
	get_tree().call_group(ROOM_SCRIPT.GROUP, "refresh")
	_out("방 %s = %s (저장 안 함)" % [rest[0], "실제 기록" if v < 0 else str(v)])


## 완료 반응을 흉내 낸다. 활동 로그에 쓰지 않는다(event_id 0) — 노트를 달 대상이 없다
func _react(rest: Array) -> void:
	if rest.size() != 1 or not (rest[0] in ["todo", "habit"]):
		_out("사용법: react todo|habit")
		return
	if rest[0] == "todo":
		Companion.todo_completed.emit({"event_id": 0, "group": "", "remaining": 1, "first_today": false, "age_days": 1, "title": "콘솔 테스트"})
	else:
		Companion.habit_completed.emit({"title": "콘솔 테스트", "remaining": 1, "gap_days": 1, "expected_gap": 1})
	_out("react %s 보냈습니다" % rest[0])


# ── 작업 표시줄 ──
# 확인한 사실은 docs/architecture/transparent-window.md 의 "작업 표시줄 버튼"이 갖는다.
# 손으로 켜는 도구다. 저장하지 않고 이번 실행 동안만 유효하다

func _taskbar(rest: Array) -> void:
	var action := String(rest[0]).to_lower() if rest.size() > 0 else "status"
	if not (action in ["status", "hide", "dance", "restore"]):
		_out("taskbar [status|hide|dance|restore]")
		return
	_out(TASKBAR_PROBE.start(action))
	# ⚠️ 기다리지 않고 띄운 뒤 결과 파일을 지켜본다. 막으면 교착이다(taskbar_probe.gd 의 주석)
	for i in 40:
		await get_tree().create_timer(0.25).timeout
		var text: String = TASKBAR_PROBE.read()
		if text != "":
			_out(text)
			return
	_out("10초 안에 결과가 안 왔다. user://taskbar_probe.txt 확인")
