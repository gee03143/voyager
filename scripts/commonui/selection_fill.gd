class_name SelectionFill
extends RefCounted

# 선택된 버튼의 배경이 즉시 바뀌지 않고 쓸어 들어오게 한다.
# 거두는 건 즉시 — 나가는 것보다 들어오는 것에 시간을 쓴다(docs/specs/ui-animation.md).
#
# 버튼 텍스트는 버튼 자신이 그리므로 채움을 그냥 자식으로 붙이면 글자를 덮는다.
# show_behind_parent로 글자 뒤에 보내고, 그러면 버튼의 선택 배경이 채움을 가리므로 그것을 비운다.
# hover는 안 비운다 — 반투명이라 채움이 비쳐 보이고, 비우면 마우스를 올린 채 누르는
# 평소 조작에서 채움이 이미 꽉 찬 상태가 되어 쓸어 들어오는 게 안 보인다.

# 세로로 쌓인 버튼은 가로로 긴 알약이라 좌→우가 그 모양을 따라 흐른다.
# 가로로 늘어선 버튼은 폭이 좁아 좌→우로 쓸면 순식간에 끝나 보이므로 중앙에서 퍼뜨린다.
enum Dir { LEFT_TO_RIGHT, CENTER_OUT }

const FILL_NAME := "SelectionFill"
const TWEEN_META := "selection_fill_tween"
const DIR_META := "selection_fill_dir"

# 채움 색은 하드코딩하지 않는다. 지금 선택 상태가 쓰는 스타일박스를 복제해 씌우므로
# 색과 모서리 반경이 따라오고, 테마에서 선택 색을 바꾸면 채움도 같이 바뀐다.
static func attach(button: BaseButton, dir: int = Dir.LEFT_TO_RIGHT) -> void:
	if button.has_node(NodePath(FILL_NAME)):
		return
	var fill := Panel.new()
	fill.name = FILL_NAME
	fill.show_behind_parent = true
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := button.get_theme_stylebox("pressed")
	if style != null:
		fill.add_theme_stylebox_override("panel", style.duplicate())
	button.add_child(fill)
	fill.set_meta(DIR_META, dir)
	_reset_rect(fill)
	_collapse(fill)
	var hidden := _hidden_like(style)
	button.add_theme_stylebox_override("pressed", hidden)
	button.add_theme_stylebox_override("hover_pressed", hidden)

# ⚠️ 여백을 잃으면 안 된다. Button은 **현재 상태의** 스타일박스로 최소 크기를 재므로
# (align_to_largest_stylebox 기본값이 꺼짐), 그냥 빈 것으로 덮으면 선택된 버튼만 작아진다.
static func _hidden_like(style: StyleBox) -> StyleBox:
	var empty := StyleBoxEmpty.new()
	if style != null:
		empty.content_margin_left = style.get_margin(SIDE_LEFT)
		empty.content_margin_top = style.get_margin(SIDE_TOP)
		empty.content_margin_right = style.get_margin(SIDE_RIGHT)
		empty.content_margin_bottom = style.get_margin(SIDE_BOTTOM)
	return empty

# sec가 0이면 연출 없이 즉시 반영한다.
static func set_selected(button: BaseButton, on: bool, sec: float) -> void:
	var fill := button.get_node_or_null(NodePath(FILL_NAME)) as Control
	if fill == null:
		return
	_kill(fill)
	if not on:
		_collapse(fill)
		return
	if sec <= 0.0 or is_equal_approx(fill.anchor_right, 1.0):
		_expand(fill)                      # 이미 차 있거나 연출을 안 쓰는 경우
		return
	_collapse(fill)
	# 다른 연출과 달리 감속을 안 쓴다. 채움은 물체가 도착하는 게 아니라 쓸어가는 것이라,
	# 감속을 걸면 움직임이 앞쪽에 몰려 순식간에 차버리고 즉시 바뀐 것처럼 보인다.
	var t := fill.create_tween().set_parallel()
	t.tween_property(fill, "anchor_right", 1.0, sec)
	if int(fill.get_meta(DIR_META, Dir.LEFT_TO_RIGHT)) == Dir.CENTER_OUT:
		t.tween_property(fill, "anchor_left", 0.0, sec)
	fill.set_meta(TWEEN_META, t)

# 비어 있는 상태. 좌→우는 왼쪽 끝의 폭 0, 중앙 확산은 한가운데의 폭 0.
static func _collapse(fill: Control) -> void:
	if int(fill.get_meta(DIR_META, Dir.LEFT_TO_RIGHT)) == Dir.CENTER_OUT:
		fill.anchor_left = 0.5
		fill.anchor_right = 0.5
	else:
		fill.anchor_left = 0.0
		fill.anchor_right = 0.0

static func _expand(fill: Control) -> void:
	fill.anchor_left = 0.0
	fill.anchor_right = 1.0

# 왼쪽 끝에 붙은 폭 0짜리 띠. anchor_right를 늘려 채우므로 버튼 폭이 바뀌어도 따라간다.
static func _reset_rect(fill: Control) -> void:
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.offset_left = 0.0
	fill.offset_top = 0.0
	fill.offset_right = 0.0
	fill.offset_bottom = 0.0

static func _kill(fill: Control) -> void:
	# get_meta의 기본값으로 null을 주면 "기본값 없음"으로 취급되어 오류가 난다(object.cpp).
	if not fill.has_meta(TWEEN_META):
		return
	var t = fill.get_meta(TWEEN_META)
	if t != null and (t as Tween).is_valid():
		(t as Tween).kill()
