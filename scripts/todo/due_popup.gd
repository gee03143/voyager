class_name DuePopup
extends PopupPanel

signal confirmed(iso: String)

@onready var title_label: Label = $VBox/TitleLabel
@onready var calendar: DueCalendar = $VBox/DueCalendar
@onready var ok_button: Button = $VBox/HBox/OKButton
@onready var cancel_button: Button = $VBox/HBox/CancelButton
@onready var delete_button: Button = $VBox/HBox/DeleteButton

var _pending_iso: String = ""

func _ready() -> void:
	ok_button.pressed.connect(_on_ok)
	cancel_button.pressed.connect(hide)
	delete_button.pressed.connect(_on_delete)
	calendar.day_selected.connect(_on_day_selected)

func open_for(current_iso: String, task_text: String) -> void:
	title_label.text = tr("TODO_DUE_POPUP_TITLE").format({"task": task_text})
	_pending_iso = current_iso
	calendar.set_selected(current_iso)
	popup_centered()

func _on_day_selected(iso: String) -> void:
	_pending_iso = iso

func _on_ok() -> void:
	confirmed.emit(_pending_iso)
	hide()

func _on_delete() -> void:
	confirmed.emit("")
	hide()
