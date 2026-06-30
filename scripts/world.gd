extends Node2D

@export var dock: Container          # 토글 버튼들의 부모
@export var panels: Array[Control]   # 도크 버튼 순서대로의 패널 (항해처럼 없으면 비워둠)
@export var voyage_button: BaseButton
@export var gear_button: BaseButton      # 옵션 패널 여는 nav 버튼

@onready var haeri_label: Label = $UI/HaeriBadge
@onready var parallax: ParallaxBackground = $Parallax
@onready var ship: Sprite2D = $Ship
@onready var _parallax_layers: Array = $Parallax.get_children()

const PX_PER_NMI := 60.0	 # 스크롤 환산(픽셀/해리)

const CRUISE_SPEED := 1.0    # 해리/초 (감성)
const ACCEL := 0.6           # 가감속(해리/초²) — 클수록 빨리 붙고/멈춤

const BOB_AMP := 4.0       # 상하 진폭(px)
const BOB_FREQ := 2.0      # 흔들림 속도(rad/초) — 클수록 빠름
const ROCK_AMP := 0.03     # 좌우 기울임 진폭(rad ≈ 1.7°)

var _ship_base_y := 0.0
var _bob_t := 0.0

var _nav := ButtonGroupNav.new()
var _ship_speed := 0.0

func _ready() -> void:
	var buttons: Array = []
	for child in dock.get_children():
		if child is BaseButton:
			buttons.append(child)
	if voyage_button != null:
		buttons.append(voyage_button)        # 같은 그룹 → 한 번에 하나(항해 열면 도크 패널 닫힘)
	if gear_button != null:
		buttons.append(gear_button)
	_nav.setup(buttons, true)
	_nav.selected.connect(_on_nav_selected)
	for p in panels:
		if p != null:
			p.visible = false
	_ship_base_y = ship.position.y


func _process(delta: float) -> void:
	var target := CRUISE_SPEED if Clock.is_focusing() else 0.0
	_ship_speed = move_toward(_ship_speed, target, ACCEL * delta)   # 부드러운 가감속
	if _ship_speed > 0.0:
		Save.voyage.voyage_distance += _ship_speed * delta          # 속도 적분 = 거리
	haeri_label.text = "%.1f leagues" % Save.voyage.voyage_distance
	
	var d := Save.voyage.voyage_distance * PX_PER_NMI
	for layer in _parallax_layers:
		if layer is ParallaxLayer and layer.motion_mirroring.x > 0.0:
			layer.motion_offset.x = -fmod(d * layer.motion_scale.x, layer.motion_mirroring.x)
	
	_bob_t += delta
	var rough := 1.0 + _ship_speed * 0.6     # 항해 중 더 큰 흔들림
	ship.position.y = _ship_base_y + sin(_bob_t * BOB_FREQ) * BOB_AMP * rough
	ship.rotation = sin(_bob_t * BOB_FREQ * 0.5) * ROCK_AMP   # 약간 다른 주기 → 자연스러운 일렁임
	
	# fps test code
	# print(Engine.get_frames_per_second())

func _on_nav_selected(index: int) -> void:
	for p in panels:
		if p != null:
			p.visible = false
	if index >= 0 and index < panels.size() and panels[index] != null:
		panels[index].visible = true
