class_name DateUtil
extends RefCounted

# "YYYY-MM-DD" → 오늘까지 남은 일수 (음수=지남). 빈/형식오류는 호출부에서 거른다.
static func days_until(iso: String) -> int:
	var p := iso.split("-")
	var due := Time.get_unix_time_from_datetime_dict(
		{"year": int(p[0]), "month": int(p[1]), "day": int(p[2]), "hour": 0, "minute": 0, "second": 0})
	var t := Time.get_date_dict_from_system()
	var today := Time.get_unix_time_from_datetime_dict(
		{"year": t.year, "month": t.month, "day": t.day, "hour": 0, "minute": 0, "second": 0})
	return int((due - today) / 86400.0)

# 마감일 표시 텍스트: 오늘/내일/월·일. 빈 문자열은 "".
static func format_due(iso: String) -> String:
	if iso.is_empty():
		return ""
	var p := iso.split("-")
	if p.size() != 3:
		return iso
	var days := days_until(iso)
	if days == 0:
		return "오늘"
	if days == 1:
		return "내일"
	var year := int(p[0])
	if year == Time.get_date_dict_from_system().year:
		return "%d/%d" % [int(p[1]), int(p[2])]            # 올해 → 월/일
	return "%d/%d/%d" % [year, int(p[1]), int(p[2])]       # 다른 해 → 연/월/일

static func monday_iso() -> String:
	var t := Time.get_date_dict_from_system()
	var days_back := (int(t.weekday) + 6) % 7          # weekday: 일0..토6 → 월요일까지 거슬러
	var today_unix := Time.get_unix_time_from_datetime_dict(
		{"year": t.year, "month": t.month, "day": t.day, "hour": 0, "minute": 0, "second": 0})
	var m := Time.get_datetime_dict_from_unix_time(int(today_unix - days_back * 86400))
	return "%04d-%02d-%02d" % [m.year, m.month, m.day]
	
# 월요일 ISO → "M/D ~ M/D" (월·연 넘어가도 unix로 +6일 계산해 정확)
static func week_range_label(monday_iso: String) -> String:
	var p := monday_iso.split("-")
	if p.size() != 3:
		return monday_iso
	var mon_unix := Time.get_unix_time_from_datetime_dict(
		{"year": int(p[0]), "month": int(p[1]), "day": int(p[2]), "hour": 0, "minute": 0, "second": 0})
	var sun := Time.get_datetime_dict_from_unix_time(int(mon_unix + 6 * 86400))
	return "%d/%d ~ %d/%d" % [int(p[1]), int(p[2]), sun.month, sun.day]
