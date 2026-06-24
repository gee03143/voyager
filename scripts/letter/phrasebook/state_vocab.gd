class_name StateVocab
# 상태(State) — 짧은 1인칭 평가(전보체). key=번역키, ko=표기.
const STATES := [
	{"key": "barely", "ko": "겨우"},
	{"key": "finally", "ko": "드디어"},
	{"key": "went_well", "ko": "잘됨"},
	{"key": "meh", "ko": "영 별로"},
	{"key": "still_did", "ko": "그래도 함"},
	{"key": "kept_off", "ko": "계속 미룸"},
	{"key": "couldnt", "ko": "손도 못 댐"},
	{"key": "tomorrow", "ko": "내일은"},
	{"key": "long_time", "ko": "오랜만에"},
]

static func ko(key: String) -> String:
	for s in STATES:
		if s["key"] == key:
			return str(s["ko"])
	return ""
