class_name ActivityFormat
extends RefCounted

# 활동 이벤트의 표시용 포맷 — 기록 타임라인과 타이머 히스토리가 공유한다.
# Save를 봐야 하는 타입(journal/mood/gratitude)은 여기 없음 — 각 뷰가 자기 문맥에서 처리

const ACCENT := {
	"pomodoro_session": Color("a63d2e"),   # 벽돌
	"timer": Color("2a6491"),              # 잉크 블루
	"todo": Color("7a5c34"),               # 세피아
	"habit": Color("3d7a3f"),              # 수풀
	"journal": Color("6a4e96"),            # 자주
	"gratitude": Color("9a6b12"),          # 황토
	"mood": Color("2a7a72"),               # 청록
}

static func accent_of(type: String) -> Color:
	return ACCENT.get(type, Color.GRAY)

# 세션 시작 시각. start_ts 없는 구버전은 계획치로 역산 — 역산도 불가하면 0
static func start_ts_of(e: Dictionary) -> int:
	if e.has("start_ts"):
		return int(e["start_ts"])
	var secs := int(e.get("seconds", 0))
	if secs <= 0:
		return 0
	return int(e.get("ts", 0)) - secs

static func is_approx(e: Dictionary) -> bool:
	return not e.has("start_ts")          # 키 유무가 판정 기준 — 역산값을 파일에 굳히지 않음

# 구간 표기. 다른 날인 쪽에만 날짜를 붙인다
static func span_text(start_ts: int, end_ts: int, day_iso: String) -> String:
	var start_text := DateUtil.format_time_hm(start_ts)
	var end_text := DateUtil.format_time_hm(end_ts)
	if DateUtil.local_day_iso(start_ts) != day_iso:
		return TranslationServer.translate("RECORD_SPAN_CROSSDAY").format({
			"day": DateUtil.format_day(DateUtil.local_day_iso(start_ts)),
			"start": start_text, "end": end_text})
	if DateUtil.local_day_iso(end_ts) != day_iso:
		return TranslationServer.translate("RECORD_SPAN_CROSSDAY_END").format({
			"day": DateUtil.format_day(DateUtil.local_day_iso(end_ts)),
			"start": start_text, "end": end_text})
	return "%s–%s" % [start_text, end_text]

# 세션 요약 라벨. 세션 계열이 아니면 빈 문자열
static func session_label(e: Dictionary) -> String:
	var subj := _subject_prefix(e)
	match str(e.get("type", "")):
		"timer":
			return TranslationServer.translate("RECORD_EVENT_TIMER").format({
				"subj": subj, "time": mmss(int(e.get("seconds", 0)))})
		"pomodoro_session":
			var cnt := int(e.get("focus_count", 0))
			var each := (int(e.get("seconds", 0)) / cnt) if cnt > 0 else 0
			return TranslationServer.translate("RECORD_EVENT_POMO").format({
				"subj": subj, "count": cnt, "time": mmss(each)})
	return ""

static func mmss(secs: int) -> String:
	return "%d:%02d" % [secs / 60, secs % 60]

static func _subject_prefix(e: Dictionary) -> String:
	var key := str(e.get("subject", ""))
	return "%s · " % ActivityVocab.ko(key) if key != "" else ""
