extends Node

# 세션 컨트롤러 — 진행 중 포모/타이머 인스턴스를 상주 소유(뷰와 분리).
# 휘발성(종료 시 소멸, Save 직렬화 X). Save는 앎(컨트롤러 계층).
var pomodoro: Pomodoro
var timer: SimpleTimer

func _ready() -> void:
	pomodoro = Pomodoro.new()
	pomodoro.name = "Pomodoro"
	add_child(pomodoro)
	pomodoro.focus_seconds = Save.settings.focus_seconds
	pomodoro.short_break_seconds = Save.settings.short_break_seconds
	pomodoro.long_break_seconds = Save.settings.long_break_seconds
	pomodoro.total_focus_count = Save.settings.total_focus_count
	pomodoro.build_plan()
	
	timer = SimpleTimer.new()
	timer.name = "Timer"
	add_child(timer)
	timer.configure(Save.settings.timer_seconds)
