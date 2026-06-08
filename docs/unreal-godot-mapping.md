# Unreal → Godot 용어 매핑

| Unreal | Godot | 비고 |
|---|---|---|
| 액터/컴포넌트 (합쳐진 개념) | **노드 (Node)** | Godot는 모든 게 노드. 액터와 컴포넌트 구분이 없음 |
| 블루프린트 / 프리팹 (저장된 트리) | **씬 (.tscn)** | 노드들의 트리를 통째로 저장한 것 |
| 컴포넌트 클래스 | 노드 타입 | Label, Button, Timer, Sprite2D … |
| 노드에 붙은 동작 클래스 | **스크립트 (.gd)** | 노드에 attach. 보통 1노드 1스크립트 |
| 다이나믹 멀티캐스트 델리게이트 | **시그널 (signal)** | `signal x` 선언 → `x.emit()` → `x.connect(fn)` |
| AddDynamic / 델리게이트 바인딩 | `signal.connect(callable)` | 에디터에서 GUI로도 연결 가능 |
| GameInstance (전역 영속 객체) | **Autoload 싱글톤** | Project Settings에서 등록, 전역 접근 |
| BeginPlay | `_ready()` | 노드가 트리에 들어오고 준비된 직후 1회 |
| Tick(DeltaSeconds) | `_process(delta)` | 매 프레임 |
| Tick (물리) | `_physics_process(delta)` | 고정 timestep |
| UPROPERTY(EditAnywhere) | `@export var` | Inspector에 노출 |
| 캐스팅 / GetComponent | `$NodePath`, `get_node()` | `$VBox/TimeLabel` 처럼 트리 경로로 접근 |
| `Cast<T>(obj)` | `obj as T` / `is` | 타입 캐스트 / 검사 |
| 레벨 (Level / Map) | 씬 (.tscn) | Godot는 레벨도 그냥 씬 |
| 액터 스폰 | `add_child(instance)` | 씬을 instantiate 후 트리에 추가 |
| DataAsset | **Resource (.tres)** | 데이터 전용 객체, 직렬화/공유 가능 |
| SaveGame | Resource 저장 / FileAccess + JSON | 저장 방식 선택 |

## 라이프사이클 요약
- `_ready()` — BeginPlay
- `_process(delta)` — Tick
- `_physics_process(delta)` — 물리 Tick
- `_input(event)` / `_unhandled_input(event)` — 입력 처리

## 핵심 감각 차이
- Unreal: 액터 + 컴포넌트의 **2계층**.
- Godot: 모든 게 **노드**라는 1계층. "컴포넌트"가 필요하면 그냥 자식 노드로 붙인다.
- 결합 알림은 양쪽 다 **델리게이트/시그널**로 처리 — 사고방식이 거의 동일.
