extends VBoxContainer

@export var nav_slot: TabNavSlot
@export var tab_labels: Array[String] = []
@export var tab_pages: Array[Control] = []
@onready var stats_tab: VBoxContainer = $StatsTab

var _focus_label: Label
var _play_label: Label
var _haeri_label: Label
var _count_label: Label

func _ready() -> void:
	_build_stats()
	if nav_slot == null:
		nav_slot = TabNavSlot.new()
		add_child(nav_slot)
		move_child(nav_slot, 0)
		attach_nav()
	Save.voyage.changed.connect(_refresh_stats)
	Save.activity_log.changed.connect(_refresh_stats)
	_refresh_stats()
	
func attach_nav() -> void:
	nav_slot.tab_selected.connect(_on_tab_selected)
	nav_slot.set_tabs(tab_labels)

func _on_tab_selected(index: int) -> void:
	for i in tab_pages.size():
		tab_pages[i].visible = (i == index)

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
