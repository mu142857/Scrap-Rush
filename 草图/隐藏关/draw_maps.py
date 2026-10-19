"""画隐藏关的总图、房间图集、节奏曲线。数据在 rooms.py。
    python3 草图/隐藏关/draw_maps.py
输出到 截图/隐藏关设计/。只是设计图，不进游戏。
"""
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from rooms import ROOMS, LINKS, ORDER, ZONES, ZONE_LABEL

HERE = Path(__file__).resolve().parent
OUT = HERE.parent.parent / "截图" / "隐藏关设计"
OUT.mkdir(parents=True, exist_ok=True)
FONT_PATH = "/System/Library/Fonts/Hiragino Sans GB.ttc"


def font(size):
    return ImageFont.truetype(FONT_PATH, size)


BG = (18, 16, 24)
PANEL = (28, 25, 36)
INK = (232, 226, 214)
DIM = (140, 134, 150)
NEUTRAL = (84, 76, 98)
NEUTRAL_TOP = (120, 110, 136)
MEM = (238, 178, 108)
MEM_TOP = (255, 222, 160)
JUNK = (96, 124, 162)
JUNK_TOP = (150, 182, 220)
FRAME_A = (230, 130, 160)
FRAME_B = (110, 210, 200)
RED = (232, 72, 64)
GOLD = (255, 206, 110)
GREEN = (120, 220, 140)
ROOM = {r[0]: r for r in ROOMS}


# ---------------------------------------------------------------- 房间里的图块

