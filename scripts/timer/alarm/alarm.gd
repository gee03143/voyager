class_name Alarm
extends RefCounted

var hour: int = 8
var minute: int = 0
var enabled: bool = true
var label: String = ""

func to_dict() -> Dictionary:
	return {"hour": hour, "minute": minute, "enabled": enabled, "label": label}
	
static func from_dict(d: Dictionary) -> Alarm:
	var a := Alarm.new()
	a.hour = int(d.get("hour", 8))
	a.minute = int(d.get("minute", 0))
	a.enabled = bool(d.get("enabled", true))
	a.label = str(d.get("label", ""))
	return a
