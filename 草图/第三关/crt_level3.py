"""第三关「显像管仓库」整张地图：2240×1000，1 倍像素（第一关是 1006×426）。

一整面堆起来的电视墙，四层，每块屏幕是一个能走进去的场景，屏幕大小不一。
每层被实心的外壳断成几段，段和段之间靠上下的洞（垂着电线梯子）连起来，所以有好几条路：
  - 稳的路：一路往上爬，走左边；
  - 绕的路：先在下面往右走，再从右边爬上去，路上能多拿零件；
  - 段尽头的死胡同里藏东西。
终点在第四层最右边：最大的那块屏幕，里面是家乡，房子的门开着。

场景画法在 l3_scenes.py 和 crt_wall_v2.py。
输出：
  l3_far.png / l3_mid.png / l3_screens.png / l3_near.png   2240×1000 分层
  l3_layout.json   每块屏幕、地面高度、哪一段、通道、洞、单向平台、起点、终点（给 Godot 接碰撞用）
  预览L3_原图.png、预览L3_游戏.png、预览L3_路线.png（1 倍）
跑法："~/Desktop/程序programs/AI Oscar/.venv/bin/python" crt_level3.py
"""
import json
import random
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

import crt_wall_v2 as k
from crt_wall_v2 import KHAKI, WOOD, GREY, PLUM, RECESS, GLARE, WALL, FLOOR_C, PCB, TV, Canvas, facet

OUT = Path(__file__).parent
W, H, FLOOR = 2240, 1000, 980
k.setup(W, H, FLOOR)
random.seed(21)
k.rng = np.random.default_rng(21)
import l3_scenes as sc  # noqa: E402

# ================================================================ 排布
MAXH = [230, 220, 220, 250]                      # 每层电视最高多高
BOTTOMS = [FLOOR]
for h in MAXH[:-1]:
    BOTTOMS.append(BOTTOMS[-1] - h)              # 980 / 750 / 530 / 310
ROW_X0 = 110
ROW_X1 = [2200, 2200, 2200, 2200]
BREAKS = [[1100], [700, 1600], [1300], []]       # 每层在这些 x 附近断开（实心外壳，不打通）
HOLES = [                                        # (下层, 上层, 目标 x)
    (0, 1, 300), (0, 1, 900), (0, 1, 1350), (0, 1, 2000),
    (1, 2, 220), (1, 2, 1000), (1, 2, 1900),
    (2, 3, 420), (2, 3, 1550),
]

ROOMS = {"kitchen": k.room_kitchen, "living": k.room_living, "bedroom": k.room_bedroom,
         "kids": k.room_kids, "study": k.room_study, "entry": k.room_entry}
SCENES = {
    # 名字: (函数, 最小屏宽, 能用的显示方式)
    "kitchen": (k.room_kitchen, 130, ["color", "bw"]), "living": (k.room_living, 140, ["color", "amber"]),
    "bedroom": (k.room_bedroom, 130, ["bw", "color"]), "kids": (k.room_kids, 130, ["green", "color"]),
    "study": (k.room_study, 140, ["amber"]), "bathroom": (sc.sc_bathroom, 130, ["color", "bw"]),
    "workshop": (sc.sc_workshop, 140, ["amber", "color"]), "subway": (sc.sc_subway, 150, ["amber", "bw"]),
    "classroom": (sc.sc_classroom, 150, ["color", "green"]), "ferris": (sc.sc_ferris, 150, ["color"]),
    "rooftop": (sc.sc_rooftop, 130, ["color", "amber"]), "beach": (sc.sc_beach, 140, ["color"]),
    "harbor": (sc.sc_harbor, 130, ["color", "bw"]), "rain_street": (sc.sc_rain_street, 130, ["bw"]),
    "snow_yard": (sc.sc_snow_yard, 120, ["color"]), "forest": (sc.sc_forest, 110, ["green", "color"]),
    "aquarium": (sc.sc_aquarium, 80, ["color", "green"]), "space": (sc.sc_space, 100, ["color"]),
    "weather": (sc.sc_weather, 80, ["color"]), "test_card": (sc.sc_test_card, 70, ["color"]),
    "static": (sc.sc_static, 70, ["color"]), "attic": (sc.sc_attic, 100, ["amber"]),
    "desert": (sc.sc_desert, 100, ["color", "amber"]),
}
FLAT = {"test_card", "weather", "static"}
USED = {name: 0 for name in SCENES}
for name in ("test_card", "static", "weather"):
    USED[name] = 1                               # 这几种少出一点