def draw_room_layout(d, ox, oy, room, tile, labels=True, small_font=None):
    """把一个房间的布局画在 (ox, oy)，tile 是一格多少像素。"""
    rid, name, zone, x, y, w, h, tension, mins, line, els = room
    tw, th = round(30 * w), round(17 * h)
    W, H = tw * tile, th * tile
    zc = ZONES[zone][1]
    d.rectangle([ox, oy, ox + W, oy + H], fill=(22, 20, 30), outline=zc, width=2)
    # 屏幕扫描线的感觉
    for yy in range(int(oy) + 2, int(oy + H), 4):
        d.line([ox + 1, yy, ox + W - 1, yy], fill=(26, 24, 34))
    sf = small_font or font(max(9, tile * 2))

    def R(x0, y0, x1, y1, **kw):
        d.rectangle([ox + x0 * tile, oy + y0 * tile, ox + x1 * tile - 1, oy + y1 * tile - 1], **kw)

    for el in els:
        k = el[0]
        if k == "L":
            cx, cy = ox + (el[1] + 0.5) * tile, oy + (el[2] + 0.5) * tile
            r = 5.6 * tile   # 灯光半径 90 像素 = 5.6 格
            d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(60, 46, 34))
    for el in els:
        k = el[0]
        if k == "n":
            _, a, b, w_, h_ = el
            R(a, b, a + w_, b + h_, fill=NEUTRAL)
            R(a, b, a + w_, b + 1 if h_ > 1 else b + 0.34, fill=NEUTRAL_TOP)
        elif k == "m":
            _, a, b, w_ = el
            R(a, b, a + w_, b + 1, fill=MEM)
            R(a, b, a + w_, b + 0.34, fill=MEM_TOP)
        elif k == "j":
            _, a, b, w_ = el
            R(a, b, a + w_, b + 1, fill=JUNK)
            for i in range(w_ * 2):
                xx = ox + a * tile + i * tile / 2
                d.line([xx, oy + (b + 1) * tile - 1, xx + tile / 2, oy + b * tile], fill=JUNK_TOP)
        elif k == "wj":
            _, a, b, h_ = el
            for i in range(h_):
                R(a, b + i, a + 1, b + i + 0.6, fill=JUNK)
        elif k in ("a", "b"):
            _, a, b, w_ = el
            col = FRAME_A if k == "a" else FRAME_B
            if k == "a":
                R(a, b, a + w_, b + 1, fill=col)
            else:
                R(a, b, a + w_, b + 1, outline=col, width=2)
            if labels:
                d.text((ox + a * tile + 2, oy + b * tile - tile * 1.6), k.upper(), fill=col, font=sf)
        elif k == "h":
            _, a, b, w_ = el
            for i in range(w_ * 2):
                xx = ox + a * tile + i * tile / 2
                d.line([xx, oy + (b + 0.5) * tile + (2 if i % 2 else -2), xx + tile / 2, oy + (b + 0.5) * tile + (-2 if i % 2 else 2)],
                       fill=(230, 230, 240), width=2)
        elif k == "g":
            _, a = el
            R(a, 0, a + 0.5, th - 1, fill=(150, 70, 60))
        elif k == "o":
            _, cx, cy, r = el
            pcx, pcy, pr = ox + cx * tile, oy + cy * tile, r * tile
            d.ellipse([pcx - pr, pcy - pr, pcx + pr, pcy + pr], outline=MEM, width=1)
            n = 6 if r > 4 else 2
            for i in range(n):
                ang = i / n * math.tau
                px, py = pcx + math.cos(ang) * pr, pcy + math.sin(ang) * pr
                d.rectangle([px - tile * 1.2, py - tile * 0.3, px + tile * 1.2, py + tile * 0.3], fill=MEM)
    for el in els:
        k = el[0]
        cx = ox + (el[1] + 0.5) * tile if k not in ("n", "g", "o") else 0
        cy = oy + (el[2] + 0.5) * tile if len(el) > 2 and k not in ("n", "g", "o") else 0
        if k == "L":
            d.rectangle([cx - tile * 0.5, cy - tile * 0.9, cx + tile * 0.5, cy + tile * 0.5], fill=GOLD)
        elif k == "e":
            d.ellipse([cx - tile * 0.6, cy - tile * 0.6, cx + tile * 0.6, cy + tile * 0.6], fill=(200, 60, 60))
            if labels:
                d.text((cx + tile * 0.8, cy - tile), el[3], fill=(240, 150, 140), font=sf)
        elif k == "X":
            s = tile * 1.6
            d.polygon([(cx, cy - s), (cx + s, cy), (cx, cy + s), (cx - s, cy)], fill=RED, outline=(255, 200, 190))
            d.text((cx - s, cy - s - tile * 2.4), "精英 · " + el[3], fill=(255, 190, 180), font=sf)
        elif k == "B":
            s = tile * 2.6
            pts = []
            for i in range(10):
                rr = s if i % 2 == 0 else s * 0.45
                ang = -math.pi / 2 + i * math.pi / 5
                pts.append((cx + math.cos(ang) * rr, cy + math.sin(ang) * rr))
            d.polygon(pts, fill=RED, outline=(255, 220, 200))
            d.text((cx + s, cy - s), "BOSS · " + el[3], fill=(255, 200, 190), font=sf)
        elif k == "S":
            d.text((cx - tile * 0.6, cy - tile * 1.2), "★", fill=(255, 240, 150), font=font(max(10, int(tile * 2.2))))
        elif k == "P":
            d.rectangle([cx - tile * 0.7, cy - tile * 0.9, cx + tile * 0.7, cy + tile * 0.4], fill=(240, 240, 240), outline=(120, 110, 100))
        elif k == "F":
            d.rectangle([cx - tile, cy - tile * 0.6, cx + tile, cy + tile * 0.6], fill=(40, 40, 40), outline=GOLD, width=2)
            d.ellipse([cx - tile * 0.7, cy - tile * 0.3, cx - tile * 0.1, cy + tile * 0.3], outline=GOLD)
            d.ellipse([cx + tile * 0.1, cy - tile * 0.3, cx + tile * 0.7, cy + tile * 0.3], outline=GOLD)
        elif k == "C":
            d.rectangle([cx - tile * 0.2, cy - tile * 1.6, cx + tile * 0.2, cy + tile * 0.5], fill=(110, 100, 90))
            d.ellipse([cx - tile * 0.6, cy - tile * 2.2, cx + tile * 0.6, cy - tile], fill=GREEN)
        elif k == "K":
            d.rectangle([cx - tile, cy - tile, cx + tile, cy + tile * 0.5], fill=(250, 210, 80), outline=(80, 60, 20))
            d.rectangle([cx - tile * 0.5, cy - tile * 0.7, cx - tile * 0.15, cy + tile * 0.2], fill=(60, 40, 10))
            d.rectangle([cx + tile * 0.15, cy - tile * 0.7, cx + tile * 0.5, cy + tile * 0.2], fill=(60, 40, 10))
        elif k == "d":
            d.text((cx - tile, cy - tile * 1.2), el[3], fill=(200, 230, 255), font=sf)
        elif k == "t" and labels:
            d.text((ox + el[1] * tile, oy + el[2] * tile), el[3], fill=DIM, font=sf)
    return W, H


# ---------------------------------------------------------------- 总图

