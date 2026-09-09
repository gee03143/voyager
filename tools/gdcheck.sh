#!/usr/bin/env bash
# GDScript 문법(파스) 체크. 인자: 검사할 .gd 파일들 (저장소 루트 기준 상대 경로)
# GODOT_BIN 환경변수 = Godot 콘솔 실행 파일 경로 (.claude/settings.local.json에서 주입)
#
# 한계 (2026-09-09 실측):
# - 잡는 것: 문법(Parse) 오류뿐
# - 못 잡는 것: 없는 메서드 호출 등 — 실행 시점에야 런타임 오류로 나옴
# - autoload 9종은 --check-only 모드에서 등록되지 않아 거짓 양성 → 아래에서 걸러냄
set -u
if [ -z "${GODOT_BIN:-}" ]; then
  echo "GODOT_BIN이 설정되지 않았습니다 (.claude/settings.local.json 확인)" >&2
  exit 2
fi
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
AUTOLOADS="Save|Companion|Screen|ImeFocusGuard|PanelPool|Sound|Timers|Clock|Alarms"
fail=0
for f in "$@"; do
  out="$("$GODOT_BIN" --headless --path "$PROJ" --check-only --script "res://$f" --quit 2>&1)"
  # 오류 줄과 바로 뒤 "at:" 줄을 한 쌍으로 묶어 판단 — 거짓 양성은 쌍째로 버린다
  real="$(printf '%s\n' "$out" | awk -v al="Identifier not found: ($AUTOLOADS)" '
    /Parse Error|Compile Error/ {
      err = $0; loc = ""
      if ((getline nxt) > 0 && nxt ~ /^ *at:/) loc = nxt
      if (err ~ al) next
      if (err ~ /Failed to compile depended scripts/) next
      print err
      if (loc != "") print loc
    }')"
  if [ -n "$real" ]; then
    echo "=== $f ==="
    printf '%s\n' "$real"
    fail=1
  fi
done
[ "$fail" -eq 0 ] && echo "문법 오류 없음 ($# 파일)"
exit "$fail"
