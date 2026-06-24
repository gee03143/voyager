class_name Discovery
extends Node

# 범용 발견 메커니즘: 항해 거리가 interval을 넘을 때마다 discovered 발신.
# 무엇을 발견하는지는 모름 — 구독자(편지/섬 등)가 결정.
# 거리는 집중 중에만 증가(world.gd) → 발견도 집중에만(자동 게이트).

signal discovered

@export var interval: float = 300.0   # 발견 간격(leagues). 인스턴스별 설정(테스트=2.0).

var _next_at := 0.0

func _ready() -> void:
	_next_at = Save.voyage.voyage_distance + interval

func _process(_delta: float) -> void:
	if interval <= 0.0:                              # 오설정 시 무한 루프 방지
		return
	while Save.voyage.voyage_distance >= _next_at:   # 한 프레임에 여러 임계 넘어도 모두
		discovered.emit()
		_next_at += interval