def overview():
    S = 118          # 一屏在总图上多宽
    SY = 66          # 一屏多高
    xs = [r[3] for r in ROOMS] + [r[3] + r[5] for r in ROOMS]
    ys = [r[4] for r in ROOMS] + [r[4] + r[6] for r in ROOMS]
    minx, maxx, miny, maxy = min(xs), max(xs), min(ys), max(ys)
    mx, my = 60, 150
    W = int((maxx - minx) * S + mx * 2)
    Hmap = int((maxy - miny) * SY)
    H = my + Hmap + 60 + 420 + 120
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((mx, 30), "隐藏关 · 第四盘「倒带」 REWIND — 总图（侧视，1 格 = 1 屏 480×270）", fill=INK, font=font(34))
    d.text((mx, 80), "主线从左往右 = 磁带往回倒：越往右，回忆越早。客厅是中转站：上去生日、下去雪天，两段片段都拿到才开电视门。",
           fill=DIM, font=font(18))

    def box(rid):
        r = ROOM[rid]
        x0 = mx + (r[3] - minx) * S
        y0 = my + (r[4] - miny) * SY
        return x0, y0, x0 + r[5] * S, y0 + r[6] * SY

    # 区域底色
    for rid, r in ROOM.items():
        x0, y0, x1, y1 = box(rid)
        zc = ZONES[r[2]][1]
        d.rectangle([x0 - 6, y0 - 6, x1 + 6, y1 + 6], fill=tuple(int(c * 0.18) for c in zc))
    # 连线
    for a, b, kind in LINKS:
        ax0, ay0, ax1, ay1 = box(a)
        bx0, by0, bx1, by1 = box(b)
        pa = ((ax0 + ax1) / 2, (ay0 + ay1) / 2)
        pb = ((bx0 + bx1) / 2, (by0 + by1) / 2)
        col = {"main": (230, 220, 200), "branch": (200, 200, 230), "back": (150, 150, 170), "secret": (255, 236, 140), "locked": (230, 120, 110)}[kind]
        width = {"main": 6, "branch": 4, "back": 2, "secret": 2, "locked": 5}[kind]
        if kind in ("back", "secret"):
            n = int(math.dist(pa, pb) // 14) + 1
            for i in range(n):
                t0, t1 = i / n, (i + 0.5) / n
                d.line([pa[0] + (pb[0] - pa[0]) * t0, pa[1] + (pb[1] - pa[1]) * t0,
                        pa[0] + (pb[0] - pa[0]) * t1, pa[1] + (pb[1] - pa[1]) * t1], fill=col, width=width)
        else:
            d.line([pa, pb], fill=col, width=width)
    # 房间：缩略布局 + 名字
    for rid, r in ROOM.items():
        x0, y0, x1, y1 = box(rid)
        tile = S / 30.0
        sub = Image.new("RGB", (int(x1 - x0) + 2, int(y1 - y0) + 2), BG)
        sd = ImageDraw.Draw(sub)
        draw_room_layout(sd, 0, 0, r, tile, labels=False)
        sub = sub.resize((int(x1 - x0), int(y1 - y0)))
        img.paste(sub, (int(x0), int(y0)))
        d.rectangle([x0, y0, x1, y1], outline=ZONES[r[2]][1], width=3)
        label = f"{rid} {r[1].split(' · ')[0]}"
        fs = 15 if r[5] >= 1 else 12
        tb = d.textbbox((0, 0), label, font=font(fs))
        d.rectangle([x0 + 2, y0 + 2, x0 + 8 + tb[2], y0 + 6 + tb[3]], fill=(10, 10, 14))
        d.text((x0 + 5, y0 + 3), label, fill=INK, font=font(fs))
    # 区域名
    seen = {}
    for rid, r in ROOM.items():
        z = r[2]
        x0, y0, x1, y1 = box(rid)
        seen.setdefault(z, [x0, y0, x1, y1])
        b = seen[z]
        seen[z] = [min(b[0], x0), min(b[1], y0), max(b[2], x1), max(b[3], y1)]
    for z, (x0, y0, x1, y1) in seen.items():
        if z in ZONE_LABEL and ZONE_LABEL[z] is None:
            continue
        name, zc = ZONES[z]
        if z in ZONE_LABEL:
            lx, lyy = ZONE_LABEL[z]
            x0, y0 = mx + (lx - minx) * S, my + (lyy - miny) * SY + 30
        d.text((x0, y0 - 30), f"{z} · {name}", fill=zc, font=font(19))

    # 图例
    ly = my + Hmap + 40
    legend = [
        (MEM, "回忆平台：暖色，被光照到才是实的（马灯、闪光灯光球、激光、电钳的光）"),
        (JUNK, "覆盖层废铁：冷色斜纹，暗处才是实的；带灯走近就化掉"),
        (NEUTRAL, "中性：录像带边框、地面、大家具，任何时候都能站"),
        (FRAME_A, "跳帧房间的 A 帧平台（实心）／ B 帧（空心青色）"),
        ((250, 210, 80), "暂停键：拍一下，4 秒里除了你全部定格"),
        ((230, 230, 240), "雪花带：会扫过来的干扰条，碰到掉灯"),
    ]
    for i, (c, txt) in enumerate(legend):
        lx = mx + (i % 2) * 900
        yy = ly + (i // 2) * 30
        d.rectangle([lx, yy + 4, lx + 30, yy + 20], fill=c)
        d.text((lx + 42, yy), txt, fill=INK, font=font(17))
    sy = ly + 100
    syms = [("★", (255, 240, 150), "秘密"), ("▯", (240, 240, 240), "家庭照片（8 张）"), ("▭", GOLD, "磁带片段"),
            ("◆", RED, "精英"), ("✸", RED, "Boss"), ("●", GREEN, "存档"), ("━", (230, 220, 200), "主线"),
            ("┅", (150, 150, 170), "回程"), ("┅", (255, 236, 140), "秘密通道"), ("━", (230, 120, 110), "锁着的门")]
    xx = mx
    for s, c, t in syms:
        d.text((xx, sy), s, fill=c, font=font(20))
        d.text((xx + 28, sy + 2), t, fill=INK, font=font(16))
        xx += 30 + d.textbbox((0, 0), t, font=font(16))[2] + 30

    # 节奏曲线
    cy0 = sy + 70
    ch = 300
    cw = W - mx * 2
    d.text((mx, cy0 - 10), "节奏曲线（按一般玩家的走法：先生日、后雪天；横轴是分钟，竖轴是紧张度 0～10）", fill=INK, font=font(20))
    top = cy0 + 30
    d.rectangle([mx, top, mx + cw, top + ch], fill=PANEL)
    total = sum(ROOM[r][8] for r in ORDER)
    for lv in range(0, 11, 2):
        yy = top + ch - lv / 10 * ch
        d.line([mx, yy, mx + cw, yy], fill=(44, 40, 54))
        d.text((mx - 26, yy - 9), str(lv), fill=DIM, font=font(14))
    t = 0.0
    pts = []
    for rid in ORDER:
        r = ROOM[rid]
        x_a = mx + t / total * cw
        x_b = mx + (t + r[8]) / total * cw
        yy = top + ch - r[7] / 10 * ch
        zc = ZONES[r[2]][1]
        d.rectangle([x_a + 1, yy, x_b - 1, top + ch], fill=tuple(int(c * 0.35) for c in zc))
        pts += [(x_a, yy), (x_b, yy)]
        label = rid
        d.text((x_a + 3, top + ch + 6), label, fill=DIM, font=font(12))
        t += r[8]
    d.line(pts, fill=(255, 230, 190), width=3)
    for m in range(0, int(total) + 1, 2):
        xx = mx + m / total * cw
        d.text((xx - 6, top + ch + 26), f"{m}′", fill=DIM, font=font(13))
    d.text((mx + cw - 330, cy0 - 10), f"合计约 {total:.0f} 分钟（第一次通关）", fill=GOLD, font=font(20))
    img.save(OUT / "1_总图_侧视.png")
    print("1_总图", img.size, f"{total:.1f} min")


# ---------------------------------------------------------------- 房间图集

def atlas():
    tile = 8
    cols = 3
    ids = [r[0] for r in ROOMS]
    cards = []
    for rid in ids:
        r = ROOM[rid]
        w = round(30 * r[5]) * tile
        h = round(17 * r[6]) * tile
        cards.append((rid, w, h))
    colw = max(c[1] for c in cards) + 40
    pad_text = 92
    # 按列排：一行行塞
    rows = []
    row, rw = [], 0
    for c in cards:
        if len(row) == cols:
            rows.append(row)
            row = []
        row.append(c)
    if row:
        rows.append(row)
    W = cols * colw + 60
    heights = [max(c[2] for c in rr) + pad_text + 50 for rr in rows]
    H = 120 + sum(heights)
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    d.text((30, 30), "隐藏关 · 房间图集（每格 16 像素；橙圈 = 建议放灯 / 扔灯的位置和 90 像素灯光）", fill=INK, font=font(28))
    y = 100
    sf = font(12)
    for rr, hh in zip(rows, heights):
        for i, (rid, w, h) in enumerate(rr):
            r = ROOM[rid]
            x = 30 + i * colw
            zc = ZONES[r[2]][1]
            d.text((x, y), f"{rid} · {r[1]}", fill=zc, font=font(20))
            d.text((x, y + 28), f"紧张度 {r[7]} · 约 {r[8]} 分钟 · {ZONES[r[2]][0]}", fill=DIM, font=font(14))
            draw_room_layout(d, x, y + 52, r, tile, labels=True, small_font=sf)
            # 一句话，自动折行
            txt = r[9]
            lines, cur = [], ""
            for ch in txt:
                cur += ch
                if d.textbbox((0, 0), cur, font=font(14))[2] > colw - 50:
                    lines.append(cur)
                    cur = ""
            lines.append(cur)
            for k, ln in enumerate(lines[:3]):
                d.text((x, y + 60 + h + k * 19), ln, fill=INK, font=font(14))
        y += hh
    img.save(OUT / "2_房间图集.png")
    print("2_房间图集", img.size)


if __name__ == "__main__":
    overview()
    atlas()
