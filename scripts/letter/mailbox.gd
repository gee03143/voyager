extends Node

# 받은 편지함: Discovery(범용 발견)를 구독해 편지를 트레이에 쌓고, 배너(Notice)·선반 배지·열람을 구동.
# Discovery=발견 시점 / Mailbox=편지 도메인(트레이)+UI / Shelf=항구 진입+배지 / LetterView=열람 / ShelfView=보관 목록.

@export var discovery: Discovery
@export var notice: Notice
@export var shelf: Shelf

@onready var _letter_view = $LetterView
@onready var _shelf_view = $ShelfView


var _pending: Array = []        # 안 읽은 편지 [{template, slots}, ...]
var _current: Dictionary = {}   # 지금 열려 있는 편지

func _ready() -> void:
	discovery.discovered.connect(_on_discovered)
	shelf.pressed.connect(_on_shelf_pressed)
	_letter_view.kept.connect(_on_kept)
	_shelf_view.visible = false
	_letter_view.visible = false

func _process(_delta: float) -> void:
	shelf.set_badge(_pending.size())

func _on_discovered() -> void:
	var pool := LetterContent.SEED_LETTERS
	_pending.append(pool[randi() % pool.size()])
	notice.show_notice("편지를 하나 주웠어요 · 집중이 끝나면 열어보세요")

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
