"""第三关精英的大号、小号版本（作者 10-18："全都是一个大小的放弹幕的"；布谷鸟钟会话把精英分成 7 种打法、大中小三档，
这里只出图）。每只用原来的画法函数（mobs_*.py 里的 @mob，只读不改），画在一块"缩放画布"上：坐标乘上倍数再画，
光照、色阶由 part() 在新尺寸上重新算，所以是真的更大 / 更小的画，不是把像素放大缩小。帧和原来一样由 mobkit.Mob 生成。

    "~/Desktop/程序programs/AI Oscar/.venv/bin/python" elites_size.py            预览（预览/size_*.png）
    "~/Desktop/程序programs/AI Oscar/.venv/bin/python" elites_size.py --export   另外导出 oscar-rush/art/enemies/l3/size/<name>.png
                                                                                  和 oscar-rush/scripts/enemies/l3/l3_elite_art.gd

大号（约 90～110 像素，走得慢、跺地、跳砸）：水塔、摩天轮、深海潜水员、老树桩。大尺寸上补了一点只有大图才画得出的细节。
小号（约 22～30 像素，飞在空中、俯冲）：复古火箭（一直点着火）、风暴云（去掉雨柱腿，只留几滴雨）、深海鮟鱇（吐气泡）、
蒙尘布幽灵（下摆飘起来、不着地）。
帧：0 待机、1 走 / 飘、2 蓄力、3 出招、4 空中、5 亮相；原图朝左，脚底中间是原点（mobkit 的规矩）。
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import mobkit  # noqa: E402
from mobkit import ELITE, LED, Canvas, Mob, flat, part, shade  # noqa: E402
import mobs_city  # noqa: E402
import mobs_home  # noqa: E402
import mobs_nature  # noqa: E402
import mobs_screen  # noqa: E402

GAME = HERE.parents[2] / "oscar-rush"
OUT_PNG = GAME / "art/enemies/l3/size"
OUT_GD = GAME / "scripts/enemies/l3/l3_elite_art.gd"


class Scaled(Canvas):
    """和原画布共用同一块像素；原画法传进来的坐标乘上 k 再画。线按 k 加粗，红灯在大图里收小一点。"""

    def __init__(self, base: Canvas, k: float):
        self.a = base.a
        self.k = k

    def _x0(self, v):
        return int(math.floor(v * self.k))

    def _x1(self, v):
        return int(math.ceil((v + 1) * self.k)) - 1

    def rect(self, x0, y0, x1, y1, c=None):
        if c is not None and tuple(c[:3]) == LED and self.k > 1.0:
            # 红灯：大图里不跟着放大成一大块，按 0.6 倍放大（还是比原来大一点）
            n = max(2, round((x1 - x0 + 1) * self.k * 0.6))
            cx, cy = (x0 + (x1 - x0 + 1) / 2) * self.k, (y0 + (y1 - y0 + 1) / 2) * self.k
            X0, Y0 = int(round(cx - n / 2)), int(round(cy - n / 2))
            return super().rect(X0, Y0, X0 + n - 1, Y0 + n - 1, c)
        return super().rect(self._x0(x0), self._x0(y0), self._x1(x1), self._x1(y1), c)

    def ellipse(self, cx, cy, rx, ry, c=None):
        return super().ellipse(cx * self.k, cy * self.k, rx * self.k, ry * self.k, c)

    def poly(self, pts, c=None):
        return super().poly([(x * self.k, y * self.k) for x, y in pts], c)

    def line(self, x0, y0, x1, y1, c=None):
        k = self.k
        m = super().line(int((x0 + 0.5) * k), int((y0 + 0.5) * k), int((x1 + 0.5) * k), int((y1 + 0.5) * k))
        s = max(1, round(k))
        if s > 1:
            out = np.zeros_like(m)
            o = s // 2
            for dy in range(s):
                for dx in range(s):
                    out |= np.roll(np.roll(m, dy - o, axis=0), dx - o, axis=1)
            m = out
        if c is not None:
            self.fill_mask(m, c)
        return m

    def polyline(self, pts, c=None):
        m = np.zeros((self.h, self.w), bool)
        for p, q in zip(pts, pts[1:]):
            m |= self.line(*p, *q)
        if c is not None:
            self.fill_mask(m, c)
        return m

    def put(self, x, y, c):
        self.rect(int(x), int(y), int(x), int(y), c)


def scaled_tube(k):
    """mobs_nature.tube 的缩放版（深海潜水员的触手用）。"""
    def tube(c, pts, r0, r1):
        return mobs_nature.__dict__["_orig_tube"](c, [(x * k, y * k) for x, y in pts], r0 * k, r1 * k)
    return tube


mobs_nature.__dict__.setdefault("_orig_tube", mobs_nature.tube)


def octopus_big(k):
    """深海潜水员（hb_octopus）的大号：原函数里吸盘那段按原坐标找行，大图里会找错，这里照抄一份改成按 k 找。"""
    flesh, brass = (156, 100, 124), (200, 156, 88)

    def draw(c, f):
        tents = np.zeros((c.h, c.w), bool)
        sway = 1 if f.step else 0
        for i, (x0, curl) in enumerate([(9, -1), (16, 1), (23, -1), (31, 1), (38, -1), (45, 1)]):
            lift = (4 if i in (0, 1) else 0) if f.attack else 0
            s = curl * (1 if (i + sway) % 2 else -1)
            pts = [(x0, 22), (x0 + s * 2 + (x0 - 27) * 0.1, 29 - lift),
                   (x0 - s * 3 + (x0 - 27) * 0.25, 36 - lift), (x0 + s + (x0 - 27) * 0.3, 43 - lift)]
            tents |= mobs_nature.tube(c, pts, 3.2, 1.0)
        part(c, tents, flesh, bands=0.8)
        # 吸盘：大图里每条触手底边一串亮点
        for y in range(int(30 * k), int(44 * k), 3):
            row = tents[y] & ~tents[min(y + 1, c.h - 1)]
            for x in np.nonzero(row)[0][::2]:
                c.a[y, x] = (*shade(flesh, 2), 255)
        helm = c.ellipse(27, 15, 15, 13)
        part(c, helm, brass)
        part(c, c.rect(13, 24, 41, 28), shade(brass, -1))
        for x in range(15, 41, 2):
            c.put(x, 26, shade(brass, 3))                          # 铆钉（大图里更密）
        flat(c, c.ellipse(27, 14.5, 6.5, 6.5), shade(brass, -3))
        glass = c.ellipse(27, 14.5, 4.8, 4.8)
        flat(c, glass, (64, 82, 98))
        flat(c, glass & c.rect(0, 0, 25, 12), (112, 140, 160))
        for gx, gy in ((15, 11), (39, 11), (27, 3)):
            part(c, c.ellipse(gx + 0.5, gy + 0.5, 2.4, 2.4), shade(brass, -1))
            c.put(gx, gy, (96, 124, 144))
        c.line(40, 5, 46, 0, (100, 92, 84)); c.line(41, 5, 47, 0, (70, 64, 60))
        if f.windup or f.attack:
            for x, y in ((47, 2), (49, 1), (50, 4), (52, 2)):
                c.put(x, y, (226, 228, 232))
        f.led(c, 26, 13, 3)
    return draw


# ---------------------------------------------------------------- 每只的配置
# (名字, 原画法, 原宽, 原高, 倍数, 小号的额外处理)
BIG = [
    ("water_tower", mobs_city.water_tower, 30, 44, 2.3),
    ("ferris_wheel", mobs_screen.ferris_wheel, 40, 46, 2.2),
    ("hb_octopus", None, 54, 44, 2.3),
    ("fr_stump", mobs_nature.fr_stump, 46, 40, 2.5),
]
SMALL = [
    ("space_rocket", mobs_screen.space_rocket, 30, 46, 0.6),
    ("weather_storm", mobs_screen.weather_storm, 44, 38, 0.95),
    ("aq_angler", mobs_nature.aq_angler, 46, 36, 0.62),
    ("dustsheet", mobs_home.dustsheet, 36, 44, 0.6),
]


def wrap(name, fn, k, small):
    def draw(c, f):
        s = Scaled(c, k)
        if name == "space_rocket" and small:
            f.air = True                                    # 小火箭一直点着火在飞
        fn(s, f)
        if not small:
            _big_extra(name, s, f, k)
        else:
            _small_extra(name, c, f, k)
    return draw


def _big_extra(name, c, f, k):
    """大图才有的细节：只加少量，不改原来的造型。"""
    if name == "water_tower":
        tank = (196, 150, 120)
        for x in range(4, 27, 3):                            # 木板缝
            for y in (11, 17, 23):
                c.put(x, y + 1, shade(tank, -2))
        c.line(2, 9, 27, 9, shade(tank, 3))                   # 顶上一道受光的檐
    elif name == "fr_stump":
        bark = (124, 86, 64)
        for x, y in ((9, 14), (30, 16), (25, 27), (12, 28)):  # 树皮上的节疤
            c.put(x, y, shade(bark, -3))
            c.put(x + 1, y, shade(bark, 1))
    elif name == "ferris_wheel":
        pass                                                  # 辐条、灯泡在大图里本来就多了


def _small_extra(name, c, f, k):
    """小号飞行版：去掉腿、加尾焰 / 气泡 / 飘起来的下摆。c 是原尺寸（小）的画布。"""
    a = c.a
    h, w = a.shape[:2]
    if name == "space_rocket":
        _rocket_porthole(a)
        _merge_lone_edge(a)
    if name == "weather_storm":
        # 去掉雨柱腿：云底以下只留几滴雨，像一团飘着的雷暴云
        cloud_bottom = int(math.ceil(25 * k))
        drops = a[cloud_bottom:].copy()
        a[cloud_bottom:] = 0
        for i, x in enumerate(range(3, w - 2, 4)):
            y = cloud_bottom + 1 + ((i + f.i) % 3) * 2
            if y < h:
                a[y, x] = (168, 200, 240, 255)
        if f.attack or f.pose:                                # 闪电还是要劈下来
            for y in range(cloud_bottom, h):
                x = int(w / 2 - 2 + ((y * 3) % 4) - 1)
                a[y, x] = (252, 230, 110, 255)
    elif name == "aq_angler":
        _angler_teeth(a)
        _merge_lone_edge(a)
        for (x, y) in ((1, 4), (2, 1), (0, 7)):               # 嘴前冒的气泡
            yy = (y + f.i) % max(1, h // 2)
            if 0 <= yy < h and a[yy, x, 3] == 0:
                a[yy, x] = (200, 230, 236, 255)
    elif name == "dustsheet":
        # 下摆飘起来：最底下两行往两边错开一格，不着地
        for y in range(h - 2, h):
            row = a[y].copy()
            a[y] = np.roll(row, 1 if (y + f.i) % 2 else -1, axis=0)


def _red(a):
    m = (a[..., 0] == LED[0]) & (a[..., 1] == LED[1]) & (a[..., 2] == LED[2]) & (a[..., 3] > 0)
    ys, xs = np.nonzero(m)
    return (int(xs.min()), int(ys.min())) if len(xs) else None


def _mode(px):
    cols = [tuple(int(v) for v in p) for p in px]
    return max(set(cols), key=cols.count) if cols else None


def _rocket_porthole(a):
    """小火箭的舷窗按小尺寸手点（美术巡检 10-18：缩小后黄铜圈和深色玻璃糊成一团、碎点 12%）：
    中间 2×2 红灯当亮点，外面一圈 1 格黄铜，四个角留机身色，周围别的杂色都抹成机身色。"""
    led = _red(a)
    if led is None:
        return
    lx, ly = led
    box = a[ly - 2:ly + 4, lx - 2:lx + 4]
    flat = box.reshape(-1, 4)
    brass = _mode([p for p in flat if p[3] and p[0] > p[2] + 40 and tuple(p[:3]) != LED])
    near = a[ly - 4:ly + 6, lx - 3:lx + 5].reshape(-1, 4)
    hull = _mode([p for p in near if p[3] and abs(int(p[0]) - int(p[2])) < 30 and p[0] > 120])
    if brass is None or hull is None:
        return
    for y in range(ly - 2, ly + 4):
        for x in range(lx - 2, lx + 4):
            if a[y, x, 3] and not (lx <= x <= lx + 1 and ly <= y <= ly + 1):
                a[y, x] = hull
    for x in (lx, lx + 1):
        a[ly - 1, x] = brass
        a[ly + 2, x] = brass
    for y in (ly, ly + 1):
        a[y, lx - 1] = brass
        a[y, lx + 2] = brass
    a[ly:ly + 2, lx:lx + 2] = (*LED, 255)


def _angler_teeth(a):
    """小鮟鱇的嘴按小尺寸手点（美术巡检 10-18：一排牙缩小后变成噪点）：
    嘴是两行深色缝（上一行短一点），里面三颗白牙：上面两颗往下、下面一颗往上。"""
    led = _red(a)
    if led is None:
        return
    lx, ly = led
    y0, y1 = ly + 4, ly + 9
    reg = a[y0:y1, :lx + 4]
    dark = (reg[..., 3] > 0) & (reg[..., :3].astype(int).sum(-1) < 160)
    white = (reg[..., 3] > 0) & (reg[..., :3].min(-1) > 200)
    ys, xs = np.nonzero(dark | white)
    if not len(xs):
        return
    x0, x1, my0, my1 = int(xs.min()), int(xs.max()), y0 + int(ys.min()), y0 + int(ys.max())
    body = _mode([p for p in a[my0 - 2:my1 + 3, x0:x1 + 1].reshape(-1, 4)
                  if p[3] and 160 <= int(p[0]) + int(p[1]) + int(p[2]) and p[:3].min() <= 200])
    mouth = _mode([p for p in reg[dark]])
    for y in range(my0, my1 + 1):
        for x in range(x0, x1 + 1):
            if a[y, x, 3]:
                a[y, x] = body
    W = (240, 236, 226, 255)
    for x in range(x0 + 1, x1):
        a[my0, x] = mouth
    for x in range(x0, x1 + 1):
        a[my0 + 1, x] = mouth
    for x, y in ((x0 + 2, my0), (x0 + 7, my0), (x0 + 4, my0 + 1)):
        a[y, x] = W


def _merge_lone_edge(a, dist=70):
    """缩小以后轮廓上一格一格的受光 / 背光边成了碎点（看着像一圈描边）：轮廓上自己一个颜色的单个像素，
    颜色和旁边差得不多的，并进旁边最多的那个颜色。差得多的（红灯、白牙、诱饵灯、气泡）不动。"""
    h, w = a.shape[:2]
    src = a.copy()
    al = src[..., 3] > 0
    for y, x in zip(*np.nonzero(al)):
        c = src[y, x, :3].astype(int)
        nb, edge, same = [], False, False
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            yy, xx = y + dy, x + dx
            if not (0 <= yy < h and 0 <= xx < w) or not al[yy, xx]:
                edge = True
                continue
            if (src[yy, xx, :3] == src[y, x, :3]).all():
                same = True
            nb.append(tuple(int(v) for v in src[yy, xx]))
        if not edge or same or not nb:
            continue
        best = max(set(nb), key=nb.count)
        if abs(np.array(best[:3]) - c).sum() < dist:
            a[y, x] = best


def build(name, fn, w0, h0, k, small):
    if fn is None:
        fn = None
    w, h = round(w0 * k), round(h0 * k)
    if name == "hb_octopus":
        mobs_nature.tube = scaled_tube(k)
        base_fn = octopus_big(k)
        draw = lambda c, f: (base_fn(Scaled(c, k), f), _big_extra(name, Scaled(c, k), f, k))  # noqa: E731
    else:
        draw = wrap(name, fn, k, small)
    m = Mob("size", name, ELITE, w, h, "", draw, moves=["slam"])
    m.build()
    mobs_nature.tube = mobs_nature.__dict__["_orig_tube"]
    return m


def preview(mobs, path, title):
    S = 3 if any(m.frame_size[1] > 80 for m in mobs) else 5
    BG = (104, 102, 110)
    rows = []
    for m in mobs:
        strip = m.strip()
        rows.append(Image.fromarray(strip).resize((strip.shape[1] * S, strip.shape[0] * S), Image.NEAREST))
    W = max(r.size[0] for r in rows) + 40
    H = sum(r.size[1] + 30 for r in rows) + 60
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype(str(GAME / "fonts/PixelFont.ttf"), 20)
    except OSError:
        font = None
    d.text((16, 12), title, fill=(235, 232, 228), font=font)
    y = 50
    for m, r in zip(mobs, rows):
        d.text((16, y - 2), f"{m.name}  {m.frame_size[0]}x{m.frame_size[1]}", fill=(235, 232, 228), font=font)
        img.paste(r, (20, y + 22), r)
        y += r.size[1] + 30
    img.save(path)


def main():
    export = "--export" in sys.argv
    big = [build(n, fn, w, h, k, False) for n, fn, w, h, k in BIG]
    small = [build(n, fn, w, h, k, True) for n, fn, w, h, k in SMALL]
    (HERE / "预览").mkdir(exist_ok=True)
    preview(big, HERE / "预览/size_大号.png", "第三关精英 大号（3 倍；0 待机 1 走 2 蓄力 3 出招 4 空中 5 亮相）")
    preview(small, HERE / "预览/size_小号.png", "第三关精英 小号（5 倍；飞行版）")
    for m in big + small:
        f0 = m.frames[0]
        ys = np.nonzero((f0[..., 3] > 0).any(1))[0]
        print(f"{m.name}: 帧 {m.frame_size}，身高 {ys.max() - ys.min() + 1}，body_rect {m.body_rect}，leds {m.leds}")
    if export:
        OUT_PNG.mkdir(parents=True, exist_ok=True)
        lines = ['## 第三关精英的大号、小号贴图（草图/第三关/怪物/elites_size.py 生成，放映机会话 10-18）。',
                 '## l3_elite.gd 用 load() 读 ART：哪只在里面就用哪只的新图，不在的照旧用 level3_mobs.gd 里的原图。',
                 '## body_rect 以脚底中间为原点，是挨打框；leds 是每帧红灯在原图里的像素（含义和 level3_mobs.gd 一样）。',
                 '', 'const ART := {']
        for m in big + small:
            Image.fromarray(m.strip()).save(OUT_PNG / f"{m.name}.png")
            br = m.body_rect
            # 框底贴着脚底（end.y = 0），不然站在地上会陷进地里（布谷鸟钟会话 10-18：树桩、风暴云原来高 3、6 像素）
            br = (br[0], br[1], br[2], -br[1])
            leds = ", ".join(f"{i}: Vector2i({x}, {y})" for i, (x, y) in sorted(m.leds.items()))
            size = "big" if m in big else "small"
            lines.append(f'\t"{m.name}": {{"size": "{size}", "texture": "res://art/enemies/l3/size/{m.name}.png", '
                         f'"hframes": 6, "frame_size": Vector2i({m.frame_size[0]}, {m.frame_size[1]}), '
                         f'"body_rect": Rect2({br[0]}, {br[1]}, {br[2]}, {br[3]}), "leds": {{{leds}}}}},')
        lines.append('}')
        OUT_GD.write_text("\n".join(lines) + "\n")
        print("导出到", OUT_PNG, "和", OUT_GD)


if __name__ == "__main__":
    main()
