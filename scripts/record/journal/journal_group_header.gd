class_name JournalGroupHeader
extends HBoxContainer

signal toggled(gid: int)
signal rename_requested(gid: int, name: String)
signal delete_requested(gid: int)

@onready var toggle_button: Button = $ToggleButton
@onready var name_label: Label = $NameLabel
@onready var rename_button: Button = $RenameButton
@onready var delete_button: HoldButton = $DeleteButton

var _gid: int = 0
var _name: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP        # 헤더가 호버 감지
	toggle_button.pressed.connect(func(): toggled.emit(_gid))
	rename_button.pressed.connect(func(): rename_requested.emit(_gid, _name))
	delete_button.held.connect(func(): delete_requested.emit(_gid))
	HoverReveal.setup(self, [rename_button, delete_button])

func setup(gid: int, name: String, count: int, collapsed: bool) -> void:
	_gid = gid
	_name = name
	toggle_button.text = "▸" if collapsed else "▾"
	name_label.text = "%s (%d)" % [name, count]
	rename_button.visible = gid != 0                # "그룹 없음"은 이름변경/삭제 없음
	delete_button.visible = gid != 0
