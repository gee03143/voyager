# Voyage 프로젝트 컨텍스트

## 프로젝트
- **Voyage**: Godot 4.6 생산성 앱 (포모도로/Todo + 항해 테마, 데스크톱 컴패니언)
- 경로: `C:\Users\NHN\Documents\voyager` (Vrem/Unreal 과 무관한 별도 저장소)
- 사용자: Unreal/C++ 경험 많음, Godot 입문
- **상세 설계·현재 상태**: `docs/architecture.md` · **로드맵**: `docs/roadmap.md`
  → 세션 시작 시 이 두 파일을 먼저 읽고 진행

## 작업 규칙 (반드시 지킬 것)
1. **코드는 사용자가 직접 타이핑** — `.gd`/`.tscn` 직접 편집 금지, 코드는 *텍스트로 제시*만.
   (docs/roadmap/에셋 파일은 생성·편집 OK)
2. 코드 질문/디버그는 **먼저 코드 읽기** — 추측 답변 금지, 근거(핀 연결/노드 정의 등) 기반으로만
3. 검토 요청 시 **항상 현재 파일을 다시 읽고** 판단 (이전 grep/read 결과 캐시 사용 금지)
4. 한국어 존댓말, 간결. 표/체크리스트 남발 금지
5. **빌드 전 설계 논의 선호**, 큰 변경은 작은 단위로 쪼개 각 단계가 빌드 가능하도록
6. **슬라이싱 ≠ 범위 축소** (중요): "가장 작은 슬라이스부터"는 *빌드 순서*일 뿐, 그 기능을 안 한다는 뜻이 아니다.
   사용자가 단순한 선택지(평평 리스트·기능 스킵 등)를 고르는 건 **착수 지점을 고르는 것** — 도착지(레퍼런스 전체)는 그대로다.
   - **Week N = 그 주에 *착수*하며 분량도 그만큼 걸린다는 의미.** 레퍼런스/요구가 곧 **산출물 정의**.
   - **"완료"는 기능이 실제 동작(F6 검증)할 때만** 쓴다. 범위를 최소로 깎은 뒤 그 깎인 기준으로 완료 판정하는 것 = 금지.
   - 선택지를 제시할 때 "최소/권장"으로 유도해 산출물을 줄이지 말 것.

## 아키텍처 원칙 (확립됨)
- **메커니즘 vs 뷰/컨트롤러 분리**: 메커니즘(`Countdown`/`Pomodoro`/`SimpleTimer`/`AlarmClock`)은
  `Save`·전역을 **모름**(재사용·테스트 가능). 뷰/컨트롤러가 `Save`를 알고 배선한다
- **공통 뷰 동작은 베이스로 추출**(`ClockToolView`). 원칙: "하나만 보고 일반화 안 함 → **두 번째 사례에서** 추출"
- **저장 정책**: 세션 duration = save-on-start / 전역 설정 = save-on-change(`AppSettings.changed`→`Save`) /
  알람 = 디바운스 저장(0.5s)
- 결합도: 알림은 **signal**, 단일 진실은 **`Save`**(autoload)
- 다국어: 원본 문자열=키, 문장 통째로 포맷(조각 연결 금지)
- 미래 서버/sync 대비: 단일 진실(`Save`)·JSON·`version` 필드.
  **안정 ID**: Todo·알람은 스냅샷(ID 없음) 유지. **습관(Week 3)에서 ID 도입**(randi 정수, `habit_defs` 키) — "주를 가로지르는 반복 정체성"이 트리거. 도입 기준 = 항목을 정체성으로 다뤄야 할 때(반복·참조·sync). 상세 `docs/architecture.md`.

## 데이터 / 오토로드
- `Save` (autoload, `user://save.json`, `version`) — 단일 진실
- `AppSettings` (데이터 백, `changed` 시그널)
- `Sound` (autoload, AudioStreamPlayer)

## 현재 진행
- Week 1 완료 (시계 탭: 포모/타이머/알람/설정 + `ClockToolView` 공통 베이스)
- **Week 2 완료**: Todo 레퍼런스 프론트 전체 — 추가/체크/취소선/삭제·마감일(상대표기 오늘/내일/날짜)·정렬·다중그룹 CRUD·진행도·드래그·호버·스크롤. 전부 F6 동작.
- **Week 3 완료**:
  - ✅ 드래그 정렬·재사용화 — `DragHandle`/`ReorderList`(`scripts/commonui`)를 **태스크·그룹·알람 3사례**에 적용. 호버·스크롤·`DateUtil`(`scripts/util`)·`LineEditAutoBlur`(`commonui`) 추출.
  - ✅ **습관 트래커(데일리)** — 주간 그리드·요일 활성화(우클릭)·달성도 원형·주간 페이지네이션·백필. 모델: `Save.habit_defs`(단일출처 `{id,title,active_days}`) + `habit_weeks`(주별 희소 체크). **안정 ID 도입**(randi). 상세 `docs/architecture.md`.
- **Week 4 진행 중 — T1~⑤ 완료**: 상주 월드 셸(월드 바탕 + 도구 팝업) + 항해. autoload `Timers`/`Clock`, 도크+패널(`ButtonGroupNav`), 상시 타이머 HUD, 셸 폴리시까지 됨. **항해 = 집중 중에만 실시간 전진**(`Clock.is_focusing`), `voyage_distance`(감성 거리, `total_focus_seconds` 통계와 분리), Ocean_8 패럴랙스(레이어별 `motion_offset` fmod 구동). **⭐ 다음 착수 = ⑥ 발견(게임 테마 논의부터)** + 병행 알람 전역화. 결정 근거·구현 결과는 architecture "Week 4 구현 결과"/roadmap 참고.
- 단계별 상세는 `docs/architecture.md`, `docs/roadmap.md` 참고
