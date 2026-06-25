extends VBoxContainer

@onready var tab_nav: HBoxContainer = $TabNav
@onready var stats_tab: VBoxContainer = $Content/Host/StatsTab
@onready var _pages: Array = [$Content/Host/StatsTab, $Content/Host/ComposerTab, $Content/Host/CodexTab]

var _nav := ButtonGroupNav.new()
var _focus_label: Label
var _play_label: Label
var _haeri_label: Label
var _count_label: Label

func _ready() -> void:
	_build_stats()
	_nav.setup_from(tab_nav, false)
	_nav.selected.connect(_on_tab_selected)
	Save.voyage.changed.connect(_refresh_stats)
	Save.activity_log.changed.connect(_refresh_stats)
	visibility_changed.connect(func(): if visible: _refresh_stats())
	_refresh_stats()
	_nav.select(0)

func _on_tab_selected(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = (i == index)

func _build_stats() -> void:
	_focus_label = _add_stat()
	_play_label = _add_stat()
	_haeri_label = _add_stat()
	_count_label = _add_stat()

func _add_stat() -> Label:
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_tab.add_child(l)
	return l

func _refresh_stats() -> void:
	var v := Save.voyage
	_focus_label.text = "누적 집중: %s" % _fmt_hm(int(v.total_focus_seconds))
	_play_label.text = "누적 플레이: %s" % _fmt_hm(int(v.total_play_seconds))
	_haeri_label.text = "항해 거리: %.1f leagues" % v.voyage_distance
	_count_label.text = "총 활동: %d건" % Save.activity_log.events.size()

func _fmt_hm(total: int) -> String:
	return "%dh %02dm" % [total / 3600, (total % 3600) / 60]
