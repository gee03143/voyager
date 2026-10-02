# 투명 창

- `project.godot` — `display/window/size/transparent`, `display/window/per_pixel_transparency/allowed`
- `scripts/shimeji_root.gd` — 투명 창을 쓰는 곳(시메지가 주 창이다)

## 역할

- 바탕화면에 캐릭터만 떠 있는 창을 만든다
- 다이어리 셸과는 별개의 OS 창이다
- 시메지가 이 위에 선다

## 계약

- 프로젝트 설정 `display/window/per_pixel_transparency/allowed`가 켜져 있어야 한다. 이미 켜져 있다
- `Window.transparent`와 `Window.transparent_bg`를 함께 켠다
- `get_tree().root.gui_embed_subwindows = false`라야 진짜 OS 창이 된다
- 클리어 컬러의 알파가 0이어야 배경이 비어 있다
- `Window.always_on_top`은 `transient`가 켜져 있으면 동작하지 않는다

## 주의

### 클리어 컬러가 배경을 덮는다

- `transparent_bg`만으로는 배경이 안 지워진다
- 아무것도 그리지 않아도 `default_clear_color` 색 사각형이 남는다
- `RenderingServer.set_default_clear_color`로 알파 0을 주면 사라진다
- 이 설정은 전역이라 다이어리 셸에도 걸린다. 셸이 자기 배경을 직접 그려야 한다
- `MainShell.tscn`의 루트는 `HBoxContainer`라 배경이 없다. 지금은 클리어 컬러에 기대고 있다
- 2026-09-21에 mobile 렌더러 + d3d12에서 확인했다

### 클릭은 창 사각형 전체가 받는다 — 폴리곤으로 자른다

- 엔진은 투명 창을 `DwmEnableBlurBehindWindow`로만 만든다. 픽셀 알파로 클릭을 거르는 코드가 없다(4.6 `platform/windows/display_server_windows.cpp`의 `WINDOW_FLAG_TRANSPARENT`)
- 그래서 투명한 픽셀도 클릭을 받는다. 시메지 창(280×340) 전체가 뒤의 앱을 가렸다(2026-10-02 유저 보고)
- `mouse_passthrough_polygon`은 `SetWindowRgn`으로 창 영역 자체를 폴리곤으로 자른다(같은 파일 `_update_window_mouse_passthrough`)
- 영역 밖은 클릭뿐 아니라 **그리기도 잘린다**. 폴리곤은 그려지는 것을 전부 덮어야 한다
- 테두리 있는 창이면 폴리곤 좌표가 프레임 두께와 제목줄 높이만큼 밀린다. 시메지 창은 테두리가 없어(`display/window/size/borderless=true`) 밀리지 않는다
- 시메지는 몸 둘레 상자를 폴리곤으로 준다(`shimeji_root.gd`의 `HIT_BOX`). 들어 올려 흔드는 동안·떨어지는 동안·온보딩 동안은 풀어 창 전체로 둔다
- ⚠️ 2026-09-21 판은 "클릭은 알파가 정하고 폴리곤은 판정을 안 바꾼다"였다. 위 엔진 소스와 맞지 않는다. 그때 무엇을 봤는지는 남아 있지 않다. 이번 수정의 F6 확인으로 이 절을 확정한다

### 커서 모양은 매 프레임 직접 집어낸다

- 폴리곤 밖은 창 영역 자체가 아니라서 모션 이벤트가 오지 않는다. 커서가 들어온 것도 나간 것도 이벤트로는 알 수 없다
- 그래서 `shimeji_root.gd`의 `_update_cursor()`가 `_process`에서 커서 자리를 직접 본다. `mouse_entered`/`exited` 류를 쓸 수 없다
- 창에 `Control`이 없어 `Control.mouse_default_cursor_shape`를 쓸 자리가 없다. `Input.set_default_cursor_shape()`로 준다
- ⚠️ `Input`의 기본 모양은 앱 전체에 하나뿐이다(4.6 `core/input/input.cpp`의 `default_shape`). 셸 창에도 같은 값이 걸린다
- 그래서 커서가 몸을 벗어나면 화살표로 되돌린다. 안 되돌리면 셸의 빈 자리까지 모양이 따라간다
- 같은 값을 다시 넣는 것은 엔진이 먼저 걸러낸다(같은 파일 `set_default_cursor_shape`의 이른 반환). 모양이 바뀔 때만 합성 모션 이벤트가 난다
- ⚠️ 모양이 실제로 OS 에 걸리는 것은 `Viewport::_gui_input_event`다. 창이 포커스 없이도 모션을 받는지는 확인 안 됨 — 2026-10-02 F6 확인 대상

### 성능은 병목이 아니다

- 투명 창을 띄운 채 FPS 2351이 나왔다 (2026-09-21, RTX 4070 SUPER)
- 비포커스에서 10으로 보이는 것은 `AppSettings.fps_unfocused` 때문이지 투명 때문이 아니다

### 주 창은 숨길 수 없다

