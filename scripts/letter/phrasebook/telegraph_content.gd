class_name TelegraphContent
# 전보체 편지. 템플릿 = 슬롯 나열 문자열. 슬롯: {subject} {fact} {state}
# 조사 빼고 공백 나열(다크소울식). 구두점 바꾸려면 템플릿 문자열만 수정.
const TEMPLATES := [
	"{subject} {fact} {state}",      # 코딩 두 시간 겨우
	"{subject} {state}",             # 코딩 계속 미룸
	"{fact} 만에 {subject}",          # 세 번째 만에 코딩
]

# subject/state = 어휘 key, fact = 실값 문자열("두 시간"/"세 번째"/"" )
static func render(template_idx: int, subject_key: String, fact: String, state_key: String) -> String:
	var t: String = TEMPLATES[clampi(template_idx, 0, TEMPLATES.size() - 1)]
	t = t.replace("{subject}", ActivityVocab.ko(subject_key))
	t = t.replace("{fact}", fact)
	t = t.replace("{state}", StateVocab.ko(state_key))
	while t.contains("  "):              # 빈 슬롯으로 생긴 이중 공백 정리
		t = t.replace("  ", " ")
	return t.strip_edges()

# 테스트용 무작위 편지(통제 어휘 안에서 랜덤 — 악용 불가, 다만 어색 조합 가능).
const _TEST_FACTS := ["두 시간", "삼십 분", "한 시간", "사십 분", "다섯 시간", ""]

static func random_letter() -> Dictionary:
	var subj = ActivityVocab.SUBJECTS[randi() % ActivityVocab.SUBJECTS.size()]
	var st = StateVocab.STATES[randi() % StateVocab.STATES.size()]
	return {
		"template_idx": randi() % TEMPLATES.size(),
		"subject": str(subj["key"]),
		"fact": _TEST_FACTS[randi() % _TEST_FACTS.size()],
		"state": str(st["key"]),
	}
