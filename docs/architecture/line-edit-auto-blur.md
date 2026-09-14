# 바깥 클릭으로 포커스 해제 — `LineEditAutoBlur`

`scripts/commonui/line_edit_auto_blur.gd`. 입력칸의 자식 노드로 붙이고 `target`으로 그 입력칸을 가리킨다.

## 역할

- 입력칸 바깥을 클릭하면 포커스를 푼다
- 포커스 해제를 커밋 신호로 쓰는 뷰들이 이 노드에 의존한다

## 계약

- `target`이 포커스를 가진 동안에만 `_input` 처리를 켠다. 평소에는 전역 입력을 감시하지 않는다
- 클릭 판정은 `target`의 글로벌 사각형 바깥인지로만 한다
- 포커스를 풀기 전에 `ImeCommitGuard.flush()`를 부른다. 이유는 `docs/architecture/ime-commit-guard.md`의 "autoload의 `_input`은 씬 노드보다 늦게 불린다"에 있다

## 주의

### 이 노드가 붙지 않은 입력칸도 있다

- 감사 항목, 컴패니언 노트, 런타임에 만드는 그룹 이름 칸에는 붙어 있지 않다
- 그 칸들은 GUI 포커스 전환이 `_input` 뒤에 일어나므로 `ImeCommitGuard`가 직접 처리한다
- 즉 이 노드가 없어도 IME 되메우기는 동작한다. 이 노드는 포커스 해제 편의를 위한 것이다
