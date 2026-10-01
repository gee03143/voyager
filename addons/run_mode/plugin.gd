@tool
extends EditorPlugin

## 실행 모드 드롭다운(docs/specs/dev-console.md 의 "실행 모드 드롭다운").
## 에디터 상단 툴바에 붙어, 고른 모드의 실행 인자를 프로젝트 설정 editor/run/main_run_args 에 넣는다.
## 「여러 인스턴스 실행」 창의 「메인 실행 인자」 칸은 settings_changed 를 받아 이 값을 다시 읽는다 —
## 그래서 여기서 바꾸면 그 창도 같이 바뀌고, F5 가 이 값으로 뜬다.

const SETTING := "editor/run/main_run_args"

## 프리셋. [이름, 실행 인자]. 셋 다 샌드박스다 — 실제 기록으로 띄우는 항목은 두지 않는다(2026-10-01 유저 결정).
## 실제 기록으로 띄우려면 「여러 인스턴스 실행」 창의 메인 실행 인자를 비운다. 그때 드롭다운은 「실제 기록 (인자 없음)」을 보여준다
const PRESETS := [
	["샌드박스 · 빈 상태", "--sandbox-empty"],
	["샌드박스 · 복사본", "--sandbox-copy"],
	["온보딩부터", "--sandbox-onboarding"],
]
const CUSTOM_LABEL := "직접 입력: %s"
const REAL_LABEL := "실제 기록 (인자 없음)"

var _picker: OptionButton


func _enter_tree() -> void:
	_picker = OptionButton.new()
	_picker.tooltip_text = "F5 실행 모드. 고른 값이 메인 실행 인자(%s)가 된다" % SETTING
	_picker.item_selected.connect(_on_selected)
	add_control_to_container(CONTAINER_TOOLBAR, _picker)
	ProjectSettings.settings_changed.connect(_sync)   # 창에서 손으로 바꾼 값도 따라간다
	_sync()


func _exit_tree() -> void:
	if ProjectSettings.settings_changed.is_connected(_sync):
		ProjectSettings.settings_changed.disconnect(_sync)
	remove_control_from_container(CONTAINER_TOOLBAR, _picker)
	_picker.queue_free()
	_picker = null


## 지금 설정값에 맞춰 목록과 선택을 다시 만든다. 프리셋에 없는 값이면 「직접 입력」 항목을 덧붙여 고른다
func _sync() -> void:
	var current := str(ProjectSettings.get_setting(SETTING, "")).strip_edges()
	_picker.clear()
	var at := -1
	for i in PRESETS.size():
		_picker.add_item(PRESETS[i][0], i)
		if PRESETS[i][1] == current:
			at = i
	if at < 0:
		_picker.add_item(REAL_LABEL if current == "" else CUSTOM_LABEL % current, PRESETS.size())
		at = PRESETS.size()
	_picker.select(at)


func _on_selected(index: int) -> void:
	if index >= PRESETS.size():
		return                                       # 「직접 입력」은 고를 것이 아니라 지금 상태를 보여줄 뿐이다
	ProjectSettings.set_setting(SETTING, PRESETS[index][1])
	ProjectSettings.save()
