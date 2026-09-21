class_name ShimejiPart
extends Node2D

## 파츠 하나. 지금은 도형을 그리지만 PNG 가 오면 이 노드에 Sprite2D 를 달고
## _draw 를 지우면 된다. 바깥은 노드의 transform 만 만지므로 그때 바뀌는 게 없다.
##
## 좌표는 전부 **자기 회전축 기준**이다. 회전축의 절대 위치는 ShimejiView 가 정한다.
## 축 목록은 docs/architecture/companion-rig.md 의 회전축 계약과 같다.

enum Kind { TAIL, EAR, FOOT, BODY, CLOAK, BAG, ARM, HEAD, BOOK, ACORN, GROUND }

const FUR := Color(0.776, 0.714, 0.631)
const FUR_DARK := Color(0.718, 0.651, 0.569)
const LINE := Color(0.290, 0.251, 0.220)
const CLOAK_COLOR := Color(0.431, 0.478, 0.384)
const BAG_COLOR := Color(0.604, 0.518, 0.404)
const EYE_WHITE := Color(0.973, 0.957, 0.929)
const MUZZLE := Color(0.875, 0.835, 0.776)
const OUTLINE := 2.5

var kind := Kind.BODY

# HEAD 전용 — 얼굴은 아직 한 노드다. PNG 가 오면 눈·눈꺼풀·입이 각자 노드가 된다
var open := 1.0
var mouth_curve := 2.5
var iris := Vector2.ZERO

# 소품 전용
var page := 0.0        # BOOK — 넘어가는 중이면 0~1
var grow := 0.0        # GROUND — 구멍이나 흙더미가 자란 정도 0~1
var mound := false     # GROUND — 참이면 흙더미, 거짓이면 파인 구멍


func setup(k: Kind, pivot: Vector2, flip: bool = false) -> void:
	kind = k
	position = pivot
	if flip:
		scale.x = -1.0


func _draw() -> void:
	match kind:
		Kind.TAIL:
			_draw_tail()
		Kind.EAR:
			_outlined(PackedVector2Array([Vector2(-7, 0), Vector2(6, -34), Vector2(8, -2)]), FUR_DARK)
		Kind.FOOT:
			_blob(Vector2.ZERO, 13.0, 8.0, FUR_DARK)
		Kind.BODY:
			_blob(Vector2(0, -42), 31.0, 38.0, FUR)
		Kind.CLOAK:
			_outlined(PackedVector2Array([
				Vector2(-29, -66), Vector2(0, -74), Vector2(29, -66),
				Vector2(25, -18), Vector2(0, -12), Vector2(-25, -18),
			]), CLOAK_COLOR)
		Kind.BAG:
			_outlined(PackedVector2Array([
				Vector2(13, -42), Vector2(31, -42), Vector2(31, -25), Vector2(13, -25),
			]), BAG_COLOR)
		Kind.ARM:
			_blob(Vector2(1, 11), 7.0, 14.0, FUR_DARK)
		Kind.HEAD:
			_draw_head()
		Kind.BOOK:
			_draw_book()
		Kind.ACORN:
			_draw_acorn()
		Kind.GROUND:
			_draw_ground()


func _draw_book() -> void:
	_outlined(PackedVector2Array([
		Vector2(-26, -14), Vector2(0, -8), Vector2(26, -14),
		Vector2(26, 14), Vector2(0, 20), Vector2(-26, 14),
	]), Color(0.937, 0.914, 0.875))
	# 넘어가는 장. 가로로 눌렀다 반대쪽에서 펴지는 것으로 넘김을 낸다
	var w := absf(cos(page * PI))
	var sx := w if page < 0.5 else -w
	draw_set_transform_matrix(Transform2D(0.0, Vector2(sx, 1.0), 0.0, Vector2.ZERO))
	_outlined(PackedVector2Array([
		Vector2(0, -8), Vector2(24, -13), Vector2(24, 13), Vector2(0, 19),
	]), Color(0.871, 0.835, 0.780))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_line(Vector2(0, -8), Vector2(0, 20), LINE, 2.5)


func _draw_acorn() -> void:
	_blob(Vector2(0, 2), 7.0, 9.0, Color(0.690, 0.541, 0.337))
	_outlined(PackedVector2Array([
		Vector2(-8, -2), Vector2(-6, -8), Vector2(6, -8), Vector2(8, -2),
	]), Color(0.478, 0.369, 0.220))


func _draw_ground() -> void:
	if grow <= 0.01:
		return
	if mound:
		_outlined(PackedVector2Array([
			Vector2(-18 * grow, 0), Vector2(0, -17 * grow), Vector2(18 * grow, 0),
		]), BAG_COLOR)
		return
	_ellipse(Vector2(0, -1), 13.0 * grow, 4.5 * grow, Color(0.290, 0.251, 0.220, 0.6))


func _draw_tail() -> void:
	var pts := PackedVector2Array([
		Vector2(-4, 4), Vector2(17, -12), Vector2(27, -40),
		Vector2(22, -68), Vector2(6, -88),
	])
	draw_polyline(pts, LINE, 40.0, true)
	draw_polyline(pts, FUR, 40.0 - OUTLINE * 2.0, true)


func _draw_head() -> void:
	var c := Vector2(0, -30)                  # 목에서 머리 중심까지
	draw_circle(c, 34.0 + OUTLINE, LINE)
	draw_circle(c, 34.0, FUR)
	_ellipse(c + Vector2(0, 11), 23.0, 19.0, MUZZLE)
	_draw_eye(c + Vector2(-13, 0))
	_draw_eye(c + Vector2(13, 0))
	_ellipse(c + Vector2(0, 13), 5.0, 3.6, LINE)
	draw_polyline(PackedVector2Array([
		c + Vector2(-7, 17), c + Vector2(0, 17 + mouth_curve), c + Vector2(7, 17),
	]), LINE, 2.5, true)


func _draw_eye(center: Vector2) -> void:
	# 깜빡임과 실눈은 눈을 세로로 눌러서 낸다. 눈꺼풀 파츠가 생기면 이 방식은 사라진다
	var ry: float = maxf(10.0 * open, 1.2)
	_blob(center, 9.0, ry, EYE_WHITE)
	_ellipse(center + iris + Vector2(0, 1), 5.2, 5.2 * open + 0.8, LINE)


## 타원. 외곽선은 한 겹 큰 타원을 밑에 깔아서 낸다.
## draw_arc 를 비균등 스케일 아래에서 쓰면 선 굵기가 방향마다 달라진다.
func _blob(center: Vector2, rx: float, ry: float, color: Color) -> void:
	_ellipse(center, rx + OUTLINE, ry + OUTLINE, LINE)
	_ellipse(center, rx, ry, color)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	draw_set_transform_matrix(Transform2D(0.0, Vector2(1.0, ry / rx), 0.0, center))
	draw_circle(Vector2.ZERO, rx, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _outlined(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points + PackedVector2Array([points[0]]), LINE, OUTLINE * 2.0, true)
	draw_colored_polygon(points, color)
