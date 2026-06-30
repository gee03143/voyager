class_name AppSettings
extends RefCounted

signal changed                          # 설정 변경 → 저장 + 뷰 전파
signal hud_reset

# HUD 위치 설정
var hud_position: Vector2 = Vector2(-1, -1)   # (-1,-1) = 미설정 → 기본 위치 사용
var hud_scale: float = 1.0                    # P3b 리사이즈용(지금은 필드만)

# 포모 세션 설정
var focus_seconds: float = 25 * 60
var short_break_seconds: float = 5 * 60
var long_break_seconds: float = 15 * 60
var total_focus_count: int = 4
var timer_seconds: float = 5 * 60

# 시계 탭 공통 세팅
var hide_countdown: bool = false        # 카운트다운 숨기기
var auto_minimize: bool = true         # 활성 시 자동 최소화 (플래그만, 효과는 Week 7)
var sound_set: int = 0                 # 알람 소리 종류

# 화면 세팅
var window_mode: int = 2                       # 0=FullScreen, 1=Borderless, 2=Windowed
var window_size: Vector2i = Vector2i(1280, 720) # Windowed 해상도
var fps_focused: int = 60                       # 포커스 시 FPS (0=무제한)
var fps_unfocused: int = 10                     # 비포커스 시 FPS
var always_on_top: bool = false

# 사운드 세팅
var master_volume: float = 1.0

func to_dict() -> Dictionary:
	return {
		"focus_seconds": focus_seconds,
		"short_break_seconds": short_break_seconds,
		"long_break_seconds": long_break_seconds,
		"total_focus_count": total_focus_count,
		"timer_seconds": timer_seconds,
		"hide_countdown": hide_countdown,
		"auto_minimize": auto_minimize,
		"sound_set": sound_set,
		"hud_position": [hud_position.x, hud_position.y],
		"hud_scale": hud_scale,
		"window_mode": window_mode,
		"window_size": [window_size.x, window_size.y],
		"fps_focused": fps_focused,
		"fps_unfocused": fps_unfocused,
		"always_on_top": always_on_top,
		"master_volume": master_volume,
	}

func from_dict(d: Dictionary) -> void:
	# 키 없으면 기본값 유지 → 스키마 진화에 안전
	focus_seconds = d.get("focus_seconds", focus_seconds)
	short_break_seconds = d.get("short_break_seconds", short_break_seconds)
	long_break_seconds = d.get("long_break_seconds", long_break_seconds)
	total_focus_count = max(1, int(d.get("total_focus_count", total_focus_count)))
	timer_seconds = d.get("timer_seconds", timer_seconds)
	hide_countdown = bool(d.get("hide_countdown", hide_countdown))
	auto_minimize = bool(d.get("auto_minimize", auto_minimize))
	sound_set = int(d.get("sound_set", sound_set))
	var hp = d.get("hud_position", null)
	if typeof(hp) == TYPE_ARRAY and hp.size() == 2:
		hud_position = Vector2(hp[0], hp[1])
	hud_scale = float(d.get("hud_scale", hud_scale))
	window_mode = int(d.get("window_mode", window_mode))
	var ws = d.get("window_size", null)
	if typeof(ws) == TYPE_ARRAY and ws.size() == 2:
		window_size = Vector2i(int(ws[0]), int(ws[1]))
	fps_focused = int(d.get("fps_focused", fps_focused))
	fps_unfocused = int(d.get("fps_unfocused", fps_unfocused))
	always_on_top = bool(d.get("always_on_top", always_on_top))
	master_volume = clampf(float(d.get("master_volume", master_volume)), 0.0, 1.0)
