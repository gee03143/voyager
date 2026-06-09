class_name ClockToolView
extends Control

@onready var display: CountdownDisplay = $VBox/Display

# 하위 클래스가 _ready 에서 호출
func _init_clock_tool() -> void:
	Save.settings.changed.connect(_apply_settings)
	_apply_settings()

func _apply_settings() -> void:
	display.visible = not Save.settings.hide_countdown

func _try_minimize() -> void:
	if _is_active() and Save.settings.auto_minimize:
		print("[자동 최소화] 미니 모드로 전환 (Week 7 구현 예정)")

func _play_alert() -> void:
	Sound.play_set(Save.settings.sound_set)

# 하위 클래스가 override — 활성(돌고 있는지) 판단
func _is_active() -> bool:
	return false