def pick_size(row):
    r = random.random()
    if r < 0.28:
        w = random.randint(92, 128)
    elif r < 0.72:
        w = random.randint(140, 200)
    elif r < 0.94:
        w = random.randint(206, 270)
    else:
        w = random.randint(290, 330)
    hmin = 92 if w < 130 else 120
    h = int(np.clip(w * random.uniform(0.62, 0.86), hmin, MAXH[row]))
    return w, h


def pick_scene(sw, left_name):
    ok = [n for n, (fn, mw, _) in SCENES.items() if sw >= mw and n != left_name and n != "entry"]
    best = min(USED[n] for n in ok)
    name = random.choice([n for n in ok if USED[n] == best])
    USED[name] += 1
    return name


def pick_tint(name, left_tint):
    opts = SCENES[name][2]
    cand = [t for t in opts if t != left_tint] or opts
    return random.choice(cand)


rows = []
for ri in range(4):
    x, row, left_name, left_tint, left_P = ROW_X0, [], None, None, None
    last = ri == 3
    while True:
        if last and x > 1600:
            w, h = 440, 250                      # 终点：家乡
        else:
            w, h = pick_size(ri)
            if x + w > ROW_X1[ri] - 70:
                w = ROW_X1[ri] - x
                if w < 92:
                    break
        P = random.choice([p for p in (KHAKI, WOOD, GREY, PLUM) if p is not left_P])
        tv = TV(x, BOTTOMS[ri] - h, w, h, P, random.choice(["speaker", "meter", "buttons"]), "color",
                top="vents" if w > 180 else None)
        sw = tv.sx1 - tv.sx0
        if last and w == 440:
            name = "hometown"
        elif last and x + w > 1500 and "entry" not in [t.name for t in row] and sw >= 130:
            name = "entry"                       # 玄关放在家乡前面一格
        else:
            name = pick_scene(sw, left_name)
        tv.name = name
        tv.tint = "color" if name in ("hometown", "entry") else pick_tint(name, left_tint)
        tv.flat = name in FLAT
        tv.row = ri
        row.append(tv)
        left_name, left_tint, left_P = name, tv.tint, P
        x += w
        if name == "hometown" or x >= ROW_X1[ri] - 1:
            break
    rows.append(row)

# 段：每层在 BREAKS 附近找最近的两台电视的接缝，那里不打通
for ri, row in enumerate(rows):
    walls = set()
    for bx in BREAKS[ri]:
        j = min(range(1, len(row)), key=lambda j: abs(row[j].x0 - bx))
        walls.add(j)
    seg = 0
    for j, tv in enumerate(row):
        if j in walls:
            seg += 1
        tv.seg = seg
        tv.wall_left = j in walls


