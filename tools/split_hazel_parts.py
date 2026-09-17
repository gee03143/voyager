"""헤이즐 정면 포즈를 리그용 부위로 쪼갠다.

입력   assets/companion/rig/hazel_front_{temp,blink_half,blink_closed}.png
       hazel_tail_src.png   (따로 그린 꼬리, 선택)
       hazel_ears_src.png   (따로 그린 귀 2개 + 귀 없는 머리 윗부분, 선택)
       hazel_eyes_src.png   (따로 그린 눈 없는 얼굴 + 눈 3상태, 선택)
출력   hazel_{ear_l,ear_r,tail}.png / hazel_body_{open,half,shut}.png / parts.json

경계는 작가가 그린 검은 윤곽선을 벽으로 삼아 플러드필로 잡는다.
사람이 정하는 값은 아래 상수뿐이다 — 귀 밑동 절단선과 씨앗 좌표.

  python tools/split_hazel_parts.py [--check 미리보기경로]
  python tools/split_hazel_parts.py --guide 가이드경로
  python tools/split_hazel_parts.py --guide-ears 귀가이드경로
  python tools/split_hazel_parts.py --guide-eyes 눈가이드경로
"""

import json
import os
import sys
from collections import deque

from PIL import Image, ImageDraw, ImageFilter

R = "assets/companion/rig/"
BASE_SRC = "hazel_front_temp.png"   # 부위를 잘라낼 정면 포즈 원본
# 따로 그린 꼬리를 여기 두면 그걸 쓴다. 없으면 정면 포즈에서 잘라내
# 몸에 가려진 안쪽을 지어낸다(품질이 떨어지므로 임시 수단이다).
# 배경은 무채색이면 어떤 색이든 자동으로 벗긴다 — 털이 따뜻한 색이라
# 밝기가 아니라 채도로 가른다. 크림색 배가 안 뚫리는 게 이 방식의 이유다.
TAIL_SRC = "hazel_tail_src.png"
TAIL_FLIP = False              # 원본 방향 그대로. 밑동이 왼쪽 아래, 꼬리 끝이 오른쪽 위다
TAIL_HEIGHT = 175              # 몸 캔버스(302) 기준 높이
TAIL_POS = (100, 78)           # 붙이는 위치. 캔버스 오른쪽 밖으로 나가도 된다

# 따로 그린 귀 2개 + 귀 없는 머리 윗부분이 한 장에 들어 있는 이미지.
# 라벨 같은 작은 덩어리는 면적으로 걸러내고 큰 것 셋만 쓴다.
EARS_SRC = "hazel_ears_src.png"
EAR_HEIGHT = 88                                     # 귀 끝~밑동 전체 높이
EAR_TIPS = {"ear_l": (43, 24), "ear_r": (109, 24)}  # 귀 끝이 놓일 자리
HEAD_W = 146                   # 머리 윗부분 폭. 기존 얼굴 실루엣에 맞춘 값이다
HEAD_POS = (1, 68)
# 이 y까지는 머리 윗부분으로 덮어쓰고, FADE까지 서서히 기존 얼굴로 넘긴다.
# 경계를 딱 자르면 가로줄이 보여서 페이드가 필요하다.
HEAD_SOLID, HEAD_FADE = 98, 112

# 귀는 머리와 뚫려 있어 윤곽선만으로는 안 막힌다. 밑동에 인공 벽을 긋는다.
# 양 끝이 귀 바깥선(진짜 벽)에 닿아야 채우기가 새지 않는다.
EAR_CUTS = [((66, 64), (14, 103)), ((84, 64), (128, 107))]
SEEDS = {
    "ear_l": [(38, 32), (30, 55), (45, 50)],
    "ear_r": [(114, 32), (106, 55), (122, 50)],
    "tail": [(158, 165), (150, 200), (140, 224), (163, 135),
             (150, 112), (168, 180), (145, 190), (155, 230)],
}
WALL_DARK = 100        # 부위 경계선으로 칠 밝기
WALL_DARK_TAIL = 82    # 꼬리 내부 음영선은 벽으로 안 친다
# 몸에 가려 원본에 안 그려진 꼬리 안쪽을 만들어 붙인다.
# 없으면 꼬리가 바깥으로 돌 때 몸과 끊겨 보인다.
TAIL_EXTEND_X = 34
TAIL_EXTEND_Y = 16


