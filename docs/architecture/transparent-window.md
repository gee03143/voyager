# 투명 창

- `scripts/util/transparency_test.gd` — 확인용 임시 스크립트
- `scenes/TransparencyTest.tscn` — 확인용 임시 씬

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

### 클릭 통과는 폴리곤이 아니라 알파가 정한다

- 투명한 픽셀은 클릭이 통과하고 그려진 픽셀은 클릭을 받는다
- `mouse_passthrough_polygon`을 캐릭터와 어긋나게 줘도 클릭 판정이 안 바뀐다
- 클래스 레퍼런스가 적은 "Windows에서는 폴리곤 바깥이 안 그려진다"도 이 환경에선 일어나지 않는다
- 그래서 말풍선이 떴다 사라질 때 폴리곤을 갱신할 필요가 없다
- 2026-09-21에 확인했다

### 성능은 병목이 아니다

- 투명 창을 띄운 채 FPS 2351이 나왔다 (2026-09-21, RTX 4070 SUPER)
- 비포커스에서 10으로 보이는 것은 `AppSettings.fps_unfocused` 때문이지 투명 때문이 아니다

### 확인하지 않은 것

- Forward+ 렌더러에서도 같은지
- 하이브리드 GPU 노트북에서 동작하는지. 이슈 트래커에 보고가 있다
- 여러 모니터에서 창 위치가 어떻게 잡히는지