- 시메지 창은 주 창이다. `hide()`나 `visible = false`를 주면 엔진이 거부한다
- 실행 로그: `Can't change visibility of main window` (2026-10-01, 4.6.3)
- 창 크기는 2×2를 줘도 64×64까지만 줄어든다(같은 날 실행 확인)
- 잠시 비켜야 하면 크기를 줄여 모든 모니터 밖 좌표로 옮긴다. 온보딩이 이 방법을 쓴다(`docs/specs/onboarding.md`)
- ⚠️ 모니터 밖에 있는 동안은 `current_screen`이 엉뚱한 모니터를 가리킨다. 돌아올 때는 기준 모니터를 먼저 정한다

### 작업 표시줄 버튼은 창마다 하나씩 뜬다 — 엔진 안에서는 뺄 수 없다

시메지와 셸이 각각 버튼으로 뜬다(2026-10-02 유저 보고). 엔진 소스로 확인한 제약이다(4.6 `platform/windows/display_server_windows.cpp`, `scene/main/window.cpp`).

- 주 창은 `WS_EX_APPWINDOW`를 무조건 받는다(`_get_window_style`). 이 스타일이 붙은 창은 작업 표시줄 버튼이 강제된다
- 엔진은 `WS_EX_TOOLWINDOW`를 어디에도 주지 않는다. 예전엔 테두리 없는 창에 붙였으나 지금은 `WS_POPUP`으로 바뀌었다(같은 함수의 주석)
- 그래서 자식 창도 소유자가 없으면 버튼이 뜬다. 셸이 지금 그 경우다
- 소유자(`GWLP_HWNDPARENT`)가 붙는 유일한 길은 `transient`와 `exclusive`를 둘 다 주는 것이다(`window_set_exclusive`)
- ⚠️ 그런데 `transient`와 `always_on_top`은 서로 배타다. 둘 다 주려 하면 엔진이 거부한다(`window_set_flag`의 `WINDOW_FLAG_ALWAYS_ON_TOP`, `window_set_transient`)
- ⚠️ 그리고 `exclusive` 자식이 있으면 부모 창은 입력을 아예 못 받는다(`Window::_window_input`의 이른 반환). 서브윈도우를 임베드하지 않을 때다 — 이 앱이 그 경우다
- 결론: **항상 위에 있으면서 작업 표시줄에 안 뜨는 창은 조합이 없다.** 주 창·자식 창을 맞바꿔도 마찬가지다
- 빼려면 네이티브로 `WS_EX_TOOLWINDOW`를 직접 붙여야 한다. HWND 는 `DisplayServer.window_get_native_handle()`로 GDScript 에서 얻을 수 있으나 스타일 변경은 GDScript 에 수단이 없다
- 같은 요청이 godot-proposals#8467 에 열려 있다(2026-10-02 확인)

#### 네이티브로는 뺄 수 있다 (2026-10-02 실행 확인)

임시 검증 코드(`scripts/dev/taskbar_probe.gd`)로 확인했다. 아래는 실행으로 확인한 사실이다.

- 시메지 창의 ex-style 에서 `WS_EX_APPWINDOW`를 빼고 `WS_EX_TOOLWINDOW`를 붙이면 버튼이 사라진다
- **창을 숨겼다 다시 보이는 왕복(`SW_HIDE`/`SW_SHOW`)이 필요 없다.** 보이는 창의 스타일만 바꿔도 버튼이 즉시 빠진다
- HWND 는 `DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, DisplayServer.MAIN_WINDOW_ID)`로 GDScript 에서 얻는다. 스타일 변경만 네이티브가 필요하다
- ⚠️ 바꾸는 쪽이 다른 프로세스면 **메인 스레드를 막으면 안 된다.** `SetWindowLongPtr`는 대상 창의 스레드로 `WM_STYLECHANGING`을 동기로 보낸다 — `OS.execute`로 기다리면 서로를 기다려 앱이 멎는다
- 같은 프로세스·같은 스레드에서 부르면(GDExtension) 이 교착은 없다. 보낸 메시지가 제자리에서 처리된다
- **한 번 걸면 유지된다.** 셸을 여닫고 헤이즐을 내보냈다 불러도 버튼이 돌아오지 않았다
- 엔진이 ex-style 을 통째로 덮는 `_update_window_style()`은 `show_window`·`window_set_mode`·`window_set_flag`·최대화 처리에서만 불린다. 창 위치·크기·`mouse_passthrough_polygon` 변경은 안 부른다 — 시메지가 매 프레임 하는 일이 전부 거기 해당한다
- `screen.gd`는 셸 창만 건드린다. 시메지 창의 플래그·모드를 바꾸는 코드가 없다
- 그래서 네이티브로 옮기면 시작할 때 한 번 부르는 함수 하나면 된다. 다시 걸 자리를 찾을 필요가 없다

### 확인하지 않은 것

- 아무것도 그리지 않은 투명 창이 클릭을 통과시키는지. 겹친 셸의 선택지가 눌리지 않은 보고가 있었다(2026-10-01). 위 "창 사각형 전체가 받는다"와 같은 원인으로 보인다

- Forward+ 렌더러에서도 같은지
- 하이브리드 GPU 노트북에서 동작하는지. 이슈 트래커에 보고가 있다
- 여러 모니터에서 창 위치가 어떻게 잡히는지
