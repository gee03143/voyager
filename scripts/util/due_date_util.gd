class_name DateUtil
extends RefCounted

const DAY_NAME_KEYS := ["DATE_MON", "DATE_TUE", "DATE_WED", "DATE_THU", "DATE_FRI", "DATE_SAT", "DATE_SUN"]  # 월요일 시작 — month_grid()와 순서 일치 필수

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
		return TranslationServer.translate("DATE_TODAY")
	if days == 1:
		return TranslationServer.translate("DATE_TOMORROW")
	var year := int(p[0])
	if year == Time.get_date_dict_from_system().year:
		return "%d/%d" % [int(p[1]), int(p[2])]            # 올해 → 월/일
	return "%d/%d/%d" % [year, int(p[1]), int(p[2])]       # 다른 해 → 연/월/일
	
# 기록용 상대 날짜: 오늘/어제/날짜 (format_due의 과거형)
static func format_day(iso: String) -> String:
	var d := days_until(iso)
	if d == 0:
		return TranslationServer.translate("DATE_TODAY")
	if d == -1:
		return TranslationServer.translate("DATE_YESTERDAY")
	var p := iso.split("-")
	if p.size() != 3:
		return iso
	if int(p[0]) == Time.get_date_dict_from_system().year:
		return "%d/%d" % [int(p[1]), int(p[2])]
	return "%d/%d/%d" % [int(p[0]), int(p[1]), int(p[2])]

static func format_created(ts: int) -> String:        # ts → "D/M/YYYY"
	var p := local_day_iso(ts).split("-")
	return "%d/%d/%d" % [int(p[2]), int(p[1]), int(p[0])]

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
	
# UTC unix ts → 로컬 날짜 iso (tz bias)
static func local_day_iso(ts: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	var d := Time.get_datetime_dict_from_unix_time(ts + bias * 60)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

# "YYYY-MM-DD" + N일
static func add_days(iso: String, days: int) -> String:
	var p := iso.split("-")
	if p.size() != 3:
		return iso
	var u := Time.get_unix_time_from_datetime_dict({"year": int(p[0]), "month": int(p[1]), "day": int(p[2]), "hour": 0, "minute": 0, "second": 0})
	var d := Time.get_datetime_dict_from_unix_time(int(u + days * 86400))
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]

# 오늘 로컬 날짜 iso
static func today_iso() -> String:
	var t := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]
	
static func format_hours(seconds: float) -> String:
	return "%dh" % int(round(seconds / 3600.0))

static func month_start_iso() -> String:
	var t := Time.get_date_dict_from_system()
	return "%04d-%02d-01" % [t.year, t.month]
	
static func days_in_month(iso: String) -> int:
	var p := iso.split("-")
	var y := int(p[0])
	var m := int(p[1])
	var nm := m + 1
	var ny := y
	if nm > 12:
		nm = 1
		ny += 1
	var a := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var b := Time.get_unix_time_from_datetime_dict({"year": ny, "month": nm, "day": 1, "hour": 0, "minute": 0, "second": 0})
	return int((b - a) / 86400)

static func add_months(iso: String, months: int) -> String:
	var p := iso.split("-")
	var total := int(p[1]) - 1 + months
	var year := int(p[0]) + int(floor(float(total) / 12.0))
	var month := ((total % 12) + 12) % 12 + 1
	return "%04d-%02d-01" % [year, month]

static func month_label(iso: String) -> String:
	var p := iso.split("-")
	return TranslationServer.translate("DATE_MONTH_LABEL").format({"year": int(p[0]), "month": int(p[1])})

static func year_start_iso() -> String:
	var t := Time.get_date_dict_from_system()
	return "%04d-01-01" % t.year

static func year_label(iso: String) -> String:
	return TranslationServer.translate("DATE_YEAR_LABEL").format({"year": int(iso.split("-")[0])})

static func month_grid(iso: String) -> Array:
	var p := iso.split("-")
	var y := int(p[0])
	var m := int(p[1])
	var first := Time.get_unix_time_from_datetime_dict({"year": y, "month": m, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var first_wd := int(Time.get_datetime_dict_from_unix_time(int(first)).weekday)   # 0=일..6=토
	var grid: Array = []
	for i in (first_wd + 6) % 7:        # 월요일 시작 정렬용 선행 빈칸
		grid.append("")
	for day in range(1, days_in_month("%04d-%02d-01" % [y, m]) + 1):
		grid.append("%04d-%02d-%02d" % [y, m, day])
	return grid