def luma(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def _load_tail_src():
    """따로 그린 꼬리를 읽어 배경을 벗기고 몸 크기에 맞춘다.

    반환: (이미지, 붙일 위치)
    """
    img = Image.open(R + TAIL_SRC).convert("RGBA")
    w, h = img.size
    px = img.load()

    def bg(c):
        # 무채색이고 밝으면 배경. 털은 R과 B 차이가 40 이상이라 안 걸린다
        return max(c[:3]) - min(c[:3]) < 14 and max(c[:3]) > 195

    seen = [[False] * h for _ in range(w)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg(px[x, y]) and not seen[x][y]:
                seen[x][y] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if bg(px[x, y]) and not seen[x][y]:
                seen[x][y] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        px[x, y] = (255, 255, 255, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[nx][ny] and bg(px[nx, ny]):
                seen[nx][ny] = True
                q.append((nx, ny))

    img = img.crop(img.getbbox())
    if TAIL_FLIP:
        img = img.transpose(Image.FLIP_LEFT_RIGHT)
    tw = max(1, round(img.width * TAIL_HEIGHT / img.height))
    return img.resize((tw, TAIL_HEIGHT), Image.LANCZOS), TAIL_POS


def _strip_bg(img):
    """무채색 배경을 테두리부터 플러드필로 벗긴다."""
    w, h = img.size
    px = img.load()

    def bg(c):
        return max(c[:3]) - min(c[:3]) < 14 and max(c[:3]) > 195

    seen = [[False] * h for _ in range(w)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg(px[x, y]) and not seen[x][y]:
                seen[x][y] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if bg(px[x, y]) and not seen[x][y]:
                seen[x][y] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        px[x, y] = (255, 255, 255, 0)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[nx][ny] and bg(px[nx, ny]):
                seen[nx][ny] = True
                q.append((nx, ny))
    return img


def _load_ears_src():
    """한 장에 든 귀 2개 + 머리 윗부분을 덩어리로 분리한다.

    반환: {"ear_l": img, "ear_r": img, "head": img}
    """
    img = _strip_bg(Image.open(R + EARS_SRC).convert("RGBA"))
    w, h = img.size
    px = img.load()
    seen = [[False] * h for _ in range(w)]
    blobs = []
    for sx in range(w):
        for sy in range(h):
            if px[sx, sy][3] > 40 and not seen[sx][sy]:
                seen[sx][sy] = True
                q, pts = deque([(sx, sy)]), []
                while q:
                    x, y = q.popleft()
                    pts.append((x, y))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = x + dx, y + dy
                            if (0 <= nx < w and 0 <= ny < h and not seen[nx][ny]
                                    and px[nx, ny][3] > 40):
                                seen[nx][ny] = True
                                q.append((nx, ny))
                xs = [p[0] for p in pts]
                ys = [p[1] for p in pts]
                blobs.append((len(pts), min(xs), min(ys), max(xs), max(ys)))
    blobs.sort(reverse=True)
    if len(blobs) < 3:
        raise SystemExit("%s 에서 덩어리 3개를 못 찾음" % EARS_SRC)
    big = blobs[:3]                                  # 라벨은 면적에서 밀려 빠진다
    big.sort(key=lambda b: b[2])                     # 위에 있는 둘이 귀
    ears = sorted(big[:2], key=lambda b: b[1])       # 왼쪽이 ear_l
    named = {"ear_l": ears[0], "ear_r": ears[1], "head": big[2]}
    out = {}
    for k, b in named.items():
        part = img.crop((b[1], b[2], b[3] + 1, b[4] + 1))
        out[k] = part.crop(part.getbbox())
    return out


def _head_overlay(head):
    """머리 윗부분을 몸 크기로 줄이고 아래쪽에 페이드를 넣는다."""
    dh = round(head.height * HEAD_W / head.width)
    hd = head.resize((HEAD_W, dh), Image.LANCZOS)
    m = hd.getchannel("A").copy()
    mp = m.load()
    for y in range(dh):
        sy = y + HEAD_POS[1]
        if sy <= HEAD_SOLID:
            continue
        k = 0.0 if sy >= HEAD_FADE else (HEAD_FADE - sy) / float(HEAD_FADE - HEAD_SOLID)
        for x in range(HEAD_W):
            mp[x, y] = int(mp[x, y] * k)
    hd.putalpha(m)
    return hd


def _ear_tip(img):
    """귀 끝의 x 중심과 y. 배치 기준점으로 쓴다."""
    px = img.load()
    for y in range(img.height):
        xs = [x for x in range(img.width) if px[x, y][3] > 100]
        if xs:
            return (sum(xs) // len(xs), y)
    return (img.width // 2, 0)


# 눈이 차지한 범위(원본 스프라이트 좌표). 깜빡임 프레임을 만들 때 쓴 값이다
EYE_BOXES = [(28, 122, 52, 152), (90, 121, 116, 152)]
EYE_PAD = 5

# 따로 그린 눈. 눈 없는 얼굴 1개 + 눈 6개(뜬/반쯤/감은 × 좌우)가 한 장에 들어 있다.
# 눈은 눈구멍에 고정이라 위치를 추측할 수 없다. 그래서 같이 온 얼굴을
# 기존 얼굴 실루엣에 피팅해 배율을 얻고, 그 배율로 눈을 기존 눈자리에 놓는다.
EYES_SRC = "hazel_eyes_src.png"
# 눈 없는 얼굴을 따로 받으면 그걸 쓴다. 눈 소스 안의 얼굴은 눈구멍 음영이
# 그려져 있어서, 눈 조각의 눈꺼풀 음영과 겹쳐 두 겹이 됐다.
FACE_SRC = "hazel_face_noeyes_src.png"
EYE_SCALE = 0.92               # 그려준 눈이 약간 커서 줄인다
# 눈 소스의 줄 순서 = 이 이름 순서. 줄을 추가하면 표정이 하나 늘어난다.
# 앞의 셋은 깜빡임이 쓰므로 순서를 바꾸지 않는다.
EYE_ROW_NAMES = ["open", "half", "shut", "happy", "surprise", "curious", "excited"]
# 얼굴 그림의 잘린 윗변을 부드럽게 넘기는 픽셀 수
FACE_TOP_FADE = 10
FACE_FIT_ROWS = range(126, 170, 4)   # 얼굴 피팅에 쓸 기존 실루엣 구간


def _span(img, y):
    px = img.load()
    xs = [x for x in range(img.width) if px[x, y][3] > 128]
    return (min(xs), max(xs)) if xs else None


def _blobs(img, min_area=1):
    """불투명 연결 성분을 (면적, x0, y0, x1, y1)로 돌려준다. 큰 것부터."""
    w, h = img.size
    px = img.load()
    seen = [[False] * h for _ in range(w)]
    out = []
    for sx in range(w):
        for sy in range(h):
            if px[sx, sy][3] > 40 and not seen[sx][sy]:
                seen[sx][sy] = True
                q, pts = deque([(sx, sy)]), []
                while q:
                    x, y = q.popleft()
                    pts.append((x, y))
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            nx, ny = x + dx, y + dy
                            if (0 <= nx < w and 0 <= ny < h and not seen[nx][ny]
                                    and px[nx, ny][3] > 40):
                                seen[nx][ny] = True
                                q.append((nx, ny))
                if len(pts) >= min_area:
                    xs = [p[0] for p in pts]
                    ys = [p[1] for p in pts]
                    out.append((len(pts), min(xs), min(ys), max(xs), max(ys)))
    out.sort(reverse=True)
    return out


def _strip_ears_from_face(face):
    """얼굴 그림에 같이 그려진 귀를 떼어낸다.

    위에서부터 훑어 좌/우 귀와 가운데 돔이 한 덩어리가 되는 행을 찾고,
    그보다 위 행에서는 가운데 런(돔)만 남긴다.
    """
    px = face.load()
    w, h = face.size

    def runs(y):
        out, s = [], None
        for x in range(w):
            on = px[x, y][3] > 60
            if on and s is None:
                s = x
            elif not on and s is not None:
                out.append((s, x - 1))
                s = None
        if s is not None:
            out.append((s, w - 1))
        return [r for r in out if r[1] - r[0] > 3]

    merge = h
    for y in range(h):
        r = runs(y)
        if len(r) == 1 and r[0][1] - r[0][0] > w * 0.5:
            merge = y
            break
    cx = w // 2
    for y in range(merge):
        keep = None
        for a, b in runs(y):
            if a - 6 <= cx <= b + 6:
                keep = (a, b)
                break
        for x in range(w):
            if keep is None or not (keep[0] <= x <= keep[1]):
                px[x, y] = (0, 0, 0, 0)
    return face.crop(face.getbbox())


def _load_eyes_src():
    """눈 소스에서 얼굴과 눈 3세트를 뽑는다.

    반환: (귀 뗀 얼굴, {"open"/"half"/"shut": [왼쪽, 오른쪽]})
    """
    img = _strip_bg(Image.open(R + EYES_SRC).convert("RGBA"))
    blobs = _blobs(img)
    if len(blobs) < 7:
        raise SystemExit("%s 에서 얼굴 1개 + 눈 6개를 못 찾음" % EYES_SRC)
    fb = blobs[0]
    face = _strip_ears_from_face(img.crop((fb[1], fb[2], fb[3] + 1, fb[4] + 1)))
    # 눈은 가로세로비가 1:1에 가깝고 라벨 알약은 4:1이 넘는다. 이걸로 라벨을 거른다
    cand = [b for b in blobs[1:]
            if (b[3] - b[1] + 1) < (b[4] - b[2] + 1) * 2.5]
    if len(cand) % 2:
        raise SystemExit("눈 덩어리가 홀수 개(%d)다. 좌우 한 쌍씩이어야 한다" % len(cand))
    eyes = sorted(cand, key=lambda b: b[2])                    # 위에서부터 한 줄씩
    sets = {}
    if len(eyes) // 2 > len(EYE_ROW_NAMES):
        raise SystemExit("눈 줄이 %d개인데 이름은 %d개뿐이다. EYE_ROW_NAMES를 늘려라"
                         % (len(eyes) // 2, len(EYE_ROW_NAMES)))
    for i in range(len(eyes) // 2):
        pair = sorted(eyes[i * 2:i * 2 + 2], key=lambda b: b[1])
        crops = [img.crop((b[1], b[2], b[3] + 1, b[4] + 1)) for b in pair]
        sets[EYE_ROW_NAMES[i]] = [e.crop(e.getbbox()) for e in crops]
    return face, sets


def _fit_face(face, body):
    """따로 그린 얼굴을 기존 얼굴 실루엣에 맞춘다. 반환 (폭, 높이, x, y)."""
    ref = {y: _span(body, y) for y in FACE_FIT_ROWS}
    ref = {y: v for y, v in ref.items() if v}
    mid = sorted(ref)[len(ref) // 2]
    cx = (ref[mid][0] + ref[mid][1]) / 2.0
    best = None
    for fw in range(120, 200, 2):
        fh = round(face.height * fw / face.width)
        fs = face.resize((fw, fh), Image.LANCZOS)
        fx = round(cx - fw / 2.0)
        for oy in range(40, 130):
            err = n = 0
            for y, (lx, rx) in ref.items():
                s = _span(fs, y - oy) if 0 <= y - oy < fh else None
                if not s:
                    err += 400
                else:
                    err += abs(s[0] + fx - lx) + abs(s[1] + fx - rx)
                n += 1
            if n and (best is None or err / n < best[0]):
                best = (err / n, fw, fh, fx, oy)
    print("얼굴 피팅: 폭=%d 위치=(%d,%d) 평균오차=%.1fpx" % (best[1], best[3], best[4], best[0]))
    return best[1], best[2], best[3], best[4]


def _apply_eyes(face, sets, scale_face=None):
    """눈 부위 털을 갈아끼우고 눈 상태별 몸통 텍스처 3종을 만든다.

    face        눈 주변 털을 가져올 그림 (눈 없는 얼굴)
    scale_face  눈 크기를 유도할 기준 얼굴. 눈 조각과 같은 배율로 그려진 것이라야 한다.
                얼굴을 따로 받으면 크롭이 달라 이 기준이 깨지므로 분리해서 받는다.
    """
    body = Image.open(R + "hazel_body_open.png").convert("RGBA")
    w, h = body.size
    fw, fh, fx, fy = _fit_face(face, body)
    fs = face.resize((fw, fh), Image.LANCZOS)
    # 얼굴을 통째로 올린다.
    # 처음엔 눈 주변만 타원으로 오려 붙였는데, 그 경계가 눈두덩을 도는 띠로
    # 보였다 — 새 얼굴과 기존 얼굴의 볼 톤이 미세하게 달라서 오려붙인 자리가
    # 그대로 드러난 것이다. 통째로 덮으면 경계 자체가 없어진다.
    if FACE_TOP_FADE:
        a = fs.getchannel("A").copy()
        ap = a.load()
        for y in range(min(FACE_TOP_FADE, fs.height)):
            for x in range(fs.width):
                ap[x, y] = int(ap[x, y] * y / float(FACE_TOP_FADE))
        fs.putalpha(a)
    noeyes = body.copy()
    noeyes.alpha_composite(fs, (fx, fy))

    if scale_face is None:
        scale_face = face
        sw = fw
    else:
        sw = _fit_face(scale_face, body)[0]
    k = (sw / float(scale_face.width)) * EYE_SCALE
    for state, pair in sets.items():
        out = noeyes.copy()
        for i, e in enumerate(pair):
            ew = max(1, round(e.width * k))
            eh = max(1, round(e.height * k))
            es = e.resize((ew, eh), Image.LANCZOS)
            x0, y0, x1, y1 = EYE_BOXES[i]
            cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
            out.alpha_composite(es, (cx - ew // 2, cy - eh // 2))
        out.save(R + "hazel_body_%s.png" % state)
    print("눈: %s 사용 (배율 %.3f, 상태 %s)" % (EYES_SRC, k, ", ".join(sets)))
    return list(sets)


def write_eye_guide(path, scale=4):
    """눈을 어디에 그려야 하는지 보여주는 가이드.

    지금 조립 상태를 옅게 깔고 눈 범위를 파랗게 칠한다.
    눈은 눈구멍에 고정으로 박히므로, 이 캔버스에 그대로 그려야 정합이 맞는다.
    """
    meta = json.load(open(R + "parts.json"))
    body = Image.open(R + "hazel_body_open.png").convert("RGBA")
    w, h = body.size
    char = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for key in ("tail", "ear_l", "ear_r"):
        part = Image.open(R + "hazel_%s.png" % key)
        char.alpha_composite(part, (meta[key]["x"], meta[key]["y"]))
    char.alpha_composite(body, (0, 0))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mark = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    md = ImageDraw.Draw(mark)
    for (x0, y0, x1, y1) in EYE_BOXES:
        md.rectangle([x0 - EYE_PAD, y0 - EYE_PAD, x1 + EYE_PAD, y1 + EYE_PAD],
                     fill=(60, 140, 255, 95))
    out.alpha_composite(mark)
    char.putalpha(char.getchannel("A").point(lambda a: int(a * 0.45)))
    out.alpha_composite(char)
    out = out.resize((w * scale, h * scale), Image.LANCZOS)
    ImageDraw.Draw(out).rectangle(
        [0, 0, w * scale - 1, h * scale - 1], outline=(0, 190, 255, 220), width=3)
    out.save(path)
    print("눈 가이드 저장: %s (%dx%d)" % (path, w * scale, h * scale))


def write_guide(path, scale=4):
    """꼬리를 어디에 그려야 하는지 보여주는 가이드.

    몸은 옅게 깔고 기존 꼬리 자리를 표시한다. 이 캔버스에 꼬리만 그려
    투명 배경으로 내보내면 그대로 쓸 수 있다.
    """
    body = Image.open(R + "hazel_body_open.png").convert("RGBA")
    w, h = body.size
    meta = json.load(open(R + "parts.json"))
    old = Image.open(R + "hazel_tail.png").convert("RGBA")

    # 지금 꼬리가 보이는 자리만 파랗게. 몸에 가린 부분은 표시하지 않는다
    ghost = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ghost.paste((60, 140, 255, 95), (meta["tail"]["x"], meta["tail"]["y"]),
                old.getchannel("A"))
    ghost.putalpha(Image.composite(
        ghost.getchannel("A"), Image.new("L", (w, h), 0),
        body.getchannel("A").point(lambda a: 0 if a > 128 else 255)))

    # 꼬리를 뺀 캐릭터를 옅게 깔아 위치를 잡게 한다
    out = ghost
    char = body.copy()
    for ear in ("ear_l", "ear_r"):
        e = Image.open(R + "hazel_%s.png" % ear)
        char.alpha_composite(e, (meta[ear]["x"], meta[ear]["y"]))
    char.putalpha(char.getchannel("A").point(lambda a: int(a * 0.45)))
    out.alpha_composite(char)
    out = out.resize((w * scale, h * scale), Image.LANCZOS)

    d = ImageDraw.Draw(out)
    d.rectangle([0, 0, w * scale - 1, h * scale - 1], outline=(0, 190, 255, 220), width=3)
    out.save(path)
    print("가이드 저장: %s (%dx%d, %dx 배율)" % (path, w * scale, h * scale, scale))


def _ear_guide(path, base, body, mask, meta, w, h, scale=4):
    """귀 작업 가이드.

    파란색 = 지금 귀가 있는 자리 (완성된 귀를 그려야 하는 곳)
    붉은색 = 귀를 떼고 프로그램이 메운 자리 (머리 윤곽을 다시 그려야 하는 곳)
    """
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mark = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    mp = mark.load()
    bp = body.load()
    for key in ("ear_l", "ear_r"):
        for (x, y) in mask[key]:
            # 몸통에 픽셀이 남아 있으면 = 메운 자리, 비어 있으면 = 귀만 있던 자리
            mp[x, y] = (235, 70, 60, 120) if bp[x, y][3] > 128 else (60, 140, 255, 110)
    out.alpha_composite(mark)
    char = base.copy()
    char.putalpha(char.getchannel("A").point(lambda a: int(a * 0.4)))
    out.alpha_composite(char)
    out = out.resize((w * scale, h * scale), Image.LANCZOS)
    ImageDraw.Draw(out).rectangle(
        [0, 0, w * scale - 1, h * scale - 1], outline=(0, 190, 255, 220), width=3)
    out.save(path)
    print("귀 가이드 저장: %s (%dx%d)" % (path, w * scale, h * scale))


def main(check_path=None, ear_guide_path=None):
    base = Image.open(R + BASE_SRC).convert("RGBA")
    w, h = base.size
    px = base.load()
    opaque = [[px[x, y][3] > 128 for y in range(h)] for x in range(w)]

    cut = Image.new("L", (w, h), 0)
    cd = ImageDraw.Draw(cut)
    for a, b in EAR_CUTS:
        cd.line([a, b], fill=255, width=3)
    cp = cut.load()

    def walls(thr):
        return [[(not opaque[x][y]) or luma(px[x, y]) < thr or cp[x, y] > 0
                 for y in range(h)] for x in range(w)]

    def flood(wall, seeds):
        seen = [[False] * h for _ in range(w)]
        q, out = deque(), set()
        for sx, sy in seeds:
            if not wall[sx][sy] and not seen[sx][sy]:
                seen[sx][sy] = True
                q.append((sx, sy))
        while q:
            x, y = q.popleft()
            out.add((x, y))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and not seen[nx][ny] and not wall[nx][ny]:
                    seen[nx][ny] = True
                    q.append((nx, ny))
        return out

    def dilate(region, n):
        cur = set(region)
        for _ in range(n):
            cur |= {(x + dx, y + dy) for (x, y) in cur
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                    if 0 <= x + dx < w and 0 <= y + dy < h and opaque[x + dx][y + dy]}
        return cur

    w_part, w_tail = walls(WALL_DARK), walls(WALL_DARK_TAIL)
    reg = {
        "ear_l": flood(w_part, SEEDS["ear_l"]),
        "ear_r": flood(w_part, SEEDS["ear_r"]),
        "tail": flood(w_tail, SEEDS["tail"]),
    }

    # 바깥 실루엣 선 = 투명 픽셀에 붙은 불투명 픽셀
    outer = {(x, y) for x in range(w) for y in range(h) if opaque[x][y] and any(
        not (0 <= x + dx < w and 0 <= y + dy < h and opaque[x + dx][y + dy])
        for dx in range(-3, 4) for dy in range(-3, 4))}

    # 귀는 앞에 있으니 자기 윤곽선을 전부 가져간다.
    # 꼬리는 뒤에 있으니 바깥 실루엣 선만 갖고, 몸과 맞닿은 선은 몸에 남긴다.
    mask = {k: dilate(reg[k], 3) for k in ("ear_l", "ear_r")}
    mask["tail"] = ((reg["tail"] | (dilate(reg["tail"], 3) & outer))
                    - mask["ear_l"] - mask["ear_r"])
    carved = mask["ear_l"] | mask["ear_r"] | mask["tail"]

    # --- 꼬리 안쪽 만들어 붙이기 -------------------------------------------
    # 몸에 가려 원본에 없는 부분이라, 가장자리 색을 왼쪽·아래로 늘려 지어낸다.
    # 늘린 영역은 반드시 "몸이 덮는 범위" 안에 가둔다. 밖으로 나가면
    # 꼬리가 돌 때 직사각형 모서리가 그대로 튀어나온다.
    behind = {(x, y) for x in range(w) for y in range(h)
              if opaque[x][y] and (x, y) not in mask["tail"]}
    tail_px = {(x, y): px[x, y] for (x, y) in mask["tail"]}
    grown = {}

    def grow(cell, color):
        if cell in tail_px or cell in grown or cell not in behind:
            return
        # 몸 뒤에 깔리는 부분이라 조금 어둡게. 새어 나와도 그림자로 읽힌다
        grown[cell] = (int(color[0] * 0.88), int(color[1] * 0.88),
                       int(color[2] * 0.88), 255)

    rows = {}
    for (x, y) in mask["tail"]:
        if y not in rows or x < rows[y]:
            rows[y] = x
    for y, x0 in rows.items():
        c = tail_px[(x0, y)]
        for i in range(1, TAIL_EXTEND_X + 1):
            if x0 - i >= 0:
                grow((x0 - i, y), c)
    cols = {}
    for (x, y) in list(tail_px) + list(grown):
        if x not in cols or y > cols[x]:
            cols[x] = y
    for x, y0 in cols.items():
        c = tail_px.get((x, y0)) or grown[(x, y0)]
        for i in range(1, TAIL_EXTEND_Y + 1):
            if y0 + i < h:
                grow((x, y0 + i), c)

    # 행마다 색을 그대로 끌면 빗살무늬가 된다. 지어낸 영역만 뭉개
    # 부드러운 그라데이션으로 만든다 — 살짝 새어 나와도 털 그늘로 읽힌다.
    for _ in range(4):
        blurred = {}
        for (x, y) in grown:
            acc, n = [0, 0, 0], 0
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-2, -1, 0, 1, 2):
                    c = grown.get((x + dx, y + dy)) or tail_px.get((x + dx, y + dy))
                    if c:
                        acc[0] += c[0]
                        acc[1] += c[1]
                        acc[2] += c[2]
                        n += 1
            blurred[(x, y)] = (acc[0] // n, acc[1] // n, acc[2] // n, 255)
        grown = blurred
    tail_px.update(grown)

    # --- 부위 텍스처 --------------------------------------------------------
    drawn = _load_ears_src() if os.path.exists(R + EARS_SRC) else None
    head_overlay = _head_overlay(drawn["head"]) if drawn else None
    meta = {}
    for key in ("ear_l", "ear_r", "tail"):
        if drawn and key in drawn:
            # 따로 그린 귀. 귀 끝을 기준으로 놓는다
            e = drawn[key]
            ew = max(1, round(e.width * EAR_HEIGHT / e.height))
            e = e.resize((ew, EAR_HEIGHT), Image.LANCZOS)
            tx, ty = _ear_tip(e)
            pos = (EAR_TIPS[key][0] - tx, EAR_TIPS[key][1] - ty)
            e.save(R + "hazel_%s.png" % key)
            meta[key] = {"x": pos[0], "y": pos[1], "w": e.width, "h": e.height}
            print("%s: %s 사용 (%dx%d @ %d,%d)"
                  % (key, EARS_SRC, e.width, e.height, pos[0], pos[1]))
            continue
        if key == "tail" and os.path.exists(R + TAIL_SRC):
            # 따로 그린 꼬리. 캔버스 밖으로 나가도 되므로 그대로 저장한다
            out, pos = _load_tail_src()
            out.save(R + "hazel_tail.png")
            meta[key] = {"x": pos[0], "y": pos[1], "w": out.width, "h": out.height}
            print("꼬리: %s 사용 (%dx%d @ %d,%d)"
                  % (TAIL_SRC, out.width, out.height, pos[0], pos[1]))
            continue
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        tp = out.load()
        src_px = tail_px if key == "tail" else {c: px[c] for c in mask[key]}
        for (x, y), c in src_px.items():
            tp[x, y] = c
        box = out.getbbox()
        out.crop(box).save(R + "hazel_%s.png" % key)
        meta[key] = {"x": box[0], "y": box[1],
                     "w": box[2] - box[0], "h": box[3] - box[1]}

    # --- 몸통 -------------------------------------------------------------
    # 여기서는 한 장만 만든다. 눈 상태별 텍스처는 _apply_eyes가 이걸 바탕으로 찍어낸다
    for key, img in (("open", base),):
        out = img.copy()
        tp, sp = out.load(), img.load()
        for (x, y) in mask["tail"]:
            tp[x, y] = (0, 0, 0, 0)           # 꼬리는 뒤에 있으니 그냥 비운다
        for ear in ("ear_l", "ear_r"):        # 귀 밑동은 가장 가까운 머리털로 메운다
            for (x, y) in mask[ear]:
                best = None
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x, y
                    for step in range(1, 26):
                        nx, ny = nx + dx, ny + dy
                        if not (0 <= nx < w and 0 <= ny < h):
                            break
                        if (nx, ny) not in carved and opaque[nx][ny]:
                            if best is None or step < best[0]:
                                best = (step, sp[nx, ny])
                            break
                tp[x, y] = best[1] if best else (0, 0, 0, 0)
        if head_overlay is not None:
            # 귀 밑동 잔해를 통째로 지우고 따로 그린 머리 윗부분으로 갈아끼운다.
            # 한 번 깔고 몸을 올린 뒤 다시 덮어야 페이드 구간이 자연스럽게 섞인다.
            for x in range(w):
                for y in range(HEAD_SOLID + 1):
                    tp[x, y] = (0, 0, 0, 0)
            merged = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            merged.alpha_composite(head_overlay, HEAD_POS)
            merged.alpha_composite(out, (0, 0))
            merged.alpha_composite(head_overlay, HEAD_POS)
            out = merged
        out.save(R + "hazel_body_%s.png" % key)

    states = ["open"]
    if os.path.exists(R + EYES_SRC):
        face, eye_sets = _load_eyes_src()
        sheet_face = face
        if os.path.exists(R + FACE_SRC):
            face = _strip_bg(Image.open(R + FACE_SRC).convert("RGBA"))
            face = face.crop(face.getbbox())
            print("얼굴: %s 사용" % FACE_SRC)
            states = _apply_eyes(face, eye_sets, scale_face=sheet_face)
        else:
            states = _apply_eyes(face, eye_sets)
    else:
        print("경고: %s 가 없어 눈 상태가 open 하나뿐이다" % EYES_SRC)

    # 줄을 지웠을 때 낡은 상태 텍스처가 남지 않게 치운다
    import glob
    for f in glob.glob(R + "hazel_body_*.png"):
        name = os.path.basename(f)[len("hazel_body_"):-len(".png")]
        if name not in states:
            os.remove(f)
            if os.path.exists(f + ".import"):
                os.remove(f + ".import")
            print("낡은 상태 제거: %s" % name)

    meta["size"] = {"w": w, "h": h}
    meta["states"] = states
    with open(R + "parts.json", "w") as f:
        json.dump(meta, f, indent=2)
    print(json.dumps(meta))

    if ear_guide_path:
        _ear_guide(ear_guide_path, base, Image.open(R + "hazel_body_open.png").convert("RGBA"),
                   mask, meta, w, h)
    if check_path:
        _preview(check_path, base, meta, w, h)


def _preview(path, base, meta, w, h):
    """조립 + 회전 미리보기. 틈이 생기는지 눈으로 본다."""
    pivot = {"ear_l": (36, 100), "ear_r": (116, 100), "tail": (130, 248)}
    pad = 70          # 꼬리가 캔버스 밖으로 나가므로 미리보기만 넓게 잡는다
    cw = w + pad

    def rot(name, ang):
        part = Image.open(R + "hazel_%s.png" % name)
        b = meta[name]
        big = Image.new("RGBA", (cw, h), (0, 0, 0, 0))
        big.alpha_composite(part, (b["x"], b["y"]))
        return big.rotate(-ang, resample=Image.BICUBIC, center=pivot[name])

    def shot(al=0.0, ar=0.0, at=0.0):
        c = Image.new("RGBA", (cw, h), (0, 0, 0, 0))
        # 귀는 몸 뒤. 주신 귀는 밑동까지 있어서 앞에 두면 이마를 덮는다
        c.alpha_composite(rot("tail", at))
        c.alpha_composite(rot("ear_l", al))
        c.alpha_composite(rot("ear_r", ar))
        c.alpha_composite(Image.open(R + "hazel_body_open.png"), (0, 0))
        return c

    first = Image.new("RGBA", (cw, h), (0, 0, 0, 0))
    first.alpha_composite(base, (0, 0))
    # 실사용 각도(꼬리 2.6도)와 과장 각도(9도)를 나란히 본다
    shots = [first, shot(), shot(-3, 2, 2.6), shot(-9, 6, 9), shot(8, -7, -9)]
    out = Image.new("RGBA", (cw * len(shots), h), (42, 38, 34, 255))
    for i, s in enumerate(shots):
        out.alpha_composite(s, (cw * i, 0))
    out.resize((cw * len(shots) * 2, h * 2), Image.LANCZOS).save(path)


if __name__ == "__main__":
    if "--guide" in sys.argv:
        write_guide(sys.argv[sys.argv.index("--guide") + 1])
        sys.exit(0)
    arg = ear = None
    if "--check" in sys.argv:
        arg = sys.argv[sys.argv.index("--check") + 1]
    if "--guide-ears" in sys.argv:
        ear = sys.argv[sys.argv.index("--guide-ears") + 1]
    if "--guide-eyes" in sys.argv:
        write_eye_guide(sys.argv[sys.argv.index("--guide-eyes") + 1])
        sys.exit(0)
    main(arg, ear)
