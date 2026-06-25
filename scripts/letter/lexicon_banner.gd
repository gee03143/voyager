extends Node

@export var notice: Notice

func _ready() -> void:
	Save.lexicon.subject_unlocked.connect(_on_unlocked)
	
func _on_unlocked(key: String) -> void:
	notice.show_notice("새 표현을 익혔어요 · %s" % ActivityVocab.ko(key))
