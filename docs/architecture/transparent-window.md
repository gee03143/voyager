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

### 성능은 병목이 아니다

- 투명 창을 띄운 채 FPS 2351이 나왔다 (2026-09-21, RTX 4070 SUPER)
- 비포커스에서 10으로 보이는 것은 `AppSettings.fps_unfocused` 때문이지 투명 때문이 아니다

### 주 창은 숨길 수 없다

- 시메지 창은 주 창이다. `hide()`나 `visible = false`를 주면 엔진이 거부한다
- 실행 로그: `Can't change visibility of main window` (2026-10-01, 4.6.3)
- 창 크기는 2×2를 줘도 64×64까지만 줄어든다(같은 날 실행 확인)
- 잠시 비켜야 하면 크기를 줄여 모든 모니터 밖 좌표로 옮긴다. 온보딩이 이 방법을 쓴다(`docs/specs/onboarding.md`)
- ⚠️ 모니터 밖에 있는 동안은 `current_screen`이 엉뚱한 모니터를 가리킨다. 돌아올 때는 기준 모니터를 먼저 정한다

### 확인하지 않은 것

- 아무것도 그리지 않은 투명 창이 클릭을 통과시키는지. 겹친 셸의 선택지가 눌리지 않은 보고가 있었다(2026-10-01). 위 "창 사각형 전체가 받는다"와 같은 원인으로 보인다

- Forward+ 렌더러에서도 같은지
- 하이브리드 GPU 노트북에서 동작하는지. 이슈 트래커에 보고가 있다
- 여러 모니터에서 창 위치가 어떻게 잡히는지
