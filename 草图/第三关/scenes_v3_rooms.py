"""第三关 v3：书房、浴室、阁楼、工作间、教室，按大屏（玻璃约 444×245）重新布置。

做法（2026-10-17，作者：大屏里东西太少、全挤在角落）：
- 东西按正常比例画（主角 13 高、椅子约 20、门约 48），不放大；大屏靠"更多组东西"铺满宽度。
- 每个场景拆成几"组"（书墙、书桌、壁炉……），每组自己管地上的家具和它头顶墙上的东西，
  spread() 按屏幕宽度从左到右摆开，组和组之间留空；放不下就按优先级丢掉不重要的组。
- 墙分三层：地上家具（0~60 格）、墙面挂件（60~140 格）、高处（吊灯、横梁、高窗），大屏才画高处。
- 平台只给大件的顶面（高 18~45 格），横向相邻平台的空隙不超过 60 格。
- 贴地 14 格以内只放暗、素的东西（柜门、桌腿），怪在地上走要看得清。
"""
import random

import numpy as np

import crt_wall_v2 as k
import l3_scenes as sc
from crt_wall_v2 import shade, box, extrude, panel, floor_shadow

S = sc.S
plat = sc.plat
disc = sc.disc

CREW = [(206, 72, 64), (190, 140, 96), (96, 136, 214), (110, 180, 100)]


# ================================================================ 通用
def dims(tv):
    """屏幕宽、墙高、大小档：L 大屏（精英战）、M 中屏、S 小屏。"""
    rw = tv.sx1 - tv.sx0
    wall_h = tv.fy - tv.sy0
    size = "L" if rw >= 330 and wall_h >= 150 else ("M" if rw >= 200 and wall_h >= 110 else "S")
    return rw, wall_h, size


