extends VBoxContainer

@onready var tab_nav: HBoxContainer = $TabNav
@onready var quit_button: Button = $Host/EtcTab/QuitButton
@onready var _pages: Array = [$Host/ScreenTab, $Host/SoundTab, $Host/EtcTab]

var _nav := ButtonGroupNav.new()

func _ready() -> void:
	_nav.setup_from(tab_nav, false)
	_nav.selected.connect(_on_tab_selected)
	quit_button.pressed.connect(Save.quit_game)     # 게임 종료(기타 탭)
	_nav.select(0)

func _on_tab_selected(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = (i == index)
