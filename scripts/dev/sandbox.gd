class_name Sandbox
extends RefCounted

## 테스트 저장 폴더(docs/specs/dev-console.md 의 "샌드박스").
## 실행 인자로 띄우면 Save 가 실제 폴더 대신 여기를 쓴다. 디버그 실행에서만 동작한다.
##   --sandbox-empty       기록 없이 시작한다. 온보딩은 본 것으로 친다
##   --sandbox-copy        지금 실제 기록의 복사본으로 시작한다
##   --sandbox-onboarding  기록 없이 시작하고 온보딩부터 재생한다
## 실행할 때마다 새로 시작한다. 앞선 샌드박스 실행에서 바꾼 것은 이어지지 않는다.
##
## 실제 폴더의 파일은 복사할 때 읽기만 한다. 지우고 쓰는 경로는 전부 DIR 아래다.

enum Mode { OFF, EMPTY, COPY, ONBOARDING }

const ARG_EMPTY := "--sandbox-empty"
const ARG_COPY := "--sandbox-copy"
const ARG_ONBOARDING := "--sandbox-onboarding"
## 예전 인자. 모르는 인자로 두면 아무 표시 없이 실제 폴더로 뜬다 — 샌드박스가 막으려던 사고다. 복사본으로 읽는다
const ARG_LEGACY := "--sandbox"
const DIR := "user://sandbox/"
const REAL_DIR := "user://"
## Save 가 쓰는 파일. 이름은 save.gd 의 *_FILE 과 같아야 한다
const SAVE_FILES := ["save.json", "records.json", "journal.json", "todo.json", "gratitude.json", "mood.json"]
const LEGACY_FILES := ["dev.json"]           # 실행 사이에 이어 쓰던 때(--sandbox)의 흔적. 샌드박스 폴더 안에만 있다

static var _mode := Mode.OFF
static var _checked := false


## 어느 샌드박스로 띄웠는가. 인자만 주면 get_cmdline_args, -- 뒤에 주면 get_cmdline_user_args 로 들어온다(실행 확인).
## 여럿 주면 ONBOARDING, EMPTY, COPY 순으로 앞의 것 — 실제 기록을 읽지 않는 쪽이 앞이다
static func mode() -> Mode:
	if not _checked:
		_checked = true
		var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
		if not OS.is_debug_build():
			_mode = Mode.OFF
		elif ARG_ONBOARDING in args:
			_mode = Mode.ONBOARDING
		elif ARG_EMPTY in args:
			_mode = Mode.EMPTY
		elif ARG_COPY in args or ARG_LEGACY in args:
			_mode = Mode.COPY
	return _mode


static func active() -> bool:
	return mode() != Mode.OFF


## 기록 없이 시작하되 온보딩은 본 것으로 치는가. Save 가 파일을 다 읽은 뒤에 본다
static func skips_onboarding() -> bool:
	return mode() == Mode.EMPTY


## 저장 파일이 놓이는 폴더
static func dir() -> String:
	return DIR if active() else REAL_DIR


## Save 가 파일을 읽기 전에 부른다. 샌드박스 폴더의 저장 파일을 지우고, COPY 면 실제 파일을 복사한다
static func prepare() -> void:
	if not active():
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in SAVE_FILES + LEGACY_FILES:
		if FileAccess.file_exists(DIR + f):
			DirAccess.remove_absolute(DIR + f)
	if mode() == Mode.COPY:
		for f in SAVE_FILES:
			if FileAccess.file_exists(REAL_DIR + f):
				copy_file(REAL_DIR + f, DIR + f)


## 바이트 그대로 복사한다. 원본은 읽기만 한다
static func copy_file(from: String, to: String) -> bool:
	var data := FileAccess.get_file_as_bytes(from)
	var out := FileAccess.open(to, FileAccess.WRITE)
	if out == null:
		return false
	out.store_buffer(data)
	out.close()
	return true
