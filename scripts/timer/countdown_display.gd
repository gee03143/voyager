class_name CountdownDisplay
extends VBoxContainer

@onready var time_label: Label = $TimeLabel
@onready var progress: ProgressBar = $Progress

var _total: float = 0.0

func set_total(total: float) -> void:
	_total = total
	progress.max_value = total
	progress.value = 0.0
	render(total)

func render(time_left: float) -> void:
	var t := int(ceil(time_left))
	time_label.text = "%02d:%02d" % [t / 60, t % 60]
	progress.value = _total - time_left
