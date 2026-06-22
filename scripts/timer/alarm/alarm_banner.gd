extends Node

@export var notice: Notice

func _ready() -> void:
	Alarms.alarm_triggered.connect(_on_alarm)

func _on_alarm(a: Alarm) -> void:
	var text := "알람 · %02d:%02d" % [a.hour, a.minute]
	if a.label != "":
		text += " · " + a.label
	notice.show_notice(text)
