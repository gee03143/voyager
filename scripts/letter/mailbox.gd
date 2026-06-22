extends Node

# 받은 편지함: Discovery(범용 발견)를 구독해 편지를 트레이에 쌓고, 토스트·인디케이터·열람을 구동.
# Discovery=발견 시점만 / Mailbox=편지 도메인(트레이)+UI / LetterView=펼쳐 읽기.

@export var discovery: Discovery
@export var shelf: Shelf

@onready var _toast: Control = $Toast
@onready var _toast_text: Label = $Toast/ToastText
@onready var _letter_view = $LetterView
@onready var _shelf_view = $ShelfView

const TOAST_TIME := 3.5

var _pending: Array = []        # 안 읽은 편지 [{template, slots}, ...]
var _toast_left := 0.0
var _current: Dictionary = {}   # 지금 열려 있는 편지

func _ready() -> void:
	discovery.discovered.connect(_on_discovered)
	shelf.pressed.connect(_on_shelf_pressed)
	_letter_view.kept.connect(_on_kept)
	_toast.visible = false
	_shelf_view.visible = false
	_letter_view.visible = false

func _process(delta: float) -> void:
	if _toast_left > 0.0:                      # 토스트 자동 숨김
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false
	shelf.set_badge(_pending.size())

func _on_discovered() -> void:
	var pool := LetterContent.SEED_LETTERS
	_pending.append(pool[randi() % pool.size()])
	_toast_text.text = "편지를 하나 주웠어요 · 집중이 끝나면 열어보세요"
	_toast.visible = true
	_toast_left = TOAST_TIME

func _on_shelf_pressed() -> void:
	if not _pending.is_empty():               # 안 읽은 게 있으면 읽기
		_current = _pending.pop_front()
		_letter_view.show_letter(_current["template"], _current["slots"], "이름 모를 항해자", "어딘가의 바다에서")
	else:                                      # 없으면 보관함 열기
		_shelf_view.visible = true

func _on_kept() -> void:
	if _current.is_empty():
		return
	Save.letters.add(_current["template"], _current["slots"])
	_current = {}
