class_name IdGen
extends RefCounted

# randi 기반 안정 ID + 충돌 가드. used = {id: true} (사용 중 집합).
# randi는 후보 공급기일 뿐 — 유일성 보장은 이 멤버십 검사가 한다(로컬 한정).
static func fresh(used: Dictionary) -> int:
	var id := randi()
	while id == 0 or used.has(id):
		id = randi()
	return id
