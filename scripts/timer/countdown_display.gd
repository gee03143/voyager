class_name CountdownDisplay
extends VBoxContainer

@export var show_label: bool = true
@export var show_progress: bool = true

@onready var time_label: Label = $TimeLabel
@onready var progress: ProgressBar = $Progress

var _total: float = 0.0

func _ready() -> void:
	time_label.visible = show_label
	progress.visible = show_progress

func set_total(total: float) -> void:
	_total = total
	progress.max_value = total
	progress.value = 0.0
	render(total)

func render(time_left: float) -> void:
	if show_progress:
		progress.value = _total - time_left
	if show_label:
		var t := int(ceil(time_left))
		var h := t / 3600
		var m := (t % 3600) / 60
		var s := t % 60
		time_label.text = ("%02d:%02d:%02d" % [h, m, s]) if h > 0 else ("%02d:%02d" % [m, s])
