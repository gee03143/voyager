class_name LetterContent
extends RefCounted

# 병 속 편지 콘텐츠 — 토큰(템플릿+슬롯) 모델.
# 인덱스 = 안정 id이므로 배열은 append-only (중간 삭제/재배치 금지).
# 문자열 원본 = 키. 번역은 TranslationServer가 처리(지금은 원문 그대로 반환).
# 지금은 목업 텍스트들만 작성해두고, 추후 데이터 테이블이나 다른 곳으로 옮겨보자

const TEMPLATES := [
	"오늘은 {0} 노를 저었어요. 당신의 항해도 무사하길.",   # 0
	"{0}, 그래도 우리는 나아가고 있어요.",                  # 1
	"멀리서 같은 바다를 봅니다. {0}.",                      # 2
	"{0} 하루였지만, 무사히 항구에 닿았어요.",              # 3
]

const WORDS := [
	"그저 묵묵히",                  # 0
	"천천히, 그러나 멈추지 않고",   # 1
	"겨우겨우",                     # 2
	"비가 내리는 날에도",           # 3
	"파도가 높은 날에도",           # 4
	"당신은 혼자가 아니에요",       # 5
	"오늘 한 일로 충분합니다",      # 6
	"길고 흐린",                    # 7
	"고단한",                       # 8
]

# 큐레이션 시드 풀 (우리가 검수한 유효 조합). MVP는 이 풀에서만 발견 → 악용 불가.
# 좀 억지스럽긴 하니 자유도는 이거보다는 높게
# 톤도 좀 더 작위적인 따뜻함보다는 솔직한 감정 전달 위주로
const SEED_LETTERS := [
	{"template": 0, "slots": [0]},
	{"template": 0, "slots": [1]},
	{"template": 1, "slots": [3]},
	{"template": 2, "slots": [5]},
	{"template": 2, "slots": [6]},
	{"template": 3, "slots": [8]},
]

static func render(template_id: int, slot_ids: Array) -> String:
	if template_id < 0 or template_id >= TEMPLATES.size():
		return ""
	var words: Array = []
	for sid in slot_ids:
		var i := int(sid)
		if sid >= 0 and sid < WORDS.size():
			words.append(String(TranslationServer.translate(WORDS[sid])))
		else:
			words.append("")
	var tmpl := String(TranslationServer.translate(TEMPLATES[template_id]))
	return tmpl.format(words)
