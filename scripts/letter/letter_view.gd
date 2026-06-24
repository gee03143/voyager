extends PanelContainer

signal kept

@onready var _message: Label = $Margin/VBox/Message
@onready var _author: Label = $Margin/VBox/Foot/FootText/Author
@onready var _meta: Label = $Margin/VBox/Foot/FootText/Meta
@onready var _keep_button: Button = $Margin/VBox/Buttons/Keep
@onready var _close_button: Button = $Margin/VBox/Buttons/Close

func _ready() -> void:
	_keep_button.pressed.connect(_on_keep_pressed)
	_close_button.pressed.connect(_on_close_pressed)

# 편지 하나를 받아 토큰을 렌더해 표시. (Save·전역 모름 — 받기만 함)
func show_letter(template_idx: int, subject: String, fact: String, state: String, author: String, meta: String) -> void:
	_message.text = TelegraphContent.render(template_idx, subject, fact, state)
	_author.text = "— " + author
	_meta.text = meta
	visible = true

func _on_keep_pressed() -> void:
	kept.emit()
	visible = false

func _on_close_pressed() -> void:
	visible = false
