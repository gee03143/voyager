extends RefCounted

## 개발자 콘솔의 taskbar 명령(docs/specs/dev-console.md). 시메지 창의 작업 표시줄 버튼을 떼보거나 되돌린다.
## 시메지 창(주 창)의 WS_EX_APPWINDOW 를 빼고 WS_EX_TOOLWINDOW 를 붙이면 버튼이 사라진다
## (확인한 사실은 docs/architecture/transparent-window.md 의 "작업 표시줄 버튼"이 갖는다).
##
## ⚠️ 이것은 손으로 켜는 도구지 앱의 기능이 아니다. 그 실행 동안만 유효하고 다시 켜면 버튼이 돌아온다.
## 앱이 스스로 하려면 GDScript 에 수단이 없어 네이티브(GDExtension)가 필요하다.
## 출시 빌드가 제 창을 만지려고 PowerShell 을 부르게 두지 않는다 — AV 가 싫어하고 시작이 느려진다.
##
## ⚠️ 막으면 안 된다. SetWindowLongPtr 는 대상 창의 스레드로 WM_STYLECHANGING 을 **동기로 보낸다**.
## OS.execute 로 메인 스레드를 막으면 Godot 은 PowerShell 을, PowerShell 은 Godot 의 메시지 펌프를
## 서로 기다려 앱이 멎는다(2026-10-02 실행 확인). 그래서 create_process 로 띄우고 결과는 파일로 받는다.
## GDExtension 으로 옮기면 이 문제는 없다 — 같은 스레드에서 부르므로 보낸 메시지가 제자리에서 처리된다.

const PS1 := "user://taskbar_probe.ps1"
const RESULT := "user://taskbar_probe.txt"

## GWL_EXSTYLE(-20) 을 읽고 고친다. SW_HIDE(0)/SW_SHOW(5) 왕복은 action 이 요구할 때만 한다 —
## 작업 표시줄은 창이 보여질 때 버튼 여부를 정하므로, 왕복이 필요한지가 이 검증의 핵심 질문이다
const BODY := """param([long]$Hwnd, [string]$Action = "status", [string]$Out = "")
$ErrorActionPreference = "Stop"
Add-Type -Namespace Probe -Name Win -MemberDefinition @'
[DllImport("user32.dll", SetLastError=true)]
public static extern IntPtr GetWindowLongPtrW(IntPtr hWnd, int nIndex);
[DllImport("user32.dll", SetLastError=true)]
public static extern IntPtr SetWindowLongPtrW(IntPtr hWnd, int nIndex, IntPtr dwNewLong);
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
$h = [IntPtr]$Hwnd
$GWL_EXSTYLE = -20
$APP = 0x00040000
$TOOL = 0x00000080
$before = [int64][Probe.Win]::GetWindowLongPtrW($h, $GWL_EXSTYLE)
$new = $before
if ($Action -eq "hide" -or $Action -eq "dance") { $new = ($before -band (-bnot $APP)) -bor $TOOL }
if ($Action -eq "restore") { $new = ($before -bor $APP) -band (-bnot $TOOL) }
$roundtrip = ($Action -eq "dance" -or $Action -eq "restore")
if ($roundtrip) { [void][Probe.Win]::ShowWindow($h, 0) }
if ($new -ne $before) { [void][Probe.Win]::SetWindowLongPtrW($h, $GWL_EXSTYLE, [IntPtr]$new) }
if ($roundtrip) { [void][Probe.Win]::ShowWindow($h, 5) }
$after = [int64][Probe.Win]::GetWindowLongPtrW($h, $GWL_EXSTYLE)
$line = "exstyle {0:X8} -> {1:X8} / appwindow={2} toolwindow={3} / roundtrip={4}" -f $before, $after, (($after -band $APP) -ne 0), (($after -band $TOOL) -ne 0), $roundtrip
if ($Out -ne "") { Set-Content -LiteralPath $Out -Value $line -Encoding ASCII } else { $line }
"""


## action 은 status(읽기만) / hide(스타일만) / dance(SW_HIDE·SW_SHOW 왕복) / restore(원래대로) 다.
## 띄우기만 하고 기다리지 않는다 — 기다리면 교착이다(위 주석). 결과는 read() 로 받는다
static func start(action: String) -> String:
	var hwnd := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, DisplayServer.MAIN_WINDOW_ID)
	if hwnd == 0:
		return "HWND 를 못 얻었다. Windows 가 아니거나 창이 없다"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RESULT))   # 지난 결과를 치운다
	var f := FileAccess.open(PS1, FileAccess.WRITE)
	if f == null:
		return "ps1 쓰기 실패(%d)" % FileAccess.get_open_error()
	f.store_string(BODY)
	f.close()
	var pid := OS.create_process("powershell.exe", [
		"-NoProfile", "-ExecutionPolicy", "Bypass",
		"-File", ProjectSettings.globalize_path(PS1),
		"-Hwnd", str(hwnd), "-Action", action,
		"-Out", ProjectSettings.globalize_path(RESULT),
	])
	if pid == -1:
		return "powershell 실행 실패"
	return "hwnd=%d pid=%d · %s 보내는 중" % [hwnd, pid, action]


## 결과 파일을 읽는다. 아직 없으면 빈 문자열이다
static func read() -> String:
	if not FileAccess.file_exists(RESULT):
		return ""
	var f := FileAccess.open(RESULT, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text().strip_edges()
	f.close()
	return text
