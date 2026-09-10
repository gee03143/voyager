class_name PanelEnter
extends RefCounted

# 패널이 한쪽에서 미끄러져 들어오는 연출. 콘텐츠 스왑과 탭 전환이 함께 쓴다.
# 들어오는 방향은 표면마다 따로 정한다 — 시간과 이징을 표면마다 정하는 것과 같은 이유다.
# 나가는 쪽은 다루지 않는다 — 거두는 데 시간을 쓰면 새 화면이 그만큼 늦게 시작한다.
#
# 컨테이너는 자식의 위치를 재배치마다 되돌리므로(docs/architecture/ui-animation.md)
# 반드시 컨테이너가 아닌 래퍼 안에 있는 패널에만 걸 것.

const DIST_PX := 48.0        # 들어오는 거리. 화면 크기에 비하면 짧다 — 멀리서 날아오면 이동이 주인공이 된다

const FROM_LEFT := Vector2(-DIST_PX, 0.0)
const FROM_BELOW := Vector2(0.0, DIST_PX)

# 패널을 담을 자리. 호출부가 원하는 컨테이너에 직접 붙인다.
static func make_wrap() -> Control:
	var wrap := Control.new()
	wrap.clip_contents = true                      # 콘텐츠는 무슨 일이 있어도 이 영역을 벗어나지 않는다
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return wrap

# 패널을 래퍼에 넣고 정확히 채우게 만든다.
static func adopt(wrap: Control, panel: Control) -> void:
	if panel.get_parent() != wrap:
		panel.reparent(wrap, false)                # 전역 변형 보정이 오프셋으로 남지 않게
	# set_anchors_preset은 앵커만 바꾸고 오프셋은 그대로 둔다(Control.xml).
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# 시간은 표면마다 따로 정한다. 큰 것이 느리게 움직여야 무겁게 느껴진다.
static func play(host: Node, panel: Control, sec: float, from: Vector2 = FROM_BELOW) -> Tween:
	panel.position = from
	panel.modulate.a = 0.0                         # 재사용되는 인스턴스라 매번 같은 자리에서 시작시킨다
	var t := host.create_tween().set_parallel()
	t.tween_property(panel, "position", Vector2.ZERO, sec) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)   # 도착하며 멈추는 감속
	t.tween_property(panel, "modulate:a", 1.0, sec * 0.5)
	return t

# 연출 없이 제자리로. 아직 화면에 없는 패널에 연출을 걸면 보이지도 않고 소진된다.
static func settle(panel: Control) -> void:
	panel.position = Vector2.ZERO
	panel.modulate.a = 1.0

# 팝업용 변형. PopupPanel은 자식의 position과 size를 매 배치마다 덮어쓰므로(popup.cpp)
# 이동은 쓸 수 없다. scale과 modulate는 안 건드리니 그 둘로 자리를 잡는 느낌을 낸다.
const POP_FROM_SCALE := 0.96

static func pop_in(host: Node, content: Control, sec: float) -> Tween:
	# 처음 열 때는 아직 배치 전이라 size가 0이다. 그때는 최소 크기로 대신한다.
	var box := content.size if content.size.y > 0.0 else content.get_combined_minimum_size()
	content.pivot_offset = box * 0.5               # 가운데를 기준으로 커진다
	content.scale = Vector2.ONE * POP_FROM_SCALE
	content.modulate.a = 0.0
	var t := host.create_tween().set_parallel()
	t.tween_property(content, "scale", Vector2.ONE, sec) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(content, "modulate:a", 1.0, sec * 0.7)
	return t

static func kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
