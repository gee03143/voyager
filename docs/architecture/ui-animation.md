# UI 애니메이션 공통 제약

트윈을 쓰는 모든 뷰에 적용된다. 현재 사례는 `scripts/companion/companion_banner.gd`(발화 연출·도장).

## 역할

- Godot 컨트롤에 트윈을 걸 때 반복해서 걸리는 엔진 제약을 한곳에 모은다
- 근거를 함께 적어 같은 것을 다시 파지 않게 한다. 전부 엔진 소스나 공식 문서에서 확인한 값이다

## 계약

- 애니메이션 대상 노드는 컨테이너의 직계 자식이면 안 된다
- 무언가를 감출 때는 `visible`이 아니라 `modulate.a`를 쓴다
- 글자를 하나씩 드러내는 라벨은 `visible_characters_behavior`를 바꾼 뒤에 쓴다
- 클릭을 부모까지 올리려면 중간 노드의 `mouse_filter`를 직접 열어야 한다

## 주의

### 컨테이너는 자식의 scale과 rotation을 초기화한다

- `Container`는 자식을 배치할 때 위치·크기뿐 아니라 rotation·scale까지 되돌린다
- 레이아웃이 다시 정렬되는 순간(문구 교체·버튼 생성 등) 트윈이 세운 scale이 1.0으로 돌아간다
- 애니메이션이 어긋나는 게 아니라 통째로 사라지므로 원인을 찾기 어렵다
- 크기가 고정된 순수 `Control`을 사이에 끼우고 그 안쪽(앵커 Full Rect)에 애니메이션을 건다
- 적용 사례: 배너의 `StampSlot`(Control) 안 `StampImage`
- 같은 이유로 `DayTimeline`의 `Track`도 앵커 배치를 쓴다

### 숨김은 `visible`이 아니라 알파로

- 컨테이너는 숨겨진 자식을 배치에서 뺀다
- `visible`을 켜는 순간 행 전체가 리플로우되어 옆 요소가 튄다
- 자리는 항상 차지하게 두고 `modulate.a`로 감춘다
- 적용 사례: 배너의 도장, 그리고 타이핑이 끝나기 전의 선택지 버튼

### 라벨 타이핑은 `VC_CHARS_AFTER_SHAPING`으로

- `Label.visible_characters`를 늘리면 글자가 하나씩 드러난다
- 기본값 `VC_CHARS_BEFORE_SHAPING`은 숨긴 글자를 줄바꿈과 크기 계산에서 아예 뺀다
- 그래서 autowrap 라벨이면 글자가 드러날 때마다 줄이 다시 접히고 높이가 변한다
- `TextServer.VC_CHARS_AFTER_SHAPING`은 전체 텍스트로 shaping을 끝낸 뒤 글리프만 가리므로 레이아웃이 고정된다
- 근거: 엔진 문서 `doc/classes/TextServer.xml`의 `VC_CHARS_BEFORE_SHAPING` 설명
- ⚠️ `get_total_character_count()`는 공백과 줄바꿈을 뺀 수라 `visible_characters`의 단위와 다르다. 목표값에는 `String.length()`를 쓴다

### `mouse_filter` 기본값은 노드 타입마다 다르다

- 클릭을 부모까지 올리려면 중간에 낀 노드가 STOP인지 먼저 확인해야 한다
- `Container`(Margin·HBox·VBox 등) = PASS
- `PanelContainer` = STOP
- `Control` = STOP
- `Label` = IGNORE
- `TextureRect` = PASS
- `Button` = STOP
- 근거: 엔진 소스 `scene/gui/*.cpp`의 각 생성자와 `scene/gui/control.h`의 기본값
- 감춘 컨트롤 위의 클릭을 통과시키려면 그 컨트롤을 IGNORE로 내린다. `HoverReveal`이 같은 방식을 쓴다
- 적용 사례: 배너 전체를 스킵 대상으로 만들려고 `Bubble`·`AvatarSlot`·`StampSlot`을 PASS로 내렸다
- `NoteEdit`은 STOP으로 남겼다. 노트를 쓰는 중에 스킵이 먹으면 안 되기 때문이다
