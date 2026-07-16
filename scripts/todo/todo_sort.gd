class_name TodoSort
extends RefCounted

enum Key { MANUAL, DUE, NAME, DONE }
const NAMES := ["TODO_SORT_MANUAL", "TODO_SORT_DUE", "TODO_SORT_NAME", "TODO_SORT_DONE"]

var _desc := false
var _idx := {}                          # 동순위 tiebreak = 수동 순서

func ordered(rows: Array, key: int, desc: bool) -> Array:
	_desc = desc
	_idx.clear()
	for i in rows.size():
		_idx[rows[i]] = i
	var result := rows.duplicate()
	match key:
		Key.DUE:  result.sort_custom(_cmp_due)
		Key.NAME: result.sort_custom(_cmp_name)
		Key.DONE: result.sort_custom(_cmp_done)
		_:                                  # 수동: 항상 _rows 순서 그대로
			pass
	return result

func _cmp_due(a: TodoRow, b: TodoRow) -> bool:
	var da := a.get_due()
	var db := b.get_due()
	if da.is_empty() or db.is_empty():
		if da.is_empty() == db.is_empty():
			return _idx[a] < _idx[b]
		return db.is_empty()                # 없는 건 항상 뒤
	if da == db: return _idx[a] < _idx[b]
	return (da < db) != _desc

func _cmp_name(a: TodoRow, b: TodoRow) -> bool:
	var na := a.get_text().to_lower()
	var nb := b.get_text().to_lower()
	if na == nb: return _idx[a] < _idx[b]
	return (na < nb) != _desc

func _cmp_done(a: TodoRow, b: TodoRow) -> bool:
	if a.is_done() == b.is_done(): return _idx[a] < _idx[b]
	return (not a.is_done()) != _desc