def spread(tv, groups, margin=8, min_gap=10):
    """groups: [(宽, 优先级, 画法 fn(x))]，按给的顺序从左到右排。只排不画，返回 [(x, 宽, fn)]：
    先排好，灯可以挂在组和组之间的空里，墙刷完再一组一组画。
    放不下就丢优先级最低的组；剩下的空按组数均分，中间几组再抖一点，不像尺子量出来的。"""
    rw = tv.sx1 - tv.sx0
    groups = list(groups)
    while len(groups) > 1 and sum(g[0] for g in groups) + min_gap * (len(groups) - 1) > rw - 2 * margin:
        groups.remove(min(groups, key=lambda g: g[1]))
    n = len(groups)
    if n == 1:
        w, _, fn = groups[0]
        return [(tv.sx0 + max(margin, (rw - w) // 2), w, fn)]
    free = rw - 2 * margin - sum(g[0] for g in groups)
    gap = free / (n - 1)
    x = tv.sx0 + margin
    if dims(tv)[2] == "S" and gap > 30:                                         # 小屏只放一两样，别甩到两头，聚在中间
        gap = 30
        x = tv.sx0 + (rw - sum(g[0] for g in groups) - gap * (n - 1)) // 2
    rr = random.Random(tv.sx0 * 7 + n)
    out = []
    for i, (w, _, fn) in enumerate(groups):
        jit = rr.randint(-int(gap * 0.12), int(gap * 0.12)) if 0 < i < n - 1 and gap > 12 else 0
        out.append((int(x + jit), w, fn))
        x += w + gap
    return out


def gaps_of(placed):
    """组和组之间空当的中点（吊灯挂这里，不挡家具和窗）。"""
    return [(a[0] + a[1] + b[0]) // 2 for a, b in zip(placed, placed[1:])]


def lamp_xs(placed):
    """两盏吊灯挑哪两个空当：左右各四分之一处那个。"""
    gs = gaps_of(placed)
    if len(gs) <= 1:
        return gs
    return [gs[len(gs) // 4], gs[(3 * len(gs)) // 4]]


def draw_groups(placed):
    for x, w, fn in placed:
        fn(x)


def wall_light(tv, lamps, ya=None, yb=None, r=None, inner=True):
    """墙上的灯光：每盏灯周围两圈八角形的亮块（亮一档、再亮一档），离灯远的墙暗一档。
    边是直线段，像剪纸；在墙刷完、家具画之前调。"""
    ya = tv.sy0 if ya is None else ya
    yb = tv.fy - 1 if yb is None else yb
    r = r or max(30.0, (tv.fy - tv.sy0) * 0.42)
    m = tv.screen_mask() & (k.YY >= ya) & (k.YY <= yb) & (k.YY < tv.fy)
    d = np.full(k.XX.shape, 99.0)
    for lx, ly in lamps:
        dx, dy = np.abs(k.XX - lx), np.abs(k.YY - ly) * 1.25
        d = np.minimum(d, np.maximum(np.maximum(dx, dy), (dx + dy) * 0.72) / r)
    brighten(m & (d < 1.0), 1)
    if inner:
        brighten(m & (d < 0.45), 1)
    brighten(m & (d > 1.8), -1)


def brighten(mask, k_=1):
    """把 mask 里的像素各自往亮挪 k_ 档（光柱、窗光）：底下画了什么还看得见，只是亮一档。"""
    a = S().a
    px = a[..., :3][mask]
    if len(px) == 0:
        return
    keys, inv = np.unique(px, axis=0, return_inverse=True)
    new = np.array([shade(tuple(int(v) for v in c), k_) for c in keys], np.uint8)
    a[..., :3][mask] = new[inv.ravel()]


def ceiling(tv, c, ch, beams=0):
    """天花板：屏幕顶上薄薄一条（透视算下来大屏也就 7~10 格），下沿一道石膏线；beams>0 画几根往灭点收的梁。"""
    x0, x1, y0 = tv.sx0, tv.sx1, tv.sy0
    S().rect(x0, y0, x1, y0 + ch, c)
    S().line(x0, y0 + ch + 1, x1, y0 + ch + 1, shade(c, 2))
    S().line(x0, y0 + ch + 2, x1, y0 + ch + 2, shade(c, -2))
    if beams:
        vx, vy = k.VP
        for i in range(beams):
            bx = x0 + (x1 - x0) * (i + 0.5) / beams
            t = ch / max(1, vy - y0)
            ex = bx + (vx - bx) * t
            S().poly([(bx - 4, y0), (bx + 4, y0), (ex + 3, y0 + ch + 1), (ex - 3, y0 + ch + 1)], shade(c, -1))
            S().poly([(bx + 2, y0), (bx + 4, y0), (ex + 3, y0 + ch + 1), (ex + 2, y0 + ch + 1)], shade(c, -2))


def paint_wall(tv, ya, yb, c):
    """把墙的 ya..yb 这一段刷成一种平色（墙裙、腰线以上的檐壁），光照色块最后由 finish_room 统一切。"""
    m = tv.screen_mask() & (k.YY >= ya) & (k.YY <= yb) & (k.YY < tv.fy)
    S().fill_mask(m, c)


def cords(x0, x1, y_pic, y_rail, c=(90, 70, 64)):
    """画从挂镜线上用两根绳吊下来：两根绳在挂镜线上收到一个钩子。"""
    hx = (x0 + x1) // 2
    S().line(x0, y_pic, hx, y_rail + 2, c); S().line(x1, y_pic, hx, y_rail + 2, c)
    S().rect(hx - 1, y_rail, hx + 1, y_rail + 1, (176, 150, 100))


def frame_pic(x, y, w, h, frame, sky, hill, ground=None):
    """墙上的画：画框 + 里面一小幅风景（天、山、地），颜色用房间自己的色相。"""
    S().rect(x - 2, y - 2, x + w + 2, y + h + 2, shade(frame, -2))
    S().rect(x - 2, y - 2, x + w + 1, y + h + 1, frame)
    S().line(x - 2, y - 2, x + w + 1, y - 2, shade(frame, 2))
    S().rect(x, y, x + w - 1, y + h - 1, sky)
    S().rect(x, y, x + w - 1, y + h // 3, shade(sky, 1))
    S().poly([(x, y + h * 0.7), (x + w * 0.35, y + h * 0.38), (x + w * 0.6, y + h * 0.62), (x + w * 0.8, y + h * 0.48),
              (x + w, y + h * 0.66), (x + w, y + h), (x, y + h)], hill)
    S().rect(x, y + int(h * 0.8), x + w - 1, y + h - 1, ground or shade(hill, -2))
    S().rect(x + w - 6, y + 3, x + w - 5, y + 4, shade(sky, 4))


def wall_shelf(x0, x1, y, c=(132, 94, 76)):
    """墙上的搁板：一块挤出厚度的木板，下面两只三角托架。"""
    box(x0, y, x1, y + 2, c, depth=0.06)
    for bx in (x0 + 3, x1 - 4):
        S().poly([(bx, y + 3), (bx + 2, y + 3), (bx + 2, y + 8)], shade(c, -2))


def books_row(x0, x1, base_y, hmin=6, hmax=10, cols=None, lean_at=None):
    """一排书立在 base_y 上（书脊朝外），偶尔一本斜靠着。"""
    cols = cols or [(170, 86, 80), (96, 116, 160), (196, 176, 122), (110, 146, 110), (146, 108, 150), (214, 204, 184)]
    bx = x0
    while bx < x1 - 1:
        bw = random.choice([2, 2, 3, 3, 4])
        bh = random.randint(hmin, hmax)
        c = random.choice(cols)
        S().rect(bx, base_y - bh, min(x1, bx + bw - 1), base_y - 1, c)
        S().line(bx, base_y - bh, bx, base_y - 1, shade(c, 1))
        if bw >= 3:
            S().put(bx + 1, base_y - bh + 2, shade(c, 3))
        bx += bw
    if lean_at is not None:
        S().poly([(lean_at, base_y), (lean_at + 3, base_y), (lean_at + 8, base_y - hmax + 1), (lean_at + 6, base_y - hmax)], cols[1])


def bookcase(x, fy, w, h, wood=(112, 80, 70), base=14):
    """书柜：上面一格一格放书，下面 base 格是关着的柜门（贴地那条不花）。"""
    floor_shadow(x, x + w, fy, 4)
    box(x, fy - h, x + w, fy, wood)
    box(x - 1, fy - h - 2, x + w + 1, fy - h, shade(wood, 1), depth=0.05)       # 顶檐
    panel(x + 2, fy - base + 1, x + w // 2 - 1, fy - 2, wood)
    panel(x + w // 2 + 1, fy - base + 1, x + w - 2, fy - 2, wood)
    S().put(x + w // 2 - 2, fy - base // 2, (226, 196, 130)); S().put(x + w // 2 + 2, fy - base // 2, (226, 196, 130))
    top = fy - h + 3
    sy = fy - base - 1
    while sy - 12 >= top:                                                       # 从下往上一层一层
        S().rect(x + 2, sy - 11, x + w - 2, sy - 1, (60, 44, 46))
        S().rect(x + 2, sy - 11, x + w - 2, sy - 10, (48, 34, 38))
        books_row(x + 3, x + w - 3, sy, 7, 10)
        S().rect(x + 1, sy, x + w - 1, sy + 1, shade(wood, 2))
        sy -= 14


def hanging_bulb(x, ceil, y, cord=(70, 60, 60)):
    """一根电线吊一只光灯泡（阁楼、工作间）。"""
    S().line(x, ceil, x, y - 3, cord)
    S().rect(x - 1, y - 3, x + 1, y - 2, (96, 90, 90))
    S().rect(x - 2, y - 1, x + 2, y + 2, (255, 240, 196))
    S().rect(x - 1, y + 3, x + 1, y + 3, (255, 228, 170))


def plats_ok(tv, n0):
    """自检：大屏 2~4 个平台、高 18~45、横向空隙 ≤ 60（只打印，不拦）。"""
    ps = sorted(sc.PLATFORMS[n0:])
    rw, wall_h, size = dims(tv)
    bad = [p for p in ps if not (18 <= tv.fy - p[2] <= 45)]
    gaps = []
    reach = None
    for a, b, _ in ps:                                                          # 按左端排，叠在一起的不算空隙
        if reach is not None:
            gaps.append(max(0, a - reach))
        reach = b if reach is None else max(reach, b)
    if bad or (size == "L" and not 2 <= len(ps) <= 4) or any(g > 60 for g in gaps):
        print(f"    [平台] {getattr(tv, 'name', '?')} {size}: {[(a - tv.sx0, b - tv.sx0, tv.fy - y) for a, b, y in ps]} 空隙 {gaps}")


# ================================================================ 书房
def study(tv):
    """书房（琥珀屏）：墙分三段（下面深色护墙板、中间壁纸、挂镜线以上的檐壁）。
    地上四组：书墙（高书柜 + 梯子 + 矮书柜）、书桌（打字机、台灯，上方搁板和合照）、
    壁炉（台上座钟蜡烛，上方用绳吊一幅大画）、阅读角（高窗和窗帘、扶手椅、落地灯）。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, size = dims(tv)
    n0 = len(sc.PLATFORMS)
    wood = (112, 80, 70)
    rail = fy - int(wall_h * 0.68) if size != "S" else y0 - 10                  # 挂镜线
    pan_top = fy - (30 if size != "S" else 18)

    def walls(lamps):
        k.room_base(tv, k.WARM_WALL, k.WARM_FLOOR, lamps[0], lamps=lamps)
        paint_wall(tv, y0, pan_top - 1, (204, 170, 146))                         # 中间刷平，灯光自己切
        paint_wall(tv, pan_top, fy - 1, (164, 128, 108))                          # 护墙板：深、素，贴地那条不花
        if size != "S":
            paint_wall(tv, y0, rail, (176, 142, 128))                            # 檐壁暗一档
        wall_light(tv, lamps)
        S().line(x0, pan_top, x1, pan_top, (170, 132, 112)); S().line(x0, pan_top + 1, x1, pan_top + 1, (100, 74, 66))
        for px in range(x0 + 4, x1 - 20, 44):
            panel(px, pan_top + 5, px + 38, fy - 4, (164, 128, 108))
        if size != "S":
            ceiling(tv, (150, 116, 104), 6 if size == "L" else 4)
            S().rect(x0, rail, x1, rail + 1, (190, 154, 130)); S().line(x0, rail + 2, x1, rail + 2, (128, 96, 86))
            # 壁纸：很稀的小菱形点，只比墙暗一档（远看是一层质感，近看才看得出花样）
            m = tv.screen_mask() & (k.YY > rail + 6) & (k.YY < pan_top - 4)
            pat = ((k.XX - x0) % 18 == 9 * (((k.YY - rail) // 16) % 2)) & ((k.YY - rail) % 16 == 8)
            pat = pat | np.roll(pat, 1, 0) | np.roll(pat, -1, 0) | np.roll(pat, 1, 1) | np.roll(pat, -1, 1)
            brighten(m & pat, -1)

    hi = lambda y: max(y, y0 + 10)

    def book_wall(x):
        th = min(int(wall_h * 0.62), 140, wall_h - 12)
        bookcase(x, fy, 36, th)
        bookcase(x + 40, fy, 34, 40, base=12)
        plat(x + 40, x + 74, fy - 40)
        gx = x + 50                                                              # 矮书柜上：地球仪、一摞横放的书
        S().line(gx, fy - 41, gx, fy - 44, (90, 70, 64)); box(gx - 4, fy - 42, gx + 4, fy - 41, (90, 70, 64), depth=0.03)
        disc(gx, fy - 50, 5, (120, 150, 140)); S().poly([(gx - 2, fy - 54), (gx + 3, fy - 52), (gx + 1, fy - 47), (gx - 3, fy - 49)], (176, 160, 112))
        S().put(gx - 2, fy - 53, (210, 230, 220))
        box(x + 60, fy - 43, x + 71, fy - 41, (150, 70, 64), depth=0.04); box(x + 61, fy - 46, x + 70, fy - 44, (96, 110, 150), depth=0.04)
        # 靠在高书柜上的梯子（高书柜顶上有一道铜轨）
        S().rect(x - 1, fy - th + 6, x + 37, fy - th + 7, (196, 160, 100))
        lx = x + 32
        top = fy - th + 8
        lean = max(6, (fy - top) // 9)
        S().line(lx, fy, lx - lean, top, (164, 124, 92)); S().line(lx + 6, fy, lx + 6 - lean, top, (130, 96, 76))
        for r in range(7, fy - top, 9):
            t = r / (fy - top)
            S().line(int(lx - lean * t), fy - r, int(lx + 6 - lean * t), fy - r, (164, 124, 92))
        if size != "S" and fy - 96 > rail + 10:                                  # 矮书柜上方：用绳吊一幅小画
            frame_pic(x + 46, fy - 96, 22, 16, (150, 112, 86), (196, 186, 150), (150, 140, 110))
            cords(x + 46, x + 68, fy - 98, rail)
        if size == "L":                                                          # 书柜顶上：一只旧皮箱、一尊石膏像
            box(x + 4, fy - th - 10, x + 24, fy - th - 3, (130, 90, 72), depth=0.06)
            S().rect(x + 28, fy - th - 12, x + 33, fy - th - 3, (214, 206, 186)); disc(x + 30, fy - th - 15, 3, (214, 206, 186))

    def desk(x):
        w = 60
        floor_shadow(x, x + w, fy, 4)
        box(x + 2, fy - 16, x + 18, fy, wood)                                    # 抽屉柜
        for i in range(3):
            panel(x + 4, fy - 14 + i * 5, x + 16, fy - 11 + i * 5, wood)
        box(x + w - 5, fy - 16, x + w - 3, fy, shade(wood, -1))
        box(x, fy - 19, x + w, fy - 17, shade(wood, 1), depth=0.06)              # 桌面
        plat(x, x + w, fy - 19)
        box(x + 20, fy - 25, x + 34, fy - 20, (84, 86, 96), depth=0.04)          # 打字机 + 一张纸
        S().rect(x + 23, fy - 30, x + 31, fy - 26, (236, 230, 214)); S().line(x + 24, fy - 28, x + 29, fy - 28, (176, 170, 160))
        box(x + 4, fy - 22, x + 14, fy - 20, (150, 70, 64), depth=0.03); box(x + 5, fy - 25, x + 13, fy - 23, (96, 110, 150), depth=0.03)
        lx = x + w - 12                                                          # 银行家台灯
        box(lx - 3, fy - 21, lx + 3, fy - 20, (150, 130, 90), depth=0.03)
        S().line(lx, fy - 26, lx, fy - 22, (150, 130, 90))
        S().poly([(lx - 6, fy - 26), (lx + 6, fy - 26), (lx + 4, fy - 30), (lx - 4, fy - 30)], (90, 140, 110))
        S().line(lx - 5, fy - 25, lx + 5, fy - 25, (255, 236, 180))
        cx = x + 34                                                              # 椅子（椅背朝镜头）
        for lx_ in (cx + 1, cx + 11):
            S().rect(lx_, fy - 8, lx_ + 1, fy, shade(wood, -2))
        box(cx, fy - 10, cx + 12, fy - 9, shade(wood, -1), depth=0.04)
        box(cx + 1, fy - 22, cx + 11, fy - 11, (130, 76, 70), depth=0.04)
        S().line(cx + 1, fy - 22, cx + 11, fy - 22, shade((130, 76, 70), 2))
        if wall_h > 70:                                                          # 桌子上方的搁板
            wall_shelf(x + 6, x + w - 6, fy - 44)
            books_row(x + 9, x + 28, fy - 44, 6, 9, lean_at=x + 29)
            S().rect(x + 40, fy - 50, x + 45, fy - 47, (176, 110, 86)); S().line(x + 42, fy - 51, x + 40, fy - 56, (110, 150, 110))
            S().line(x + 43, fy - 51, x + 46, fy - 57, (110, 150, 110)); S().put(x + 46, fy - 58, (140, 180, 130))
            if size == "S":
                plat(x + 6, x + w - 6, fy - 44)
        if wall_h > 70:
            k.crew_photo(x + 8, hi(fy - 78))
        if size == "L":
            frame_pic(x + 10, fy - 140, 40, 30, (150, 112, 86), (176, 186, 176), (120, 136, 116))   # 吊在挂镜线上的大画
            cords(x + 10, x + 50, fy - 142, rail)

    def fireplace(x):
        w = 58
        stone = (176, 160, 146)
        floor_shadow(x - 4, x + w + 4, fy, 4)
        box(x - 4, fy - 2, x + w + 4, fy, shade(stone, -1), depth=0.05)          # 炉床
        box(x, fy - 34, x + w, fy - 2, stone)
        S().rect(x + 6, fy - 30, x + w - 6, fy - 28, shade(stone, -1))
        S().rect(x + 12, fy - 24, x + w - 12, fy - 3, (56, 44, 48))              # 炉口
        S().poly([(x + 12, fy - 24), (x + w - 11, fy - 24), (x + w - 14, fy - 27), (x + 15, fy - 27)], (56, 44, 48))
        S().rect(x + 12, fy - 24, x + 14, fy - 3, (72, 58, 60))
        S().rect(x + 18, fy - 6, x + w - 18, fy - 4, (96, 66, 58))               # 木柴，只剩一点暗红的炭
        for ex in (x + 22, x + 27, x + 33):
            S().put(ex, fy - 5, (176, 104, 74))
        box(x - 4, fy - 37, x + w + 4, fy - 35, wood, depth=0.06)                # 壁炉台
        plat(x - 4, x + w + 4, fy - 37)
        box(x + 4, fy - 44, x + 10, fy - 38, (60, 50, 56), depth=0.03)           # 台上：座钟、两支蜡烛、花瓶
        S().rect(x + 5, fy - 43, x + 9, fy - 40, (226, 214, 180))
        for cx in (x + 18, x + w - 18):
            S().rect(cx, fy - 40, cx + 1, fy - 38, (176, 150, 100)); S().rect(cx, fy - 45, cx + 1, fy - 41, (236, 228, 206))
            S().put(cx, fy - 46, (255, 236, 170))
        S().rect(x + w - 9, fy - 44, x + w - 5, fy - 38, (120, 140, 170)); S().put(x + w - 8, fy - 43, (170, 190, 210))
        if wall_h > 100:                                                         # 上方一幅大画，用绳吊在挂镜线上
            ph = 34 if size == "L" else 26
            frame_pic(x + 6, fy - 52 - ph, w - 12, ph, (176, 140, 90), (186, 190, 176), (130, 120, 104))
            if size != "S":
                cords(x + 6, x + w - 6, fy - 54 - ph, rail)
        if size == "L":
            k.wall_clock(x + w // 2, rail - 22, 8)

    def reading(x):
        w = 86
        wx = x + 30
        if wall_h > 90:                                                          # 高窗：从挂镜线下一点一直到窗台；窗帘从挂镜线垂到护墙板
            wy = (rail + 10) if size != "S" else y0 + 12
            wh = fy - 52 - wy
            k.window(wx, wy, 30, wh)
            S().line(wx, wy + wh // 4, wx + 30, wy + wh // 4, (138, 108, 112))
            for cx, d in [(wx - 10, 1), (wx + 33, -1)]:
                S().rect(cx, rail + 4, cx + 7, pan_top - 2, (150, 96, 96))
                S().rect(cx + (5 if d > 0 else 0), rail + 4, cx + (7 if d > 0 else 2), pan_top - 2, shade((150, 96, 96), -1))
                S().line(cx + 3, rail + 6, cx + 3, pan_top - 4, shade((150, 96, 96), 1))
                S().rect(cx - 1, fy - 70, cx + 8, fy - 68, (196, 160, 100))           # 束带
            box(wx - 13, rail + 2, wx + 43, rail + 5, (120, 86, 72), depth=0.04)       # 窗帘盒
            box(wx - 2, fy - 52, wx + 32, fy - 50, (196, 170, 150), depth=0.05)        # 窗台：一盆小花
            S().rect(wx + 4, fy - 57, wx + 9, fy - 53, (176, 110, 86)); S().rect(wx + 4, fy - 61, wx + 9, fy - 58, (150, 170, 120))
        k.rug(x + 34, fy, 30, (140, 110, 120), (156, 124, 132))
        k.armchair(x + 6, fy)
        plat(x + 2, x + 24, fy - 23)
        tx = x + 34                                                              # 小圆桌 + 茶杯
        S().rect(tx + 4, fy - 12, tx + 5, fy, shade(wood, -1)); box(tx, fy - 14, tx + 9, fy - 13, wood, depth=0.05)
        S().rect(tx + 2, fy - 17, tx + 4, fy - 15, (230, 224, 210)); S().put(tx + 5, fy - 16, (230, 224, 210))
        k.floor_lamp(x + w - 10, fy, fy - 44)
        k.plant(x + w - 30, fy)

    groups = {
        "L": [(78, 5, book_wall), (60, 4, desk), (58, 3, fireplace), (86, 2, reading)],
        "M": [(78, 5, book_wall), (60, 4, desk), (86, 2, reading)],
        "S": [(36, 5, lambda x: bookcase(x, fy, 36, min(88, wall_h - 12))), (60, 4, desk)],
    }[size]
    placed = spread(tv, groups)
    if size == "S":
        lamps = [(x0 + int(rw * 0.6), y0 + int(wall_h * 0.3))]
    else:                                                                        # 吊灯挂在组和组之间的空里
        lamps = [(gx, fy - int(wall_h * (0.5 if i == 0 else 0.44))) for i, gx in enumerate(lamp_xs(placed))]
    walls(lamps)
    draw_groups(placed)
    if size != "S":
        for lx, ly in lamps:
            k.hanging_lamp(lx, y0 + 6, ly)
    plats_ok(tv, n0)
    k.finish_room(tv, lamps[0])


# ================================================================ 浴室
def bathroom(tv):
    """浴室（彩色 / 黑白）：下半墙贴大块瓷砖（缝只暗一档），上面刷漆；老房子的水管明着走。
    地上：毛巾柜、爪脚浴缸和半拉开的浴帘（上方一扇高磨砂窗）、洗手台和镜柜、马桶和上面的搁板、
    洗衣机和墙上的热水器、暖气片和挂着的毛巾。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, size = dims(tv)
    n0 = len(sc.PLATFORMS)
    tile_top = fy - min(int(wall_h * 0.42), 100)

    def walls(lamps):
        wallc = [(214, 214, 196), (200, 198, 182), (182, 180, 168), (162, 160, 152), (142, 140, 138)]
        k.room_base(tv, wallc, k.TILE_FLOOR, lamps[0], lamps=lamps)
        paint_wall(tv, y0, tile_top, (204, 200, 184))                            # 上半墙刷平漆
        tile = (196, 214, 210)
        m = tv.screen_mask() & (k.YY >= tile_top) & (k.YY < fy)
        S().fill_mask(m, tile)
        S().fill_mask(m & (k.YY >= fy - 20), shade(tile, -1))
        tw_, th_ = (16, 12) if size != "S" else (12, 10)
        S().fill_mask(m & ((((k.XX - x0) % tw_) == 0) | (((k.YY - tile_top) % th_) == 0)), shade(tile, -1))
        S().rect(x0, tile_top - 4, x1, tile_top - 1, (120, 150, 156))             # 腰线砖
        S().line(x0, tile_top - 4, x1, tile_top - 4, (150, 178, 182))
        wall_light(tv, lamps)
        if size != "S":
            ceiling(tv, (196, 196, 184), 6 if size == "L" else 4)

    porcelain = (228, 228, 222)
    pipe, pipe_d = (170, 160, 150), (130, 122, 116)
    hi = lambda y: max(y, y0 + 10)

    def vpipe(px, ya, yb):
        S().rect(px, ya, px + 2, yb, pipe); S().line(px + 2, ya, px + 2, yb, pipe_d)
        for jy in (ya + 6, yb - 6):
            if ya + 6 < yb - 6:
                S().rect(px - 1, jy, px + 3, jy + 2, shade(pipe, 1))

    def cabinet(x):
        """高高的毛巾柜：上面玻璃门里叠着毛巾，下面木门。不站人。"""
        w, h = 28, min(70, wall_h - 14)
        c = (200, 196, 184)
        floor_shadow(x, x + w, fy, 4)
        box(x, fy - h, x + w, fy, c)
        S().rect(x + 3, fy - h + 4, x + w - 3, fy - 28, (176, 196, 200))
        for i, tc in enumerate([(206, 160, 170), (236, 226, 200), (150, 180, 200), (206, 160, 170), (236, 226, 200)]):
            yy = fy - 31 - i * 6
            if yy - 4 > fy - h + 4:
                S().rect(x + 5, yy - 4, x + w - 5, yy, tc); S().line(x + 5, yy - 4, x + w - 5, yy - 4, shade(tc, 1))
        S().line(x + w // 2, fy - h + 4, x + w // 2, fy - 28, c)
        panel(x + 3, fy - 24, x + w - 3, fy - 3, c)
        S().put(x + w // 2 + 3, fy - 14, (176, 150, 100))
        box(x + 6, fy - h - 8, x + 20, fy - h - 1, (176, 150, 116), depth=0.05)   # 柜顶一只藤筐
        if size == "L":                                                          # 柜子上方：高搁板上几只玻璃罐和一只备用灯泡盒
            sy_ = fy - h - 40
            wall_shelf(x - 2, x + w + 6, sy_, (186, 176, 164))
            for i, (jc, jh) in enumerate([((176, 206, 196), 9), ((226, 214, 180), 6), ((196, 186, 214), 11)]):
                jx = x + 1 + i * 10
                S().rect(jx, sy_ - jh, jx + 6, sy_ - 1, jc); S().rect(jx + 1, sy_ - jh - 2, jx + 5, sy_ - jh - 1, shade(jc, -2))

    def tub(x):
        w = 66
        floor_shadow(x, x + w, fy, 4)
        if size == "S" and wall_h > 70:                                          # 小屏没有马桶那组，合照挂在浴缸上方
            k.crew_photo(x + 16, fy - 64)
        for fx in (x + 4, x + w - 7):                                            # 爪脚
            S().rect(fx, fy - 3, fx + 3, fy, (190, 160, 100)); S().put(fx - 1, fy, (190, 160, 100)); S().put(fx + 4, fy, (150, 120, 80))
        S().poly([(x, fy - 19), (x + w, fy - 19), (x + w - 4, fy - 6), (x + w - 10, fy - 3), (x + 10, fy - 3), (x + 4, fy - 6)], porcelain)
        S().poly([(x + w - 16, fy - 19), (x + w, fy - 19), (x + w - 4, fy - 6), (x + w - 10, fy - 3), (x + w - 20, fy - 3)], shade(porcelain, -1))
        S().line(x + 6, fy - 4, x + w - 10, fy - 4, shade(porcelain, -2))
        box(x - 1, fy - 21, x + w + 1, fy - 19, porcelain, depth=0.05)          # 缸沿
        S().rect(x + 3, fy - 21, x + w - 3, fy - 21, (150, 196, 214))
        plat(x - 1, x + w + 1, fy - 21)
        dx = x + 12                                                              # 小黄鸭
        S().rect(dx, fy - 25, dx + 4, fy - 22, (240, 208, 96)); S().rect(dx + 3, fy - 27, dx + 5, fy - 25, (240, 208, 96))
        S().put(dx + 6, fy - 26, (230, 140, 80)); S().put(dx + 4, fy - 26, (60, 50, 50))
        if wall_h > 70:
            # 淋浴：立管从缸边一直走到天花板，弯出一个花洒；帘杆横在浴缸上方，帘子收在右头，几道宽褶
            px = x + 4
            vpipe(px, y0, fy - 22)
            S().line(px + 2, fy - 64, px + 9, fy - 64, pipe)
            S().poly([(px + 7, fy - 63), (px + 13, fy - 63), (px + 12, fy - 60), (px + 8, fy - 60)], (200, 204, 212))
            S().rect(px + 3, fy - 34, px + 6, fy - 33, (200, 204, 212))           # 冷热两个龙头
            ry = fy - 72
            S().rect(x - 2, ry, x + w + 2, ry + 1, (176, 180, 190))
            S().rect(x + w + 1, ry - 1, x + w + 2, ry + 2, (150, 154, 166))
            cur = [(236, 190, 196), (214, 160, 172), (236, 190, 196), (196, 140, 156)]
            cx0 = x + w - 24
            for i, c in enumerate(cur):
                fx = cx0 + i * 6
                S().poly([(fx, ry + 2), (fx + 6, ry + 2), (fx + 7 + i // 2, fy - 24), (fx - 1 + i // 2, fy - 24)], c)
            S().line(cx0, fy - 24, cx0 + 25, fy - 24, (176, 120, 136))
            for i in range(9):
                S().put(cx0 + 1 + i * 3, ry + 2, (150, 154, 166))
        if wall_h > 120:                                                         # 浴缸上方一扇高高的磨砂窗，上半开着一道缝
            ww = 32
            wx = x + 18
            wy = hi(tile_top - 70 if size == "L" else tile_top - 50)
            wh = tile_top - 16 - wy
            S().rect(wx - 2, wy - 2, wx + ww + 2, wy + wh + 3, (176, 176, 168))
            S().rect(wx, wy, wx + ww, wy + wh, (214, 228, 232))
            S().rect(wx, wy + wh // 2, wx + ww, wy + wh, (196, 214, 222))
            S().line(wx, wy + wh // 2, wx + ww, wy + wh // 2, (176, 176, 168)); S().line(wx + ww // 2, wy, wx + ww // 2, wy + wh, (176, 176, 168))
            S().rect(wx + 1, wy + 1, wx + ww // 2 - 1, wy + 3, (140, 160, 190))   # 开着的缝里看得见一点天
            box(wx - 3, wy + wh + 3, wx + ww + 3, wy + wh + 4, (200, 200, 192), depth=0.05)
            S().rect(wx + 4, wy + wh - 1, wx + 8, wy + wh + 2, (110, 150, 110))

    def sink(x):
        w = 30
        floor_shadow(x + 8, x + 20, fy, 3)
        box(x + 11, fy - 18, x + 17, fy, (226, 226, 220), depth=0.05)            # 立柱
        box(x, fy - 23, x + w, fy - 19, porcelain, depth=0.06)                   # 台盆
        S().rect(x + 13, fy - 27, x + 14, fy - 24, (170, 176, 190)); S().line(x + 14, fy - 27, x + 17, fy - 27, (170, 176, 190))
        plat(x, x + w, fy - 23)
        S().rect(x + 3, fy - 26, x + 7, fy - 24, (226, 214, 200))                # 肥皂
        if wall_h > 70:
            box(x + 1, fy - 66, x + w - 1, fy - 36, (200, 204, 200), depth=0.03)  # 镜柜
            S().rect(x + 3, fy - 64, x + w - 3, fy - 38, (180, 206, 220))
            S().line(x + 7, fy - 60, x + 14, fy - 53, (226, 240, 246)); S().line(x + 9, fy - 60, x + 16, fy - 53, (226, 240, 246))
            S().line(x + w // 2, fy - 64, x + w // 2, fy - 38, (200, 204, 200))
            S().rect(x + w // 2 - 3, fy - 70, x + w // 2 + 3, fy - 68, (226, 220, 200))   # 镜前灯
            S().rect(x + w // 2 - 1, fy - 68, x + w // 2 + 1, fy - 67, (200, 204, 200))
            box(x + 3, fy - 35, x + w - 3, fy - 34, (220, 220, 214), depth=0.04)
            S().rect(x + 5, fy - 39, x + 9, fy - 36, (210, 220, 226))             # 漱口杯 + 四支牙刷
            for i, c in enumerate(CREW):
                S().line(x + 5 + i, fy - 42, x + 5 + i, fy - 39, c)
        if size == "L":
            k.wall_clock(x + w // 2, tile_top - 30, 6)

    def toilet(x):
        w = 40
        floor_shadow(x + 4, x + 24, fy, 3)
        box(x + 4, fy - 32, x + 20, fy - 20, porcelain, depth=0.05)             # 水箱
        S().rect(x + 17, fy - 28, x + 18, fy - 27, (176, 180, 190))
        S().poly([(x + 6, fy), (x + 18, fy), (x + 20, fy - 6), (x + 24, fy - 10), (x + 24, fy - 13), (x + 2, fy - 13), (x + 2, fy - 9), (x + 5, fy - 6)], shade(porcelain, -1))
        box(x + 1, fy - 15, x + 25, fy - 13, porcelain, depth=0.05)              # 坐圈
        S().rect(x + 30, fy - 26, x + 35, fy - 22, (240, 240, 236)); S().rect(x + 29, fy - 27, x + 30, fy - 21, (176, 180, 190))   # 卷纸
        if wall_h > 70:
            wall_shelf(x, x + w - 2, fy - 44, (186, 176, 164))
            plat(x, x + w - 2, fy - 44)
            for i, c in enumerate([(206, 130, 140), (150, 180, 200), (236, 226, 200)]):   # 叠好的毛巾
                box(x + 3, fy - 47 - i * 3, x + 15, fy - 45 - i * 3, c, depth=0.04)
            S().rect(x + 22, fy - 50, x + 27, fy - 45, (176, 110, 86))
            S().line(x + 24, fy - 51, x + 21, fy - 58, (110, 160, 110)); S().line(x + 25, fy - 51, x + 29, fy - 59, (110, 160, 110))
            S().put(x + 21, fy - 59, (140, 190, 130)); S().put(x + 29, fy - 60, (140, 190, 130))
        if wall_h > 100:
            k.crew_photo(x + 9, fy - 82)

    def laundry(x):
        w = 46
        floor_shadow(x, x + 28, fy, 4)
        c = (226, 226, 220)
        box(x, fy - 28, x + 28, fy, c)                                           # 洗衣机
        S().rect(x + 2, fy - 26, x + 26, fy - 22, shade(c, -1))
        S().rect(x + 18, fy - 25, x + 19, fy - 24, (226, 72, 64)); S().rect(x + 21, fy - 25, x + 24, fy - 24, (120, 120, 132))
        ring = np.abs(np.hypot(k.XX - (x + 14), k.YY - (fy - 11)) - 7) < 1.0
        S().fill_mask(ring, (150, 154, 166))
        disc(x + 14, fy - 11, 6, (150, 186, 206)); S().line(x + 11, fy - 14, x + 13, fy - 16, (210, 230, 240))
        plat(x - 1, x + 29, fy - 28)
        bx = x + 32                                                              # 脏衣篮
        floor_shadow(bx, bx + 14, fy, 2)
        S().poly([(bx, fy - 14), (bx + 15, fy - 14), (bx + 13, fy), (bx + 2, fy)], (176, 150, 116))
        for yy in range(fy - 12, fy, 3):
            S().line(bx + 2, yy, bx + 13, yy, (150, 124, 96))
        S().rect(bx + 2, fy - 17, bx + 8, fy - 15, (150, 180, 200)); S().rect(bx + 7, fy - 18, bx + 12, fy - 15, (206, 130, 140))
        if wall_h > 110:                                                         # 墙上的老式热水器：圆筒、表盘、水管上下走
            hx, hy1 = x + 6, fy - 56
            hy0 = hy1 - 38
            vpipe(hx + 4, hy1, fy - 29)
            vpipe(hx + 12, y0, hy0)
            box(hx - 2, hy0, hx + 18, hy1, (214, 210, 200), depth=0.05)
            S().rect(hx - 2, hy0, hx + 18, hy0 + 3, (196, 192, 184)); S().rect(hx - 2, hy1 - 3, hx + 18, hy1, (196, 192, 184))
            disc(hx + 8, hy0 + 14, 4, (236, 236, 226)); S().line(hx + 8, hy0 + 14, hx + 10, hy0 + 12, (176, 80, 72))
            S().rect(hx + 5, hy0 + 24, hx + 11, hy0 + 27, (90, 100, 110)); S().put(hx + 6, hy0 + 25, (240, 150, 80))   # 小火苗窗
        elif wall_h > 70:
            vpipe(x + 10, fy - 70, fy - 29)
        if size == "L":                                                          # 天花板下的排风扇
            fx_, fy_ = x + 30, y0 + 22
            S().rect(fx_ - 1, fy_ - 1, fx_ + 17, fy_ + 15, (176, 176, 168)); S().rect(fx_, fy_, fx_ + 16, fy_ + 14, (150, 150, 146))
            for yy in range(fy_ + 2, fy_ + 13, 3):
                S().line(fx_ + 2, yy, fx_ + 14, yy, (120, 120, 120))

    def radiator(x):
        w = 34
        if size == "L":                                                          # 天花板吊下来一盆绿萝，藤垂下来
            hx, hy = x + 16, fy - int(wall_h * 0.5)
            for dx in (-6, 6):
                S().line(hx, y0 + 6, hx + dx, hy - 1, (176, 156, 120))
            S().poly([(hx - 7, hy), (hx + 8, hy), (hx + 6, hy + 8), (hx - 5, hy + 8)], (186, 120, 96))
            S().line(hx - 7, hy, hx + 7, hy, shade((186, 120, 96), 2))
            for vx, vl in [(hx - 6, 22), (hx - 2, 34), (hx + 3, 16), (hx + 7, 28)]:
                for yy in range(hy + 2, hy + vl, 3):
                    ox = int(2 * np.sin((yy + vx) * 0.5))
                    S().rect(vx + ox, yy, vx + ox + 1, yy + 1, (110, 160, 110) if (yy // 3) % 2 else (140, 186, 130))
            S().rect(hx - 6, hy - 4, hx + 6, hy - 1, (120, 170, 116)); S().put(hx - 3, hy - 5, (150, 200, 140))
        floor_shadow(x, x + 30, fy, 2)
        box(x, fy - 22, x + 30, fy - 4, (196, 190, 180), depth=0.04)             # 铸铁暖气片
        for gx in range(x + 3, x + 30, 4):
            S().line(gx, fy - 21, gx, fy - 5, (170, 164, 156))
        S().rect(x + 2, fy - 3, x + 3, fy, (150, 146, 140)); S().rect(x + 27, fy - 3, x + 28, fy, (150, 146, 140))
        S().rect(x + 4, fy - 30, x + 14, fy - 21, (150, 180, 200)); S().rect(x + 4, fy - 30, x + 14, fy - 29, shade((150, 180, 200), 1))   # 搭着的毛巾
        S().rect(x + 18, fy - 27, x + 26, fy - 21, (226, 214, 180))
        if wall_h > 70:
            ty = fy - 52                                                         # 毛巾杆
            S().rect(x + 2, ty, x + 30, ty + 1, (176, 180, 190))
            S().rect(x + 6, ty + 2, x + 18, ty + 16, (206, 160, 170)); S().rect(x + 15, ty + 4, x + 18, ty + 16, shade((206, 160, 170), -1))
            S().line(x + 6, ty + 13, x + 18, ty + 13, shade((206, 160, 170), -2))

    groups = {
        "L": [(28, 1, cabinet), (66, 5, tub), (30, 3, sink), (40, 4, toilet), (46, 3, laundry), (34, 2, radiator)],
        "M": [(66, 5, tub), (30, 3, sink), (40, 4, toilet), (46, 2, laundry)],
        "S": [(66, 5, tub), (30, 3, sink)],
    }[size]
    placed = spread(tv, groups)
    if size == "S":
        lamps = [(x0 + int(rw * 0.5), y0 + 14)]
    else:
        lamps = [(gx, fy - int(wall_h * 0.55)) for gx in lamp_xs(placed)]
    walls(lamps)
    draw_groups(placed)
    if size != "S":
        S().rect(x0, tile_top - 10, x1, tile_top - 8, pipe)                       # 一根横着走的水管（冷水总管）
        S().line(x0, tile_top - 8, x1, tile_top - 8, pipe_d)
        for lx, ly in lamps:                                                     # 圆球吊灯
            S().line(lx, y0, lx, ly - 5, (150, 150, 150))
            disc(lx, ly, 5, (250, 244, 220)); S().rect(lx - 4, ly + 2, lx + 4, ly + 4, (226, 220, 200))
            S().rect(lx - 2, ly - 6, lx + 2, ly - 5, (176, 176, 170))
    plats_ok(tv, n0)
    k.finish_room(tv, lamps[0])


# ================================================================ 阁楼
def attic(tv):
    """阁楼（琥珀）：两边是斜屋顶的底面（椽子一根根看得见），中间山墙竖着钉木板，一根横梁一根立柱；
    山墙高处一扇圆窗斜着打进一道细光；横梁上吊一只灯泡。地上：旧箱子和行李箱、蒙着布的旧沙发、木马、
    衣架上的旧大衣、木箱上的老收音机、一摞纸箱。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, size = dims(tv)
    n0 = len(sc.PLATFORMS)
    cx = (x0 + x1) // 2
    knee = fy - max(26, int(wall_h * 0.42))                                       # 两边矮墙的高度：屋顶从这里斜上去
    ridge_y = y0 - int(wall_h * 0.25)                                            # 屋脊在屏幕上面，山墙顶被切掉，不是一个大三角
    win = (cx, max(y0 + 14, knee - int(wall_h * 0.28)))
    bulb = (cx - int(rw * 0.22), knee + 6) if size != "S" else (cx, knee + 4)
    lamps = [bulb, win]
    planks = [(178, 144, 112), (164, 130, 102), (148, 116, 94), (128, 100, 84), (110, 86, 76)]
    k.room_base(tv, planks, [(150, 112, 88), (134, 98, 78), (116, 84, 70), (100, 72, 62)], bulb, lamps=lamps)
    paint_wall(tv, y0, fy - 1, planks[2])
    wall_light(tv, lamps, r=max(24.0, wall_h * 0.26), inner=False)               # 阁楼暗：灯和圆窗只照亮一小圈
    m = tv.screen_mask() & (k.YY < fy)
    seam = m & (((k.XX - x0) % 11) == 0)                                          # 山墙的竖木板缝：只比木板暗一档
    seam |= m & (((k.XX - x0) % 11) == 1) & (((k.YY + (k.XX // 11) * 17) % 41) == 0)   # 木板接头
    brighten(seam, -1)
    # 屋顶底面：左右两块，从矮墙顶斜到屋脊，再到屏幕角；椽子是一道道平行于斜边的亮条，越靠前越宽
    roof = (92, 70, 64)
    for side in (-1, 1):
        ex = x0 - 2 if side < 0 else x1 + 2
        pts = [(ex, knee), (cx, ridge_y), (ex, ridge_y)]
        S().poly(pts, roof)
        for i, off in enumerate([3, 10, 21, 37]):                                 # 椽子：一根比一根靠前，往外错
            w_ = 2 + i
            dx = -side * off * 0.9
            p0, p1 = (ex, knee - off * 1.4), (cx + dx * 0.15, ridge_y - off)
            S().poly([(ex, knee - off * 1.4), p1, (p1[0], p1[1] - w_), (ex, knee - off * 1.4 - w_)], (132, 100, 84))
            S().poly([(ex, knee - off * 1.4 + 1), p1, (p1[0], p1[1] + 1), (ex, knee - off * 1.4 + 2)], (70, 54, 52))
        S().line(ex, knee, cx, ridge_y, (150, 116, 94))                          # 山墙边一道亮的封檐板
        S().line(ex, knee + 1, cx, ridge_y + 1, (120, 92, 78))
    # 横梁 + 立柱（只在墙够高时画）
    if wall_h > 80:
        by = knee - int(wall_h * 0.12)
        t = (knee - by) / max(1, knee - ridge_y)
        bx0, bx1 = int(x0 + (cx - x0) * t) - 6, int(x1 - (x1 - cx) * t) + 6
        box(bx0, by, bx1, by + 5, (140, 106, 86), depth=0.05)
        S().line(bx0, by, bx1, by, (170, 134, 104))
        box(cx - 3, y0 - 2, cx + 3, by - 1, (130, 98, 82), depth=0.04)
        # 横梁上挂着的东西：一串干辣椒 / 一只旧风筝……这里挂一盏灯泡和一只鸟笼
        hanging_bulb(bulb[0], by + 6, bulb[1] + 12) if bulb[1] + 12 > by + 10 else None
        if size == "L":                                                           # 横梁上搁着一卷旧地毯，还吊一盏马灯
            rx0, rx1 = bx0 + 30, bx0 + 110
            S().rect(rx0, by - 6, rx1, by - 1, (150, 104, 92)); S().line(rx0, by - 6, rx1, by - 6, (176, 130, 110))
            S().line(rx0, by - 2, rx1, by - 2, (120, 84, 76))
            disc(rx0, by - 4, 3, (176, 130, 110)); disc(rx0, by - 4, 1, (110, 76, 70))
            for fx_ in range(rx0 + 12, rx1, 22):
                S().line(fx_, by - 6, fx_, by - 1, (196, 160, 120))
            lx_ = cx + int(rw * 0.08)
            S().line(lx_, by + 6, lx_, by + 16, (90, 70, 64))
            S().rect(lx_ - 3, by + 17, lx_ + 3, by + 18, (110, 86, 72))
            S().rect(lx_ - 3, by + 19, lx_ + 3, by + 26, (196, 176, 130)); S().rect(lx_ - 1, by + 21, lx_ + 1, by + 24, (226, 200, 140))
            S().rect(lx_ - 4, by + 27, lx_ + 4, by + 28, (110, 86, 72))
            cg = cx + int(rw * 0.2)
            S().line(cg, by + 6, cg, by + 14, (90, 70, 64))
            S().poly([(cg - 6, by + 28), (cg + 7, by + 28), (cg + 7, by + 20), (cg, by + 14), (cg - 6, by + 20)], (110, 86, 72))
            for bxx in range(cg - 4, cg + 7, 3):
                S().line(bxx, by + 19, bxx, by + 27, (176, 146, 110))
            S().rect(cg - 6, by + 28, cg + 7, by + 29, (90, 70, 64))
    # 圆窗 + 一道细光
    if wall_h > 60:
        wx, wy = win
        r = 7 if size == "L" else 6
        disc(wx, wy, r + 2, (110, 84, 72)); disc(wx, wy, r, (246, 228, 176))
        S().line(wx - r, wy, wx + r, wy, (110, 84, 72)); S().line(wx, wy - r, wx, wy + r, (110, 84, 72))
        tx = wx + int(rw * 0.12)
        beam = S().poly([(wx - 3, wy + 2), (wx + 3, wy - 2), (tx + 12, fy), (tx - 2, fy)])
        brighten(beam & tv.screen_mask(), 1)
        rr = random.Random(5)
        for _ in range(int(rw / 25)):
            t = rr.random()
            S().put(int(wx + (tx + 5 - wx) * t + rr.randint(-3, 3)), int(wy + (fy - wy) * t), (252, 238, 200))
    old = (176, 140, 104)

    def trunks(x):
        floor_shadow(x, x + 40, fy, 4)
        c = (120, 84, 66)
        if wall_h > 60:                                                           # 钉在山墙木板上的合照
            k.crew_photo(x + 10, fy - 54)
        box(x, fy - 18, x + 38, fy, c)                                            # 大箱子：皮带、铜角
        S().rect(x + 1, fy - 18, x + 38, fy - 15, shade(c, 1))
        for sx in (x + 9, x + 28):
            S().rect(sx, fy - 18, sx + 2, fy, (90, 64, 54))
        for px, py in [(x, fy - 18), (x + 36, fy - 18), (x, fy - 2), (x + 36, fy - 2)]:
            S().rect(px, py, px + 2, py + 2, (196, 160, 100))
        S().rect(x + 17, fy - 13, x + 20, fy - 10, (196, 160, 100))
        box(x + 2, fy - 28, x + 36, fy - 19, (150, 112, 92))                      # 上面一只行李箱
        S().rect(x + 15, fy - 31, x + 21, fy - 30, (90, 64, 54)); S().put(x + 15, fy - 29, (90, 64, 54)); S().put(x + 21, fy - 29, (90, 64, 54))
        S().rect(x + 8, fy - 25, x + 13, fy - 22, (214, 196, 160))               # 旧标签
        plat(x + 2, x + 36, fy - 28)
        disc(x + 44, fy - 6, 6, (176, 120, 120), 6)                               # 帽盒
        S().rect(x + 38, fy - 13, x + 50, fy - 11, (196, 140, 136)); S().rect(x + 38, fy - 6, x + 50, fy, (150, 100, 100))

    def sofa(x):
        w = 64
        cloth = (164, 154, 138)
        floor_shadow(x, x + w, fy, 4)
        # 一块布盖住整张沙发：靠背、扶手的轮廓还看得出来，布从上往下垂出几道褶，底边拖在地上
        pts = [(x, fy), (x + 1, fy - 18), (x + 4, fy - 20), (x + 9, fy - 17), (x + 10, fy - 26), (x + w // 2, fy - 28),
               (x + w - 10, fy - 26), (x + w - 9, fy - 17), (x + w - 4, fy - 21), (x + w - 1, fy - 18), (x + w, fy)]
        extrude(pts, cloth, depth=0.05, cap=5)
        S().poly([(x + 10, fy - 15), (x + w - 10, fy - 15), (x + w - 9, fy - 12), (x + 10, fy - 12)], shade(cloth, -1))   # 坐垫凹下去的一道
        for fx, h in [(x + 6, 14), (x + 20, 8), (x + 34, 10), (x + 47, 7), (x + w - 6, 13)]:
            S().poly([(fx, fy - h), (fx + 2, fy), (fx - 3, fy)], shade(cloth, -2))
        S().line(x + 10, fy - 26, x + w - 10, fy - 26, shade(cloth, 2))
        S().rect(x + 3, fy - 1, x + w - 3, fy, shade(cloth, -3))
        plat(x + 4, x + w - 4, fy - 24)
        if wall_h > 70:                                                           # 靠着矮墙的两幅旧画
            frame_pic(x + 14, fy - 52, 16, 12, (150, 112, 86), (200, 180, 140), (150, 120, 96))
            S().poly([(x + 38, fy - 30), (x + 56, fy - 30), (x + 58, fy - 50), (x + 40, fy - 50)], (150, 112, 86))
            S().poly([(x + 40, fy - 32), (x + 54, fy - 32), (x + 56, fy - 48), (x + 42, fy - 48)], (110, 86, 72))

    def horse(x):
        c = (196, 156, 116)
        floor_shadow(x, x + 26, fy, 2)
        S().polyline([(x, fy - 2), (x + 6, fy), (x + 20, fy), (x + 26, fy - 2)], (140, 100, 80))   # 摇板
        S().polyline([(x + 1, fy - 1), (x + 6, fy + 1), (x + 20, fy + 1), (x + 25, fy - 1)], (110, 80, 66))
        for lx, ly in [(x + 7, fy), (x + 18, fy)]:
            S().line(lx, fy - 9, lx + (1 if lx < x + 12 else -1), ly - 1, (150, 110, 86))
        box(x + 5, fy - 15, x + 20, fy - 10, c, depth=0.04)                      # 身子
        S().poly([(x + 18, fy - 14), (x + 21, fy - 23), (x + 26, fy - 22), (x + 25, fy - 19), (x + 21, fy - 12)], c)   # 脖子和头
        S().put(x + 23, fy - 21, (60, 44, 44))
        S().line(x + 18, fy - 22, x + 19, fy - 15, (110, 80, 66)); S().line(x + 19, fy - 23, x + 20, fy - 16, (90, 64, 54))   # 鬃毛
        S().line(x + 5, fy - 14, x + 2, fy - 8, (110, 80, 66))                  # 尾巴
        S().rect(x + 10, fy - 16, x + 15, fy - 15, (176, 80, 72))               # 鞍
        for i, c2 in enumerate([(176, 140, 104), (150, 120, 100), (196, 170, 130)]):   # 几块积木
            box(x + 30 + i * 2, fy - 5 - (i == 1) * 5, x + 34 + i * 2, fy - 1 - (i == 1) * 5, c2, depth=0.04)

    def mirror(x):
        """穿衣镜：两条腿撑着一面椭圆镜，一块旧布斜搭在上半截。镜子里映着圆窗的光。"""
        wood_ = (120, 86, 70)
        floor_shadow(x, x + 22, fy, 2)
        S().line(x + 2, fy, x + 5, fy - 30, wood_); S().line(x + 20, fy, x + 17, fy - 30, wood_)
        S().line(x + 3, fy, x + 6, fy - 30, shade(wood_, -2)); S().line(x + 21, fy, x + 18, fy - 30, shade(wood_, -2))
        disc(x + 11, fy - 32, 8, wood_, 14)
        disc(x + 11, fy - 32, 6, (190, 190, 180), 12)
        S().line(x + 8, fy - 38, x + 14, fy - 26, (226, 226, 214)); S().line(x + 9, fy - 40, x + 15, fy - 28, (226, 226, 214))
        S().poly([(x + 1, fy - 46), (x + 12, fy - 48), (x + 21, fy - 45), (x + 22, fy - 30), (x + 18, fy - 34),
                  (x + 14, fy - 30), (x + 10, fy - 36), (x + 4, fy - 33), (x + 1, fy - 37)], (176, 160, 140))
        S().poly([(x + 14, fy - 47), (x + 21, fy - 45), (x + 22, fy - 30), (x + 18, fy - 34)], shade((176, 160, 140), -1))
        S().line(x + 1, fy - 46, x + 12, fy - 48, shade((176, 160, 140), 2))

    def radio(x):
        crate = (150, 116, 86)
        floor_shadow(x, x + 28, fy, 3)
        box(x, fy - 20, x + 28, fy, crate)                                        # 木箱
        for yy in (fy - 14, fy - 7):
            S().line(x, yy, x + 28, yy, shade(crate, -2))
        S().line(x + 2, fy - 19, x + 26, fy - 1, shade(crate, -1))
        plat(x, x + 28, fy - 20)
        rc = (110, 76, 62)                                                         # 拱顶的老收音机
        S().poly([(x + 4, fy - 21), (x + 20, fy - 21), (x + 20, fy - 32), (x + 16, fy - 37), (x + 8, fy - 37), (x + 4, fy - 32)], rc)
        S().poly([(x + 7, fy - 30), (x + 17, fy - 30), (x + 17, fy - 32), (x + 14, fy - 35), (x + 10, fy - 35), (x + 7, fy - 32)], (196, 170, 120))
        for gx in range(x + 9, x + 17, 2):
            S().line(gx, fy - 34, gx, fy - 31, (150, 120, 90))
        S().rect(x + 7, fy - 27, x + 17, fy - 25, (226, 196, 130)); S().put(x + 12, fy - 26, (176, 80, 72))
        S().put(x + 8, fy - 23, (200, 176, 130)); S().put(x + 16, fy - 23, (200, 176, 130))
        S().line(x + 18, fy - 37, x + 23, fy - 44, (90, 70, 64))                   # 天线

    def boxes(x):
        c = (170, 136, 100)
        floor_shadow(x, x + 36, fy, 4)
        for bx, by, bw, bh in [(x, fy, 22, 14), (x + 21, fy, 16, 12), (x + 3, fy - 14, 18, 13), (x + 4, fy - 27, 20, 12)]:
            box(bx, by - bh, bx + bw, by, c if (bx + by) % 2 else shade(c, -1), depth=0.07)
            S().rect(bx + bw // 2 - 1, by - bh, bx + bw // 2 + 1, by - bh + 4, (220, 200, 160))   # 胶带
        plat(x + 4, x + 24, fy - 39)
        S().poly([(x + 8, fy - 39), (x + 17, fy - 39), (x + 15, fy - 46), (x + 10, fy - 46)], (200, 176, 140))   # 顶上一只旧灯罩

    groups = {
        "L": [(24, 2, mirror), (52, 5, trunks), (64, 4, sofa), (28, 4, radio), (38, 3, boxes), (36, 1, horse)],
        "M": [(52, 5, trunks), (64, 4, sofa), (28, 3, radio), (38, 2, boxes)],
        "S": [(52, 5, trunks), (28, 4, radio), (36, 3, horse)],
    }[size]
    draw_groups(spread(tv, groups, margin=10))
    if wall_h > 80:                                                               # 墙角的蛛网
        for side in (-1, 1):
            ex = x0 + 2 if side < 0 else x1 - 2
            for i in range(4):
                S().line(ex, knee - 4 - i * 4, ex - side * (4 + i * 4), knee - 4 - i * 4 - (4 + i * 4) // 2, (176, 156, 140))
    plats_ok(tv, n0)
    k.finish_room(tv, bulb)


# ================================================================ 工作间
def workshop(tv):
    """工作间（琥珀 / 彩色）：工作台上方一块洞洞板（只占台面那一段）挂着认得出的工具，再往上一块搁板放罐子；
    铁架子和上面的电闸箱；红色工具柜、台钻和一扇脏窗；锯木架和从天花板吊下来的手拉葫芦；
    最左边靠墙的木料和自行车，墙上挂着备胎。高处一副吊架放着长木板。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, size = dims(tv)
    n0 = len(sc.PLATFORMS)
    band = fy - (26 if size != "S" else 16)

    def walls(lamps):
        k.room_base(tv, [(176, 168, 150), (160, 150, 134), (142, 132, 120), (122, 112, 104), (104, 96, 92)],
                    [(130, 124, 118), (116, 110, 106), (102, 96, 94), (90, 84, 84)], lamps[0], lamps=lamps)
        paint_wall(tv, y0, band - 1, (150, 140, 124))                            # 墙刷平，灯光自己切
        paint_wall(tv, band, fy - 1, (124, 118, 110))                            # 下面一截水泥墙裙
        wall_light(tv, lamps)
        S().line(x0, band, x1, band, (150, 142, 130))
        if size != "S":
            ceiling(tv, (120, 112, 104), 6 if size == "L" else 4, beams=5 if size == "L" else 3)
    steel = (84, 88, 100)
    hi = lambda y: max(y, y0 + 10)

    def tool(kind, x, y, c=steel):
        """洞洞板上的一件工具，挂钩在 (x, y)。"""
        if kind == "hammer":
            S().rect(x - 1, y, x + 1, y + 14, (150, 110, 80)); S().rect(x - 4, y - 1, x + 4, y + 2, c); S().put(x - 4, y + 2, c)
        elif kind == "saw":
            S().poly([(x, y), (x + 20, y + 2), (x + 20, y + 7), (x, y + 9)], (176, 180, 190))
            for i in range(x + 1, x + 20, 2):
                S().put(i, y + 8 - (i - x) // 10, (120, 124, 136))
            S().rect(x - 5, y, x, y + 9, (150, 96, 70)); S().rect(x - 4, y + 3, x - 2, y + 6, (110, 76, 60))
        elif kind == "wrench":
            for i, h in enumerate((16, 13, 10)):
                wx = x + i * 4
                S().rect(wx, y + 2, wx + 1, y + h, c); S().rect(wx - 1, y, wx + 2, y + 2, c); S().put(wx, y, shade(c, 3))
        elif kind == "pliers":
            S().line(x, y, x - 3, y + 12, (176, 80, 72)); S().line(x + 2, y, x + 5, y + 12, (176, 80, 72)); S().rect(x - 1, y - 4, x + 3, y, c)
        elif kind == "drivers":
            for i, hc in enumerate([(176, 80, 72), (200, 170, 90), (90, 130, 170), (176, 80, 72)]):
                sx_ = x + i * 4
                S().rect(sx_, y, sx_ + 1, y + 4, hc); S().line(sx_, y + 5, sx_, y + 10, c)
        elif kind == "tape":
            disc(x + 3, y + 4, 4, (200, 170, 90)); disc(x + 3, y + 4, 1, (90, 80, 70))
        elif kind == "square":
            S().rect(x, y, x + 1, y + 14, (176, 180, 190)); S().rect(x, y + 13, x + 9, y + 14, (176, 180, 190))
        elif kind == "coil":
            ring = np.abs(np.hypot(k.XX - (x + 5), k.YY - (y + 7)) - 5) < 1.2
            S().fill_mask(ring, (200, 120, 60)); S().line(x + 5, y, x + 5, y + 2, (200, 120, 60))

    def bike(x):
        """靠墙的几根木料、一辆自行车，墙上钩子挂一条备胎和一卷绳子。不站人。"""
        floor_shadow(x, x + 46, fy, 2)
        if wall_h > 70:
            for lx, lh, c in [(x + 2, 74, (186, 156, 116)), (x + 7, 62, (170, 140, 104)), (x + 11, 80, (196, 166, 124))]:
                lh = min(lh, wall_h - 14)
                S().poly([(lx, fy), (lx + 3, fy), (lx + 9, fy - lh), (lx + 6, fy - lh)], c)
                S().line(lx + 3, fy, lx + 9, fy - lh, shade(c, -2))
        bx = x + 14
        for wx in (bx, bx + 24):
            ring = np.abs(np.hypot(k.XX - wx, k.YY - (fy - 8)) - 7.5) < 0.9
            S().fill_mask(ring & tv.screen_mask(), (70, 70, 80))
            S().put(wx, fy - 8, (176, 176, 186))
        S().polyline([(bx, fy - 8), (bx + 9, fy - 18), (bx + 20, fy - 18), (bx + 24, fy - 8), (bx + 12, fy - 8), (bx + 9, fy - 18)], (176, 86, 70))
        S().line(bx + 20, fy - 18, bx + 19, fy - 22, (70, 70, 80)); S().line(bx + 17, fy - 22, bx + 22, fy - 22, (70, 70, 80))
        S().rect(bx + 7, fy - 20, bx + 11, fy - 19, (60, 50, 50))
        if wall_h > 90:
            tx, ty = x + 30, fy - 60
            S().rect(tx - 1, ty - 12, tx + 1, ty - 10, (70, 70, 80))
            ring = np.abs(np.hypot(k.XX - tx, k.YY - ty) - 8) < 1.6
            S().fill_mask(ring, (70, 70, 80))
            tool("coil", x + 26, fy - 92)
            S().rect(x + 30, fy - 94, x + 32, fy - 92, (70, 70, 80))

    def bench(x):
        w = 100
        floor_shadow(x, x + w, fy, 4)
        wood = (150, 110, 80)
        for lx in (x + 2, x + w - 5):
            box(lx, fy - 17, lx + 3, fy, (110, 84, 66))
        box(x + 4, fy - 6, x + w - 4, fy - 5, (110, 84, 66), depth=0.05)          # 下层搁板：几只暗的油漆桶
        for i, c in enumerate([(110, 100, 96), (96, 90, 96), (120, 104, 90)]):
            S().rect(x + 10 + i * 10, fy - 13, x + 16 + i * 10, fy - 7, c); S().line(x + 10 + i * 10, fy - 13, x + 16 + i * 10, fy - 13, shade(c, 1))
        box(x, fy - 21, x + w, fy - 18, wood, depth=0.06)                        # 台面
        plat(x, x + w, fy - 21)
        box(x + 6, fy - 27, x + 15, fy - 22, steel, depth=0.04)                   # 台钳
        S().rect(x + 15, fy - 26, x + 19, fy - 25, shade(steel, 1))
        box(x + 70, fy - 30, x + 88, fy - 22, (176, 86, 70), depth=0.05)          # 红工具箱
        S().rect(x + 75, fy - 33, x + 83, fy - 32, (60, 50, 50)); S().put(x + 75, fy - 31, (60, 50, 50)); S().put(x + 83, fy - 31, (60, 50, 50))
        S().line(x + 70, fy - 27, x + 88, fy - 27, shade((176, 86, 70), -2))
        S().rect(x + 30, fy - 22, x + 52, fy - 22, (196, 180, 150))               # 一块木板、刨子
        box(x + 40, fy - 25, x + 50, fy - 23, (150, 96, 70), depth=0.03)
        S().line(x + 58, fy - 22, x + 58, fy - 40, (60, 56, 60))                  # 夹在台边的工作灯
        S().poly([(x + 54, fy - 40), (x + 63, fy - 44), (x + 62, fy - 47), (x + 55, fy - 45)], (120, 140, 130))
        S().line(x + 55, fy - 40, x + 62, fy - 43, (255, 236, 180))
        if wall_h > 70:                                                           # 洞洞板：只在台面这一段
            py0, py1 = fy - min(80, int(wall_h * 0.78)), fy - 30
            px0, px1 = x + 6, x + w - 6
            box(px0, py0, px1, py1, (182, 154, 118), depth=0.02)
            for hy in range(py0 + 3, py1 - 1, 5):
                for hx in range(px0 + 3, px1 - 1, 5):
                    S().put(hx, hy, (164, 136, 104))
            kinds = ["saw", "hammer", "wrench", "pliers", "drivers", "tape", "square"]
            spots = [(px0 + 9, py0 + 6), (px0 + 36, py0 + 6), (px0 + 46, py0 + 7), (px0 + 62, py0 + 9), (px0 + 70, py0 + 6),
                     (px0 + 9, py0 + 24), (px0 + 26, py0 + 24), (px0 + 74, py0 + 24)]
            for kind, (tx, ty) in zip(kinds, spots):
                if ty + 16 < py1 and tx + 20 < px1:
                    tool(kind, tx, ty)
            if py1 - py0 >= 20:                                                   # 洞洞板右下角钉着那张合照
                k.crew_photo(px0 + 62, py1 - 15)
            if size != "S" and py0 - 30 > y0 + 10:                                # 洞洞板上方一块搁板：罐子
                sy_ = py0 - 10
                wall_shelf(px0, px1, sy_, (130, 100, 80))
                for i, c in enumerate([(150, 150, 160), (176, 140, 90), (120, 140, 120), (186, 176, 150)]):
                    jx = px0 + 6 + i * 21 + (i % 2) * 4
                    box(jx, sy_ - 9 + (i % 2) * 2, jx + 7, sy_ - 1, c, depth=0.04); S().rect(jx, sy_ - 10 + (i % 2) * 2, jx + 7, sy_ - 9 + (i % 2) * 2, shade(c, -2))

    def rack(x):
        w = 40
        floor_shadow(x, x + w, fy, 4)
        h = min(64, wall_h - 12)
        for px in (x, x + w - 2):
            S().rect(px, fy - h, px + 1, fy, (110, 114, 126))
        levels = [fy - 2, fy - 18, fy - 36, fy - 54][: 2 + (h > 40) + (h > 58)]
        for i, ly in enumerate(levels):
            box(x, ly - 1, x + w, ly, (126, 130, 142), depth=0.06)
            if i == 0:
                for j, c in enumerate([(96, 90, 86), (110, 100, 90)]):           # 最下层：暗的大桶
                    S().rect(x + 4 + j * 16, ly - 12, x + 15 + j * 16, ly - 2, c); S().line(x + 4 + j * 16, ly - 12, x + 15 + j * 16, ly - 12, shade(c, 1))
            elif i == 1:
                box(x + 3, ly - 12, x + 20, ly - 2, (186, 150, 108), depth=0.05)
                S().rect(x + 10, ly - 12, x + 12, ly - 9, (220, 200, 160))
                S().rect(x + 24, ly - 8, x + 30, ly - 2, (176, 86, 70)); S().rect(x + 32, ly - 9, x + 37, ly - 2, (120, 140, 170))
            elif i == 2:
                for j in range(4):
                    S().rect(x + 3 + j * 9, ly - 7, x + 8 + j * 9, ly - 2, [(200, 170, 90), (150, 150, 160), (176, 140, 90), (110, 130, 110)][j])
            else:
                box(x + 6, ly - 10, x + 30, ly - 2, (176, 146, 108), depth=0.05)
        plat(x, x + w, fy - 36 if len(levels) > 2 else fy - 18)
        if wall_h > 110:                                                          # 电闸箱：铁皮盒、一根线管直通天花板
            ex, ey = x + 10, fy - 100
            S().rect(ex + 8, y0, ex + 10, ey, (120, 120, 126)); S().line(ex + 10, y0, ex + 10, ey, (96, 96, 104))
            box(ex, ey, ex + 18, ey + 24, (140, 146, 140), depth=0.04)
            S().rect(ex + 2, ey + 2, ex + 16, ey + 22, shade((140, 146, 140), -1))
            S().poly([(ex + 5, ey + 6), (ex + 12, ey + 6), (ex + 8, ey + 12), (ex + 12, ey + 12), (ex + 6, ey + 19), (ex + 8, ey + 13), (ex + 5, ey + 13)], (220, 190, 90))   # 闪电标
            S().rect(ex + 19, ey + 8, ex + 20, ey + 14, (60, 56, 60))                  # 拉闸把手
            S().line(ex + 18, ey + 24, ex + 16, fy - 56, (60, 56, 60))                 # 一根电线垂下来

    def chest(x):
        w = 56
        red = (160, 84, 72)
        floor_shadow(x, x + 30, fy, 4)
        box(x, fy - 28, x + 28, fy - 2, red)                                       # 带轮子的工具柜
        for i in range(4):
            yy = fy - 26 + i * 6
            S().rect(x + 2, yy, x + 26, yy + 4, shade(red, -1)); S().line(x + 2, yy, x + 26, yy, shade(red, 1))
            S().rect(x + 11, yy + 2, x + 17, yy + 2, (196, 196, 206))
        for wx in (x + 3, x + 24):
            S().rect(wx, fy - 1, wx + 2, fy, (60, 56, 60))
        plat(x, x + 28, fy - 28)
        box(x + 4, fy - 33, x + 16, fy - 29, (196, 170, 90), depth=0.04)           # 柜顶一只电钻盒
        dx = x + 40                                                                # 台钻
        floor_shadow(dx - 4, dx + 10, fy, 2)
        box(dx - 4, fy - 2, dx + 8, fy, steel, depth=0.05)
        S().rect(dx, fy - 44, dx + 1, fy - 3, (110, 114, 126))
        box(dx - 3, fy - 24, dx + 8, fy - 22, (110, 114, 126), depth=0.04)
        box(dx - 2, fy - 50, dx + 9, fy - 40, (120, 140, 130))
        S().rect(dx + 3, fy - 39, dx + 4, fy - 32, (176, 180, 190)); S().line(dx + 9, fy - 44, dx + 13, fy - 38, (60, 56, 60))
        if wall_h > 100:                                                           # 上面一扇脏玻璃窗（上下两格）
            ww, wh = 34, min(56, wall_h - 100)
            wy = fy - 62 - wh
            k.window(x + 8, wy, ww, wh, frame=(120, 112, 100), moon=False)
            S().line(x + 10, wy + 2, x + 18, wy + 10, (110, 120, 150))
            box(x + 5, wy + wh + 3, x + ww + 11, wy + wh + 4, (150, 140, 126), depth=0.05)
            S().rect(x + 12, wy + wh - 3, x + 17, wy + wh + 2, (176, 150, 100))     # 窗台上一只油壶

    def sawhorse(x):
        w = 56
        floor_shadow(x, x + w, fy, 3)
        for sx_ in (x + 4, x + w - 12):
            S().line(sx_, fy, sx_ + 4, fy - 16, (150, 110, 80)); S().line(sx_ + 8, fy, sx_ + 4, fy - 16, (124, 90, 66))
            box(sx_ - 1, fy - 18, sx_ + 9, fy - 17, (150, 110, 80), depth=0.04)
        box(x, fy - 21, x + w, fy - 19, (196, 166, 120), depth=0.06)               # 搁着一块长木板
        plat(x, x + w, fy - 21)
        S().rect(x + 20, fy - 23, x + 27, fy - 22, (176, 180, 190))
        S().put(x + 33, fy - 22, (176, 180, 190)); S().put(x + 36, fy - 22, (176, 180, 190))
        S().line(x + w + 2, fy, x + w + 6, fy - 40, (150, 120, 90))                 # 靠墙的扫帚
        S().poly([(x + w + 2, fy), (x + w + 10, fy), (x + w + 7, fy - 6), (x + w + 4, fy - 6)], (176, 150, 100))
        if wall_h > 110:                                                           # 天花板上吊下来的手拉葫芦：链子、滑轮、钩子
            hx = x + w // 2
            hy = fy - int(wall_h * 0.42)
            S().rect(hx - 6, y0 + 6, hx + 6, y0 + 8, (110, 114, 126))
            for yy in range(y0 + 9, hy - 6, 3):
                S().rect(hx - 1, yy, hx, yy + 1, (96, 96, 104)); S().put(hx + 4, yy + 1, (96, 96, 104))
            box(hx - 5, hy - 6, hx + 5, hy, (176, 86, 70), depth=0.04)
            S().line(hx, hy + 1, hx, hy + 12, (96, 96, 104))
            S().polyline([(hx, hy + 12), (hx, hy + 16), (hx + 3, hy + 16), (hx + 3, hy + 13)], (110, 114, 126))
            for yy in range(hy + 1, hy + 30, 3):                                    # 拉链垂到一边
                S().put(hx + 4, yy, (96, 96, 104))

    groups = {
        "L": [(46, 1, bike), (100, 5, bench), (40, 4, rack), (56, 3, chest), (62, 2, sawhorse)],
        "M": [(100, 5, bench), (40, 3, rack), (56, 4, chest)],
        "S": [(100, 5, bench)],
    }[size]
    placed = spread(tv, groups)
    if size == "S":
        lamps = [(x0 + int(rw * 0.5), y0 + 9)]                                   # 小屏：灯贴着天花板，别挡洞洞板
    else:
        lamps = [(gx, fy - int(wall_h * 0.5)) for gx in lamp_xs(placed)]
    walls(lamps)
    draw_groups(placed)
    if size == "L":                                                                # 高处的吊架：两根吊杆挑着几块长木板、一架折叠梯
        ay = fy - int(wall_h * 0.74)
        ax0, ax1 = x0 + int(rw * 0.16), x0 + int(rw * 0.44)
        for ax in (ax0 + 6, ax1 - 6):
            S().rect(ax, y0 + 6, ax + 1, ay + 4, (110, 114, 126))
        box(ax0, ay + 4, ax1, ay + 6, (110, 114, 126), depth=0.04)
        for i, c in enumerate([(186, 156, 116), (170, 140, 104), (196, 166, 124)]):
            S().rect(ax0 + 4 + i * 6, ay - 1 - i * 2, ax1 - 10 + i * 4, ay + 3 - i * 2, c)
            S().line(ax0 + 4 + i * 6, ay - 1 - i * 2, ax1 - 10 + i * 4, ay - 1 - i * 2, shade(c, 1))
    for lx, ly in lamps:
        S().line(lx, y0, lx, ly - 5, (70, 60, 60))
        S().poly([(lx - 6, ly), (lx + 7, ly), (lx + 2, ly - 5), (lx - 1, ly - 5)], (110, 116, 124))
        S().line(lx - 6, ly, lx + 6, ly, (70, 74, 84))
        S().rect(lx - 2, ly + 1, lx + 2, ly + 3, (255, 244, 200))
    plats_ok(tv, n0)
    k.finish_room(tv, lamps[0])


# ================================================================ 教室
def classroom(tv):
    """教室（彩色 / 绿荧光）：老式教室的墙，下半截刷绿漆、上半截米白。
    大黑板（粉笔画着四个小人和一座房子），黑板上方一排字母卡和广播喇叭，讲台在黑板右半边前面；
    一组两张课桌椅；书包柜和地球仪，上方软木板贴着小孩的画和挂钟；两扇高窗、窗台上的花和鱼缸、暖气片；
    两根日光灯管吊下来。"""
    x0, y0, x1, fy = tv.sx0, tv.sy0, tv.sx1, tv.fy
    rw, wall_h, size = dims(tv)
    n0 = len(sc.PLATFORMS)
    green_top = fy - (int(wall_h * 0.3) if size != "S" else 14)

    def walls(lamps):
        k.room_base(tv, [(220, 214, 180), (204, 198, 166), (184, 178, 152), (160, 156, 136), (136, 132, 120)], k.WARM_FLOOR, lamps[0], lamps=lamps)
        paint_wall(tv, y0, green_top - 1, (214, 208, 178))                       # 上半截米白
        paint_wall(tv, green_top, fy - 1, (140, 160, 128))                       # 下半截绿漆
        wall_light(tv, lamps)
        S().rect(x0, green_top, x1, green_top + 1, (110, 132, 104))
        if size != "S":
            ceiling(tv, (196, 192, 170), 6 if size == "L" else 4)
    chalk = (226, 232, 220)
    wood = (150, 104, 82)
    hi = lambda y: max(y, y0 + 8)

    def board(x):
        w = {"L": 150, "M": 120, "S": 70}[size]
        bh = {"L": 64, "M": 52, "S": 34}[size]
        by1 = fy - (40 if size != "S" else 30)
        by0 = hi(by1 - bh)
        S().rect(x - 3, by0 - 3, x + w + 3, by1 + 2, (126, 96, 80))
        S().line(x - 3, by0 - 3, x + w + 3, by0 - 3, (160, 126, 104))
        S().rect(x, by0, x + w, by1, (56, 92, 74))
        S().rect(x, by0, x + w, by0 + (by1 - by0) // 3, (62, 100, 80))
        box(x - 2, by1 + 2, x + w + 2, by1 + 3, (126, 96, 80), depth=0.05)        # 粉笔槽
        S().rect(x + 10, by1 + 1, x + 13, by1 + 1, chalk); S().rect(x + 18, by1 + 1, x + 20, by1 + 1, (226, 160, 160))
        bx, base = x + 12, by1 - 8                                                # 粉笔画：四个手拉手的小人
        for i in range(4):
            fx = bx + i * 9
            S().put(fx + 1, base - 9, chalk); S().line(fx + 1, base - 8, fx + 1, base - 3, chalk)
            S().line(fx - 1, base - 6, fx + 3, base - 6, chalk); S().line(fx + 1, base - 3, fx, base, chalk); S().line(fx + 1, base - 3, fx + 2, base, chalk)
        if w >= 100:                                                              # 一座房子、太阳、一行算式
            hx = x + w - 44
            S().polyline([(hx, base), (hx, base - 12), (hx + 10, base - 21), (hx + 20, base - 12), (hx + 20, base), (hx, base)], chalk)
            S().rect(hx + 8, base - 7, hx + 11, base, chalk)
            S().rect(hx + 13, base - 11, hx + 16, base - 8, chalk)
            ring = np.abs(np.hypot(k.XX - (x + w - 12), k.YY - (by0 + 10)) - 4) < 0.8
            S().fill_mask(ring, chalk)
            sc.digits(x + 6, by0 + 5, "1", chalk); S().line(x + 11, by0 + 7, x + 13, by0 + 7, chalk); S().line(x + 12, by0 + 6, x + 12, by0 + 8, chalk)
            sc.digits(x + 15, by0 + 5, "3", chalk); S().line(x + 19, by0 + 6, x + 21, by0 + 6, chalk); S().line(x + 19, by0 + 8, x + 21, by0 + 8, chalk)
            sc.digits(x + 23, by0 + 5, "4", chalk)
        if size != "S" and by0 - 30 > y0 + 8:                                     # 黑板上方：一排字母卡（只在黑板上方这一段）
            letters = [(206, 120, 110), (110, 150, 200), (220, 200, 130), (130, 180, 120)]
            n = (w - 30) // 13
            for i in range(n):
                lx = x + 14 + i * 13
                c = letters[i % 4]
                ly = by0 - 18 + (i % 2)
                S().rect(lx, ly, lx + 9, ly + 10, (236, 232, 214)); S().rect(lx + 2, ly + 2, lx + 7, ly + 8, c)
                S().rect(lx + 4, ly + 4, lx + 5, ly + 6, (236, 232, 214))
            if size == "L" and by0 - 60 > y0 + 8:                                 # 再往上：国旗似的三角彩旗 + 广播喇叭
                sx_, sy_ = x + w // 2 - 9, by0 - 52
                S().rect(sx_, sy_, sx_ + 18, sy_ + 14, (120, 96, 80)); S().rect(sx_ + 2, sy_ + 2, sx_ + 16, sy_ + 12, (176, 160, 130))
                for yy in range(sy_ + 4, sy_ + 11, 2):
                    S().line(sx_ + 4, yy, sx_ + 14, yy, (140, 124, 104))
                S().line(sx_ + 9, sy_ - 1, sx_ + 9, y0, (110, 104, 96))
        tx = x + w - 52                                                           # 讲台：在黑板右半边前面
        floor_shadow(tx, tx + 44, fy, 4)
        box(tx, fy - 18, tx + 44, fy, wood)
        panel(tx + 3, fy - 15, tx + 20, fy - 3, wood); panel(tx + 24, fy - 15, tx + 41, fy - 3, wood)
        box(tx - 1, fy - 20, tx + 45, fy - 18, shade(wood, 1), depth=0.06)
        plat(tx - 1, tx + 45, fy - 20)
        box(tx + 30, fy - 24, tx + 38, fy - 21, (226, 214, 180), depth=0.03)       # 一摞作业本、一只苹果
        disc(tx + 8, fy - 23, 2, (206, 72, 64)); S().put(tx + 8, fy - 26, (110, 150, 100))
        if size != "S":                                                           # 讲台左边一把老师的椅子
            cx = tx - 14
            S().rect(cx + 1, fy - 9, cx + 1, fy, shade(wood, -2)); S().rect(cx + 9, fy - 9, cx + 9, fy, shade(wood, -2))
            box(cx, fy - 11, cx + 10, fy - 10, wood, depth=0.04)
            box(cx, fy - 24, cx + 2, fy - 12, wood, depth=0.04)

    def desks(x):
        """一组两张课桌，桌边各一把椅子；第二张往后错一点。"""
        for i in range(2):
            dx = x + i * 30
            dy = fy - (i % 2) * 2
            floor_shadow(dx, dx + 22, dy, 3)
            for lx in (dx + 1, dx + 19):
                S().rect(lx, dy - 15, lx + 1, dy, (110, 114, 126))
            box(dx, dy - 18, dx + 21, dy - 16, (184, 140, 108), depth=0.06)
            S().rect(dx + 2, dy - 15, dx + 19, dy - 12, (120, 124, 136))            # 桌肚
            box(dx + 3, dy - 21, dx + 10, dy - 19, [(226, 214, 180), (196, 214, 226)][i], depth=0.03)
            cx = dx + 22
            S().rect(cx + 1, dy - 9, cx + 1, dy, (110, 114, 126)); S().rect(cx + 6, dy - 9, cx + 6, dy, (110, 114, 126))
            box(cx, dy - 11, cx + 7, dy - 10, (184, 140, 108), depth=0.04)
            box(cx + 5, dy - 22, cx + 7, dy - 12, (184, 140, 108), depth=0.04)
            if i == 0:                                                             # 椅背上挂着书包
                S().rect(cx + 7, dy - 20, cx + 11, dy - 13, (96, 136, 214)); S().line(cx + 7, dy - 20, cx + 11, dy - 20, shade((96, 136, 214), 1))
        plat(x, x + 21, fy - 18)
        plat(x + 30, x + 51, fy - 20)
        if wall_h > 110:                                                           # 课桌上方：一张大地图
            mx, my = x + 2, fy - 104
            S().rect(mx - 1, my - 2, mx + 50, my, (126, 96, 80)); S().rect(mx - 1, my + 33, mx + 50, my + 35, (126, 96, 80))
            S().rect(mx, my + 1, mx + 49, my + 32, (110, 150, 186))
            for pts in ([(mx + 4, my + 6), (mx + 18, my + 4), (mx + 20, my + 14), (mx + 12, my + 24), (mx + 6, my + 16)],
                        [(mx + 26, my + 5), (mx + 44, my + 7), (mx + 42, my + 20), (mx + 32, my + 18), (mx + 28, my + 28), (mx + 24, my + 14)]):
                S().poly(pts, (206, 196, 140))
            S().put(mx + 34, my + 12, (206, 72, 64))

    def windows(x):
        w = 70
        if wall_h > 90:
            wh = min(int(wall_h * 0.45), wall_h - 70)
            wy = fy - 40 - wh
            for i in range(2):
                k.window(x + 4 + i * 34, wy, 28, wh, frame=(176, 170, 150), moon=i == 1)
                S().line(x + 4 + i * 34, wy + wh // 3, x + 32 + i * 34, wy + wh // 3, (176, 170, 150))
            box(x, wy + wh + 4, x + 68, wy + wh + 5, (196, 190, 170), depth=0.05)   # 窗台：一盆花、一只小鱼缸
            k.plant(x + 8, wy + wh + 3)
            S().rect(x + 48, wy + wh - 4, x + 58, wy + wh + 3, (176, 206, 214)); S().rect(x + 48, wy + wh - 4, x + 58, wy + wh - 3, (206, 226, 230))
            S().rect(x + 52, wy + wh, x + 54, wy + wh + 1, (230, 150, 80))
        rx = x + 14                                                                  # 暖气片
        floor_shadow(rx, rx + 40, fy, 2)
        box(rx, fy - 16, rx + 40, fy - 4, (186, 186, 180), depth=0.04)
        for gx in range(rx + 3, rx + 40, 4):
            S().line(gx, fy - 15, gx, fy - 5, (160, 160, 156))
        S().rect(rx + 2, fy - 3, rx + 3, fy, (150, 150, 146)); S().rect(rx + 37, fy - 3, rx + 38, fy, (150, 150, 146))

    def cubbies(x):
        w = 44
        floor_shadow(x, x + w, fy, 4)
        box(x, fy - 34, x + w, fy, wood)
        cols = [(206, 120, 110), (110, 150, 200), (220, 200, 130)]
        for r in range(2):
            for c_ in range(3):
                cx, cy = x + 2 + c_ * 14, fy - 32 + r * 15
                S().rect(cx, cy, cx + 11, cy + 12, (84, 62, 56))
                if r == 0:                                                         # 上层放书包；下层（贴地那条）只放暗的鞋袋
                    bc = cols[c_]
                    S().rect(cx + 2, cy + 3, cx + 9, cy + 12, bc); S().rect(cx + 3, cy + 1, cx + 8, cy + 3, shade(bc, -1))
                    S().line(cx + 2, cy + 3, cx + 9, cy + 3, shade(bc, 1))
                else:
                    S().rect(cx + 2, cy + 6, cx + 9, cy + 12, (110, 96, 90))
        plat(x, x + w, fy - 34)
        gx = x + w - 10                                                              # 地球仪
        S().line(gx, fy - 35, gx, fy - 38, (90, 70, 64)); box(gx - 3, fy - 36, gx + 3, fy - 35, (90, 70, 64), depth=0.03)
        disc(gx, fy - 44, 5, (110, 150, 200)); S().poly([(gx - 2, fy - 48), (gx + 3, fy - 46), (gx + 1, fy - 41), (gx - 3, fy - 43)], (130, 180, 120))
        if wall_h > 90:                                                              # 软木板：贴着小孩的画
            cy0 = fy - 92
            S().rect(x - 4, hi(cy0), x + w + 4, cy0 + 40, (150, 110, 80))
            S().rect(x - 2, hi(cy0) + 2, x + w + 2, cy0 + 38, (196, 156, 112))
            pics = [(x + 1, cy0 + 6, (236, 232, 214)), (x + 17, cy0 + 4, (236, 220, 220)), (x + 31, cy0 + 9, (226, 236, 220)),
                    (x + 6, cy0 + 22, (226, 230, 240)), (x + 25, cy0 + 21, (236, 232, 214))]
            for i, (px, py, pc) in enumerate(pics):
                S().rect(px, py, px + 11, py + 12, pc)
                c = CREW[i % 4]
                S().rect(px + 3, py + 4, px + 5, py + 9, c); S().put(px + 4, py + 3, c)    # 每张画一个小人
                if i % 2:
                    S().rect(px + 7, py + 7, px + 9, py + 9, shade(c, -2))
                else:
                    S().put(px + 8, py + 2, (240, 200, 90))
                S().put(px + 5, py, (206, 72, 64))
            if size == "L":
                k.wall_clock(x + w // 2, cy0 - 26, 7)

    groups = {
        "L": [(152, 5, board), (52, 4, desks), (44, 3, cubbies), (70, 2, windows)],
        "M": [(122, 5, board), (52, 4, desks), (44, 3, cubbies)],
        "S": [(72, 5, board), (44, 3, cubbies)],
    }[size]
    placed = spread(tv, groups)
    if size == "S":
        lamps = [(x0 + int(rw * 0.6), y0 + 16)]
    else:
        lamps = [(gx, fy - int(wall_h * 0.68)) for gx in lamp_xs(placed)]
    walls(lamps)
    draw_groups(placed)
    if size != "S":                                                                  # 日光灯管，吊两根链子
        for lx, ly in lamps:
            for cx in (lx - 14, lx + 14):
                S().line(cx, y0, cx, ly - 2, (150, 150, 146))
            box(lx - 18, ly - 2, lx + 18, ly, (196, 196, 190), depth=0.03)
            S().rect(lx - 17, ly + 1, lx + 17, ly + 2, (252, 252, 236))
    plats_ok(tv, n0)
    k.finish_room(tv, lamps[0])


SCENES_V3 = {"study": study, "bathroom": bathroom, "attic": attic, "workshop": workshop, "classroom": classroom}
