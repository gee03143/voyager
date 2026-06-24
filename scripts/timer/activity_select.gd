class_name ActivitySelect
extends OptionButton

# "없음" + 큐레이션 활동을 채우고, 선택을 Clock.current_activity에 반영(공유).
func _ready() -> void:
	_populate()
	item_selected.connect(_on_selected)
	visibility_changed.connect(func(): if visible: _sync())

func _populate() -> void:
	clear()
	add_item("없음")                        # index 0
	for s in ActivityVocab.SUBJECTS:
		add_item(str(s["ko"]))               # index 1..N
	_sync()

func _sync() -> void:                        # Clock.current_activity → 선택 반영(탭 전환 동기화)
	var sel := 0
	for i in ActivityVocab.SUBJECTS.size():
		if str(ActivityVocab.SUBJECTS[i]["key"]) == Clock.current_activity:
			sel = i + 1
			break
	select(sel)

func _on_selected(index: int) -> void:
	Clock.current_activity = "" if index == 0 else str(ActivityVocab.SUBJECTS[index - 1]["key"])
