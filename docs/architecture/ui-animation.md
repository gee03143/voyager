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

### 컨테이너는 자식의 위치·크기·rotation·scale을 되돌린다

- `Container.fit_child_in_rect()`가 자식에게 `set_rect()`·`set_rotation(0)`·`set_scale(Vector2(1,1))`을 건다
- 근거: 엔진 소스 `scene/gui/container.cpp`의 `fit_child_in_rect` 끝부분
- 레이아웃이 다시 정렬되는 순간(자식 추가·삭제, 최소 크기 변화, 컨테이너 리사이즈) 트윈이 세운 값이 전부 돌아간다
- 애니메이션이 어긋나는 게 아니라 통째로 사라지므로 원인을 찾기 어렵다
- 크기가 고정된 순수 `Control`을 사이에 끼우고 그 안쪽(앵커 Full Rect)에 애니메이션을 건다
- 적용 사례: 배너의 `StampSlot`(Control) 안 `StampImage`
- 같은 이유로 `DayTimeline`의 `Track`도 앵커 배치를 쓴다
- ⚠️ 재정렬은 `queue_sort()`가 걸릴 때만 일어나므로, 아무 일도 없으면 위치 트윈이 한동안 버틴다. 안 걸린 게 아니라 아직 안 걸린 것이다

### 높이는 컨테이너와 싸우지 않고 애니메이션할 수 있다

- `fit_child_in_rect`는 자식의 `get_combined_minimum_size()`를 읽어 배치를 정한다
- 그래서 `custom_minimum_size`를 트윈하면 컨테이너가 그 값을 따라온다
- 형제 요소들이 밀려나는 것까지 컨테이너가 알아서 처리한다
- 리스트 행이 펼쳐지고 접히는 연출은 이 방식을 쓴다

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

### 이동 래퍼의 클리핑은 상시로 건다

- 미끄러져 들어오는 요소는 영역 밖으로 삐져나오므로 `clip_contents`가 필요하다
- 연출이 도는 동안에만 켜고 싶어지지만, 그러면 **평소에 영역을 벗어나는 것을 못 막는다**
- 패널이 영역보다 큰 최소 크기를 가지면 컨테이너가 공간을 못 주고, 그 내용이 영역 밖으로 넘친다
- 루트가 가운데 정렬 컨테이너면 위아래 양쪽으로 넘쳐 바깥 UI까지 덮는다
- 콘텐츠 영역은 무슨 일이 있어도 벗어나지 않는 게 우선이다. 상시로 켠다
- ⚠️ 넘치는 내용은 클리핑으로 가려질 뿐 사라지지 않는다. 그건 레이아웃에서 따로 풀 문제다

### 래퍼로 옮길 때 오프셋을 확실히 초기화한다

- `Node.reparent()`는 기본으로 전역 변형을 유지하며, 그 보정이 오프셋으로 남는다
- 옮길 때마다 쌓이면 패널이 엉뚱한 자리에 놓인다
- `reparent(부모, false)`로 보정을 끄고 옮긴다
- ⚠️ `set_anchors_preset()`은 **앵커만** 바꾸고 오프셋은 그대로 둔다(`doc/classes/Control.xml`)
- 래퍼를 정확히 채우려면 `set_anchors_and_offsets_preset()`을 쓴다
- 적용 사례: 콘텐츠 스왑에서 패널이 어긋난 자리에 그려지던 문제

### 자식의 최소 크기를 래퍼가 대신 올리지 않는다

- 순수 `Control` 래퍼는 컨테이너가 아니라 자식의 최소 크기를 위로 전달하지 않는다
- `custom_minimum_size`로 직접 옮기고 싶어지지만 하지 않는다
- 패널의 최소 크기가 창보다 크면 그 값이 위로 전파되면서 바깥 레이아웃을 밀어낸다
- 배너처럼 옆에 있던 것이 밀려나 화면이 무너진다
- 래퍼는 주어진 공간만 차지하고, 넘치는 것은 클리핑이 막는다

### `Window` 파생 노드에는 트윈을 걸 수 없다

- `PopupPanel`·`AcceptDialog` 등은 `Window`를 상속하고, `Window`는 `Viewport`를 상속한다
- `CanvasItem`이 아니므로 `modulate`도 `scale`도 `rotation`도 없다
- 근거: 엔진 문서 `doc/classes/Window.xml`의 `inherits` 속성
- 창을 페이드하거나 키우려면 창이 아니라 **창 안의 Control**에 걸어야 한다
- 적용 사례: 마감일 선택과 그룹 편집 팝업은 창을 즉시 띄우고 내용만 연출한다