# ================================================================ 空隙杂物（照旧）
def vcr(x0, y0, w, h):
    m = k.mid
    m.rect(x0, y0, x0 + w, y0 + h, (54, 52, 62)); m.line(x0, y0, x0 + w, y0, (78, 74, 86))
    m.line(x0 + w, y0, x0 + w, y0 + h, (40, 38, 48))
    if h >= 8:
        m.rect(x0 + 4, y0 + 3, x0 + w // 2, y0 + 4, (30, 28, 36))
        m.rect(x0 + w - 18, y0 + 2, x0 + w - 6, y0 + h - 2, (24, 34, 30))
        for i in range(2):
            m.put(x0 + w - 16 + i * 3, y0 + 3, (120, 214, 130))
        m.put(x0 + 3, y0 + h - 2, (226, 72, 64))


def tape_stack(x0, y0, w, h):
    y = y0 + h
    while y > y0:
        th = min(4, y - y0)
        c = random.choice([(40, 38, 46), (60, 56, 66), (196, 186, 166)])
        k.mid.rect(x0 + random.randint(0, 2), y - th, x0 + w - random.randint(0, 2), y - 1, c)
        k.mid.put(x0 + w // 2, y - 2, (206, 196, 176) if c != (196, 186, 166) else (90, 80, 80))
        y -= th


def carton(x0, y0, w, h):
    m = k.mid
    m.rect(x0, y0, x0 + w, y0 + h, (150, 118, 90)); m.rect(x0 + w - 3, y0, x0 + w, y0 + h, (126, 98, 78))
    m.line(x0, y0, x0 + w, y0, (176, 142, 108)); m.rect(x0 + w // 2 - 2, y0, x0 + w // 2 + 2, y0 + h // 3, (186, 170, 140))


def dead_tv(x0, y0, w, h):
    P = random.choice([KHAKI, GREY, PLUM, WOOD])
    k.body(x0, y0, x0 + w, y0 + h, P, lip=3)
    sx0, sy0, sx1, sy1 = x0 + 4, y0 + 4, x0 + w - 6, y0 + h - 6
    if sx1 - sx0 > 8 and sy1 - sy0 > 6:
        k.recess(sx0, sy0, sx1, sy1, 2)
        d = k.ring_depth(sx0, sy0, sx1, sy1, 2)
        span = max(1, min(sx1 - sx0, sy1 - sy0) // 2)
        for i, c in enumerate([(34, 34, 50), (42, 42, 60), (50, 50, 70)]):
            k.mid.fill_mask(d >= int(span * (0, 0.2, 0.5)[i]), c)


def fill_gap(x0, x1, top, bottom):
    y = bottom
    while y > top:
        room_h = y - top
        h = room_h if room_h < 24 else random.randint(10, min(40, room_h))
        xa, xb = x0 + random.randint(0, 6), x1 - random.randint(0, 6)
        if xb - xa < 10:
            xa, xb = x0, x1
        kind = random.random()
        if h < 8:
            k.mid.rect(xa, y - h, xb, y - 1, (54, 52, 62)); k.mid.line(xa, y - h, xb, y - h, (78, 74, 86))
        elif kind < 0.3:
            for vx in range(xa, xb - 20, 64):
                vcr(vx, y - h, min(62, xb - vx), h - 1)
        elif kind < 0.55 and h >= 18:
            dead_tv(xa, y - h, min(xb - xa, int(h * 1.4)), h - 1)
            if xb - xa - int(h * 1.4) > 14:
                carton(xa + int(h * 1.4) + 1, y - min(h, 20), xb - xa - int(h * 1.4) - 2, min(h, 20) - 1)
        elif kind < 0.75:
            for tx in range(xa, xb - 8, 16):
                tape_stack(tx, y - h, min(14, xb - tx), h - 1)
        else:
            for bx in range(xa, xb - 10, 40):
                carton(bx, y - h, min(38, xb - bx), h - 1)
        y -= h


def build_far():
    f = k.far
    f.rect(0, 0, W - 1, H - 1, WALL[1])
    f.rect(0, 0, W - 1, 24, WALL[0])
    for x in range(0, W, 80):
        f.rect(x + 30, 0, x + 36, 24, WALL[2])
    for rx in range(-20, W, 140):
        f.rect(rx, 60, rx + 2, FLOOR, WALL[3]); f.rect(rx + 110, 60, rx + 112, FLOOR, WALL[3])
        for sy in range(110, FLOOR, 50):
            f.rect(rx, sy, rx + 112, sy + 2, WALL[3])
            x = rx + 4
            while x < rx + 100:
                tw, th = random.choice([14, 18, 22]), random.choice([12, 16, 20])
                if x + tw > rx + 108:
                    break
                f.rect(x, sy - th, x + tw, sy - 1, WALL[2]); f.line(x, sy - th, x + tw, sy - th, WALL[3])
                f.rect(x + 2, sy - th + 2, x + tw - 5, sy - 4, (52, 58, 82) if random.random() < 0.2 else (36, 36, 50))
                x += tw + random.choice([1, 2, 4])
    f.rect(0, FLOOR - 6, W - 1, H - 1, WALL[2])
    m = k.mid
    m.rect(0, FLOOR, W - 1, H - 1, FLOOR_C[2])
    m.line(0, FLOOR, W - 1, FLOOR, FLOOR_C[0]); m.line(0, FLOOR + 1, W - 1, FLOOR + 1, FLOOR_C[1])
    m.rect(0, FLOOR + 7, W - 1, H - 1, FLOOR_C[3])


# ================================================================ 画
build_far()
for lower, upper in zip(rows, rows[1:]):
    for u in upper:
        for l in lower:
            a, b = max(u.x0, l.x0), min(u.x1, l.x1)
            if b - a > 4 and l.y0 > u.y1 + 1:
                fill_gap(a, b, u.y1 + 1, l.y0)
    # 上层伸出下层右端的部分，底下用杂物一直垫到下层的下沿
    if upper[-1].x1 > lower[-1].x1 + 4:
        fill_gap(lower[-1].x1 + 1, upper[-1].x1, upper[-1].y1 + 1, lower[-1].y1 + 1)

for row in rows:
    for tv in row:
        tv.draw_shell()

END = None
for row in rows:
    for tv in row:
        before = k.scr.a.copy()
        k.set_vp(tv)
        n0 = len(sc.PLATFORMS)
        if tv.name in ROOMS:
            sc.room(ROOMS[tv.name], tv)
        elif tv.name == "hometown":
            END = sc.sc_hometown(tv)
        else:
            SCENES[tv.name][0](tv)
        tv.platforms = sc.PLATFORMS[n0:]
        outside = ~tv.screen_mask()
        k.scr.a[outside] = before[outside]

PASSAGES, HOLE_DATA = [], []
for row in rows:
    for l, r in zip(row, row[1:]):
        if not r.wall_left:
            k.side_passage(l, r)
            PASSAGES.append({"x0": l.sx1 - 2, "x1": r.sx0 + 2, "y0": l.fy - 24, "floor": l.fy, "row": l.row + 1})


def place_hole(lo, up, target):
    best = None
    for u in rows[up]:
        for l in rows[lo]:
            a, b = max(u.sx0, l.sx0) + 14, min(u.sx1, l.sx1) - 36
            if b - a < 0:
                continue
            x = int(np.clip(target, a, b))
            d = abs(x - target)
            if best is None or d < best[0]:
                best = (d, x, u, l)
    _, x, u, l = best
    k.drop_hole(u, l, x)
    HOLE_DATA.append({"x0": x, "x1": x + 22, "top": u.fy, "bottom": l.fy, "ladder_x": x + 11,
                      "upper": [u.row, u.seg], "lower": [l.row, l.seg]})


for lo, up, tx in HOLES:
    place_hole(lo, up, tx)

# 起点：仓库地面左边，第一台电视左侧外壳砸开一个口，门口垫两个纸箱当台阶
a = rows[0][0]
k.mid.rect(a.x0 - 1, a.fy - 24, a.sx0 + 2, a.fy + 2, RECESS[0])
k.mid.rect(a.x0 - 1, a.fy - 24, a.sx0 + 2, a.fy - 23, RECESS[1])
for y in range(a.fy - 24, a.fy + 3):
    for x in range(a.sx0 - 2, a.sx0 + 4):
        k.scr.clear(x, y)
carton(a.x0 - 34, FLOOR - 14, 30, 13)
carton(a.x0 - 20, FLOOR - 26, 18, 11)
PASSAGES.append({"x0": a.x0 - 1, "x1": a.sx0 + 2, "y0": a.fy - 24, "floor": a.fy, "row": 1})
sc.PLATFORMS.append((a.x0 - 34, a.x0 - 4, FLOOR - 14)); sc.PLATFORMS.append((a.x0 - 20, a.x0 - 2, FLOOR - 26))
START = (40, FLOOR)

for tv in rows[3]:
    if tv.top is None and tv.x1 - tv.x0 < 200:
        cx = (tv.x0 + tv.x1) // 2
        k.mid.line(cx, tv.y0, cx - 18, tv.y0 - 16, PLUM[5]); k.mid.line(cx + 1, tv.y0, cx + 20, tv.y0 - 14, PLUM[5])
        k.mid.rect(cx - 2, tv.y0 - 2, cx + 3, tv.y0 - 1, PLUM[4])
for (ax, bx, sag) in [(-10, 300, 40), (260, 700, 30), (640, 1000, 20), (980, 1500, 40), (1600, 2250, 50)]:
    k.cable([(ax, 4), (bx, 8)], sag, 2)

k.mid = facet(k.mid, cell=11, min_area=60, grad=0.6, seed=5,
              keep=tuple(RECESS) + tuple(FLOOR_C) + (GLARE,) + tuple(PCB))

for name, c in [("l3_far", k.far), ("l3_mid", k.mid), ("l3_screens", k.scr), ("l3_near", k.near)]:
    Image.fromarray(c.a).save(OUT / f"{name}.png")

# ================================================================ 连通检查：段是节点，洞是边
nodes = {(tv.row, tv.seg) for row in rows for tv in row}
adj = {n: set() for n in nodes}
for h in HOLE_DATA:
    u, l = tuple(h["upper"]), tuple(h["lower"])
    adj[u].add(l); adj[l].add(u)
end_node = (3, rows[3][-1].seg)
seen, q = {(0, 0)}, deque([(0, 0)])
while q:
    n = q.popleft()
    for m_ in adj[n]:
        if m_ not in seen:
            seen.add(m_); q.append(m_)
assert end_node in seen, "终点走不到"
assert seen == nodes, f"有段走不到：{nodes - seen}"


def all_paths(a, b, path=()):
    path = path + (a,)
    if a == b:
        return [path]
    out = []
    for n in adj[a]:
        if n not in path:
            out += all_paths(n, b, path)
    return out


PATHS = all_paths((0, 0), end_node)
dead_ends = [n for n in nodes if len(adj[n]) == 1 and n not in ((0, 0), end_node)]

layout = {
    "size": [W, H], "warehouse_floor": FLOOR, "start": START, "end": END,
    "screens": [{"name": tv.name, "row": tv.row + 1, "seg": tv.seg, "tint": tv.tint,
                 "casing": [tv.x0, tv.y0, tv.x1, tv.y1], "screen": [tv.sx0, tv.sy0, tv.sx1, tv.sy1], "floor": tv.fy,
                 "wall_left": tv.wall_left}
                for row in rows for tv in row],
    "passages": PASSAGES, "holes": HOLE_DATA,
    "platforms": [{"x0": a_, "x1": b_, "y": y_} for a_, b_, y_ in sc.PLATFORMS],
    "routes": [[list(n) for n in p] for p in PATHS], "dead_ends": [list(n) for n in dead_ends],
    "note": "外壳是实心墙；屏幕里地面在 floor；wall_left=true 表示和左边那台不通；passages 是左右通道（齐地面）；"
            "holes 是上下的洞，ladder_x 是电线梯子；platforms 是单向平台；routes 是从起点段到终点段的所有走法（[层, 段]）。",
}
(OUT / "l3_layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=1))


# ================================================================ 预览
def over(dst, src):
    m_ = src[..., 3] > 0
    dst[m_] = src[m_]
    return dst


raw = np.zeros((H, W, 4), np.uint8)
for c in (k.far, k.mid, k.scr, k.near):
    over(raw, c.a)
chars = OUT.parents[1] / "oscar-rush/art/chars"
hero = over(np.array(Image.open(chars / "red_body.png").convert("RGBA"))[:, 0:16],
            np.array(Image.open(chars / "red_strip.png").convert("RGBA"))[:, 0:16])
hx, hy = 60, FLOOR - hero.shape[0]
over(raw[hy:hy + hero.shape[0], hx:hx + 16], hero)
Image.fromarray(raw).save(OUT / "预览L3_原图.png")

DARK = np.array([0.36, 0.35, 0.41])
light = np.ones((H, W, 3)) * DARK
k.LIGHTS.append((hx + 8, hy + 6, 60, (255, 200, 140), 0.7))
for (lx, ly, r, col, kk) in k.LIGHTS:
    x0_, x1_ = int(max(0, lx - r - 2)), int(min(W, lx + r + 2))
    y0_, y1_ = int(max(0, ly - r - 2)), int(min(H, ly + r + 2))
    if x1_ <= x0_ or y1_ <= y0_:
        continue
    d = np.hypot(k.XX[y0_:y1_, x0_:x1_] - lx, (k.YY[y0_:y1_, x0_:x1_] - ly) * 1.15) / r
    band = np.floor(np.clip(1 - d, 0, 1) * 4) / 4
    light[y0_:y1_, x0_:x1_] += band[..., None] * (np.array(col) / 255.0) * kk
lit = raw[..., :3] * np.clip(light, 0, 1.15)
unshaded = k.scr.a[..., 3] > 0
lit[unshaded] = raw[..., :3][unshaded]
lit = np.clip(lit, 0, 255).astype(np.uint8)
Image.fromarray(lit).save(OUT / "预览L3_游戏.png")

route = Canvas(W, H, np.dstack([lit, np.full((H, W), 255, np.uint8)]))
RED, PINK = (236, 60, 60), (246, 150, 150)
for row in rows:                                                     # 每一段的地面：一条红线
    for seg in sorted({tv.seg for tv in row}):
        tvs = [tv for tv in row if tv.seg == seg]
        y = tvs[0].fy - 6
        x0_ = tvs[0].sx0 + 4 if not (tvs[0].row == 0 and seg == 0) else 40
        route.line(x0_, y, tvs[-1].sx1 - 4, y, RED); route.line(x0_, y - 1, tvs[-1].sx1 - 4, y - 1, RED)
        node = (tvs[0].row, seg)
        if node in dead_ends:
            route.rect(tvs[-1].sx1 - 10, y - 6, tvs[-1].sx1 - 4, y, (250, 200, 90))     # 死胡同：藏零件
for h in HOLE_DATA:                                                  # 洞：竖线
    for y in range(h["top"] - 6, h["bottom"] - 6):
        c = RED if (y // 4) % 2 else PINK
        route.put(h["ladder_x"], y, c); route.put(h["ladder_x"] + 1, y, c)
route.rect(START[0] - 4, FLOOR - 14, START[0] + 4, FLOOR - 6, (120, 230, 140))
route.rect(END[0] - 4, END[1] - 14, END[0] + 4, END[1] - 6, (250, 230, 110))
route.save(OUT / "预览L3_路线.png")
Image.fromarray(route.a).resize((W // 2, H // 2), Image.LANCZOS).save(OUT / "预览L3_路线_缩小.png")
print("ok", sum(len(r) for r in rows), "screens", len(PASSAGES), "passages", len(HOLE_DATA), "holes",
      len(sc.PLATFORMS), "platforms;", len(PATHS), "routes; dead ends", dead_ends, "end", END)
