class_name DuePopup
extends PopupPanel

signal confirmed(iso: String)

@onready var title_label: Label = $VBox/TitleLabel
@onready var input: LineEdit = $VBox/Input
@onready var error_label: Label = $VBox/ErrorLabel
@onready var ok_button: Button = $VBox/HBox/OKButton
@onready var cancel_button: Button = $VBox/HBox/CancelButton

func _ready() -> void:
	ok_button.pressed.connect(_on_ok)
	cancel_button.pressed.connect(hide)
	input.text_submitted.connect(func(_t): _on_ok())

func open_for(current_iso: String, task_text: String) -> void:
	title_label.text = "마감일 설정: %s" % task_text
	input.text = current_iso
	error_label.text = ""
	popup_centered()
	input.grab_focus()

func _on_ok() -> void:
	var t := input.text.strip_edges()
	if t.is_empty():
		confirmed.emit("")            # 비우면 마감일 제거
		hide()
		return
	var iso := _normalize(t)
	if iso.is_empty():
		error_label.text = "YYYY-MM-DD 형식으로 입력하세요 (예: 2026-06-13)"
		return
	confirmed.emit(iso)
	hide()

func _normalize(t: String) -> String:
	var p := t.split("-")
	if p.size() != 3:
		return ""
	if not (p[0].is_valid_int() and p[1].is_valid_int() and p[2].is_valid_int()):
		return ""
	var y := int(p[0])
	var m := int(p[1])
	var d := int(p[2])
	if y < 1 or m < 1 or m > 12 or d < 1 or d > _days_in_month(y, m):
		return ""
	return "%04d-%02d-%02d" % [y, m, d]

func _days_in_month(y: int, m: int) -> int:
	var days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if m == 2 and (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)):
		return 29
	return days[m - 1]
