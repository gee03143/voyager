extends Node

@export var eye_button: BaseButton       # UI 토글(안구)
@export var gear_button: BaseButton      # 메뉴(기어), 동작은 world의 도크 nav가 담당, 여기서는 투명도 조절용
@export var chrome: Array[Control] = []  # UI 토글로 숨길 것들(도크·항해버튼·HUD·해리·PanelHost…)

var _ui_visible := true

func _ready() -> void:
	eye_button.pressed.connect(_toggle_ui)

func _toggle_ui() -> void:
	_ui_visible = not _ui_visible
	for c in chrome:
		if c != null:
			c.visible = _ui_visible
	eye_button.modulate.a = 1.0 if _ui_visible else 0.4     # 안구·기어는 자리 유지, 흐리게
	gear_button.modulate.a = 1.0 if _ui_visible else 0.4
