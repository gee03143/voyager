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
