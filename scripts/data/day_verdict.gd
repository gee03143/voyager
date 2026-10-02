class_name DayVerdict
extends RefCounted

signal changed

# 하루 판정 — 유저가 자기 하루에 붙인 이름. verdict.json (docs/specs/day-verdict.md)
# entries: [{id, ts, kind, text}]   kind: held | endured | drifted | custom. text 는 custom 일 때만 쓴다
# 선택지는 문구가 아니라 종류로 저장한다 — 문구를 고치거나 옮겨도 지난 판정이 그대로 읽힌다
# 날짜에 묶지 않는다. 마지막 판정에서 GAP_SEC 가 지나면 다음 판정을 받는다. 판정 하나가 하루 하나다
# 한 번 정하면 끝이다. 고치는 함수를 두지 않는다

const KINDS := ["held", "endured", "drifted", "custom"]
## 선택지로 고르는 종류와 그 이름 문구. custom 은 유저가 적은 text 가 이름이다
const NAME_KEYS := {"held": "VERDICT_HELD", "endured": "VERDICT_ENDURED", "drifted": "VERDICT_DRIFTED"}
const GAP_SEC := 6 * 3600

# ⚠️ 색인은 아래 add 와 from_dict 안에서만 유지된다(docs/architecture/store-id-index.md).
var entries: Array = []              # ts 오름차순. add 가 끝에 붙이므로 저절로 유지된다
var _by_id: Dictionary = {}          # id → entries의 항목(같은 참조)

func add(kind: String, text: String = "") -> int:
	if not kind in KINDS:
		return 0
	var id := IdGen.fresh(_by_id)            # 색인이 곧 사용 중 id 집합이다
	var e := {"id": id, "ts": DateUtil.now_unix(), "kind": kind, "text": text if kind == "custom" else ""}
	entries.append(e)
	_by_id[id] = e
	changed.emit()
	return id

## 지금 판정을 받을 수 있는가. 마지막 판정에서 GAP_SEC 가 지났거나 판정이 없으면 참
func can_judge(now: int) -> bool:
	return entries.is_empty() or now - int(entries[-1]["ts"]) >= GAP_SEC

## 판정의 이름. 화면에 보일 문자열이다
static func name_of(e: Dictionary) -> String:
	var kind := str(e.get("kind", ""))
	if kind == "custom":
		return str(e.get("text", ""))
	return TranslationServer.translate(NAME_KEYS.get(kind, ""))

func latest() -> Dictionary:
	return {} if entries.is_empty() else entries[-1]

## 판정한 날 수. 로어 해금이 이 수를 센다(docs/companion-persona.md §6)
func count() -> int:
	return entries.size()

func to_dict() -> Dictionary:
	return {"entries": entries}

func from_dict(d: Dictionary) -> void:
	entries = []
	var re = d.get("entries", [])
	if typeof(re) == TYPE_ARRAY:
		for x in re:
			if typeof(x) != TYPE_DICTIONARY:
				continue
			var kind := str(x.get("kind", ""))
			if not kind in KINDS:
				continue
			x["id"] = int(x.get("id", 0))
			x["ts"] = int(x.get("ts", 0))
			x["kind"] = kind
			x["text"] = str(x.get("text", ""))
			entries.append(x)
	entries.sort_custom(func(a, b): return a["ts"] < b["ts"])
	_reindex()

func _reindex() -> void:
	_by_id.clear()
	for e in entries:
		_by_id[int(e.get("id", 0))] = e
