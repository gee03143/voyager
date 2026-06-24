class_name ActivityVocab
# 큐레이션 활동 어휘(Subject). key=안정 번역키, ko=한국어 표기.
const SUBJECTS := [
	{"key": "coding", "ko": "코딩"},
	{"key": "study", "ko": "공부"},
	{"key": "exercise", "ko": "운동"},
	{"key": "writing", "ko": "글쓰기"},
	{"key": "drawing", "ko": "그림"},
	{"key": "reading", "ko": "독서"},
	{"key": "music", "ko": "악기 연습"},
	{"key": "jobhunt", "ko": "구직"},
	{"key": "chores", "ko": "집안일"},
]

static func ko(key: String) -> String:
	for s in SUBJECTS:
		if s["key"] == key:
			return str(s["ko"])
	return ""
