class_name MoodHistoryRow
extends PanelContainer

signal selected
signal delete_requested(id: int)

const LEVEL_EMOJI := ["😞", "😕", "😐", "🙂", "😄"]

@onready var click_area: HBoxContainer = $Margin/HBox/ClickArea
@onready var level_label: Label = $Margin/HBox/ClickArea/LevelLabel
@onready var datetime_label: Label = $Margin/HBox/ClickArea/Body/DateTimeLabel
@onready var memo_label: Label = $Margin/HBox/ClickArea/Body/MemoLabel
@onready var delete_button: HoldButton = $Margin/HBox/DeleteButton

var _id: int = 0

func _ready() -> void:
	memo_label.clip_text = true
	memo_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	delete_button.held.connect(func(): delete_requested.emit(_id))
	click_area.gui_input.connect(_on_click_area_input)
	HoverReveal.setup(self, [delete_button])

func _on_click_area_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit()

func setup(entry: Dictionary) -> void:
	_id = int(entry.get("id", 0))
	var level := clampi(int(entry.get("level", 3)), 1, 5)
	level_label.text = LEVEL_EMOJI[level - 1]
	var ts := int(entry.get("ts", 0))
	datetime_label.text = "%s %s" % [DateUtil.format_day(DateUtil.local_day_iso(ts)), DateUtil.format_time_hm(ts)]
	datetime_label.modulate.a = 0.6
	var memo := str(entry.get("memo", "")).strip_edges()
	memo_label.text = memo
	memo_label.visible = memo != ""
