extends Node

@export var notice: Notice

func _ready() -> void:
	Alarms.alarm_triggered.connect(_on_alarm)

func _on_alarm(a: Alarm) -> void:
	var hh := "%02d" % a.hour
	var mm := "%02d" % a.minute
	var text: String
	if a.label != "":
		text = TranslationServer.translate("ALARM_NOTICE_WITH_LABEL").format({"hour": hh, "minute": mm, "label": a.label})
	else:
		text = TranslationServer.translate("ALARM_NOTICE").format({"hour": hh, "minute": mm})
	notice.show_notice(text)
