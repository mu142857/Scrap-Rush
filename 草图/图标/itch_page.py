"""REWIND RUSH 的 itch 页面装修（放映机会话，10-19）。参考作者前作 Linger 的 itch 页：顶上一条标题横幅，页面黑底，两侧散着小像素装饰。

    "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" itch_page.py

输出 Oscar Rush/itch素材/页面装修/：
  banner_960x300.png、banner_1920x600.png
      标题横幅。1 倍画布 240×75，整 4 / 8 倍最近邻放大。和 ldjam 封面 A6 统一：
      第二关片库（棕褐色胶片调）当背景，左边四个船员提着马灯（2 倍），右边两行大字 REWIND / RUSH（游戏的像素字），
      马灯的暖光一圈圈打在场景上；四边一档一档压暗，最外一圈就是页面底色，融进黑底。
  bg_rust_tile_512.png（256 的图案、2 倍像素）
      能无缝平铺的页面背景：第一关锅炉房那种生锈的铁板。64 格一块板，板缝、四角铆钉、锈斑、锈水往下淌，全部按 256 取模画，左右上下接得上。
      整体很暗（OKLab 明度 0.10~0.2），压在下面不影响读字。
  bg_film_tile_512.png
      备选：如果"第一张"说的是 itch素材 的 banner_1（序章片库），用这张：一排排片盒架子，同样很暗、能平铺。
  page_bg_1920x1200.png
      不平铺的整张背景（itch"背景图片"选不重复、顶部居中）：锈铁底，中间 960 宽留干净，两侧散着小装饰。
  deco/*.png
      散在两侧的小装饰，透明底：螺丝、齿轮、铆钉板、小弯管、碎铁片、扳手、断掉的胶片头。都是 1 倍画、整 4 倍放大（和 page_bg 里的铁板一个像素大小）。
配色建议写在同目录的 配色.md。
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "itch素材/页面装修"

# 借 ldjam 封面小样 mock.py 里的画法（像素字、船员、马灯、胶片色），只取函数，不跑它出图的那段
_src = (ROOT / "ldjam/封面小样/mock.py").read_text()
_ns = {}
exec(_src[:_src.index("def save(")], _ns)
layers, sepia, glow, crew, glyph_mask = (_ns[k] for k in ("layers", "sepia", "glow", "crew", "glyph_mask"))
L2 = ["level2_far_0.png", "level2_mid_0.png", "level2_main_0.png"]

PAGE = (12, 9, 8)                       # 页面底色（也是横幅最外一圈）
TITLE = (246, 226, 186)
TITLE_OUT = (14, 9, 6)


# ---------------------------------------------------------------- 横幅
def title_layer(s, scale, fill=TITLE, outline=TITLE_OUT):
    g = glyph_mask(s)
    m = np.zeros((g.shape[0] + 2, g.shape[1] + 2), bool)
    m[1:-1, 1:-1] = g
    o = np.zeros_like(m)
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            o |= np.roll(np.roll(m, dy, 0), dx, 1)
    rgba = np.zeros(m.shape + (4,), np.uint8)
    rgba[o] = outline + (255,)
    rgba[m] = fill + (255,)
    t = Image.fromarray(rgba)
    return t.resize((t.width * scale, t.height * scale), Image.NEAREST)


def edge_fade(im, steps=((3, 0.82), (6, 0.62), (9, 0.42), (12, 0.24), (15, 0.1)), sides=(1, 1, 1, 1)):
    """四边一档一档压暗到页面底色（硬边的台阶，不用渐变）：steps = (离边多少格以内, 保留多少)。"""
    a = np.asarray(im.convert("RGB")).astype(float)
    h, w = a.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    l, t, r, b = sides
    d = np.full((h, w), 999)
    if l:
        d = np.minimum(d, xs)
    if r:
        d = np.minimum(d, w - 1 - xs)
    if t:
        d = np.minimum(d, ys)
    if b:
        d = np.minimum(d, h - 1 - ys)
    keep = np.ones((h, w))
    for lim, k in sorted(steps, key=lambda s: -s[0]):
        keep[d < lim] = k
    keep[d < 1] = 0.0
    page = np.array(PAGE, float)
    out = a * keep[..., None] + page * (1 - keep[..., None])
    return Image.fromarray(out.clip(0, 255).astype(np.uint8))


def banner():
    W, H = 240, 75
    room = layers(L2, (556, 231, 556 + W, 231 + H))
    room = Image.fromarray((np.asarray(room).astype(float) * [1.3, 1.3, 1.3, 1]).clip(0, 255).astype(np.uint8))
    pic = sepia(room, 0.78)
    im = Image.new("RGBA", (W, H), PAGE + (255,))
    im.alpha_composite(pic)
    # 四个船员 + 马灯，2 倍（先在透明小图上按原大画，再放大）
    lay = Image.new("RGBA", (80, 24), (0, 0, 0, 0))
    lamp = crew(lay, (66, 22), gap=9)
    lay = lay.resize((160, 48), Image.NEAREST)
    feet = (72, 69)
    ox, oy = feet[0] - 132, feet[1] - 44
    lamp_at = (ox + lamp[0] * 2, oy + lamp[1] * 2)
    im = glow(im, lamp_at, [(62, 0.14), (42, 0.26), (24, 0.42)])
    im.alpha_composite(lay, (ox, oy))
    # 右边压一块暗，好放字（一档档往左淡）
    a = np.asarray(im).astype(float)
    for x in range(92, W):
        k = 0.6 if x >= 152 else 1.0 - (x - 92) * (0.4 / 60)
        a[:, x, :3] *= round(k * 10) / 10                     # 一档 0.1，台阶不是渐变
    im = Image.fromarray(a.clip(0, 255).astype(np.uint8))
    t1, t2 = title_layer("REWIND", 3), title_layer("RUSH", 3)
    tx = W - t1.width - 4
    im.alpha_composite(t1, (tx, 9))
    im.alpha_composite(t2, (tx, 9 + t1.height - 1))
    im = edge_fade(im, steps=((2, 0.8), (4, 0.62), (6, 0.44), (8, 0.26), (10, 0.12)))
    return im


# ---------------------------------------------------------------- 平铺背景
RUST = [(40, 22, 18), (56, 30, 22), (74, 40, 26)]
IRON = [(16, 13, 13), (20, 16, 16), (24, 19, 18), (29, 23, 21), (36, 29, 26), (46, 37, 32)]


def wrap_put(a, x, y, c):
    n = a.shape[0]
    a[y % n, x % n] = c


def rust_tile(n=256, seed=3):
    """锈铁板：每块 64×64（每行错开半块），板面上下两档明暗（左上亮一档），板缝暗、缝下一道亮；
    四角铆钉；随机锈斑和锈水（往下淌）全部按 n 取模画，所以四边接得上。"""
    rng = np.random.default_rng(seed)
    a = np.zeros((n, n, 3), np.uint8)
    P = 64
    for row in range(n // P):
        off = (P // 2) * (row % 2)
        for col in range(n // P):
            shade = 2 + int(rng.integers(0, 2))
            for y in range(P):
                for x in range(P):
                    c = IRON[shade] if (x + y) < P * 0.9 else IRON[shade - 1]
                    wrap_put(a, col * P + off + x, row * P + y, c)
            x0, y0 = col * P + off, row * P
            for t in range(P):                                  # 板缝
                wrap_put(a, x0 + t, y0, IRON[0])
                wrap_put(a, x0 + t, y0 + 1, IRON[4])
                wrap_put(a, x0, y0 + t, IRON[0])
                wrap_put(a, x0 + 1, y0 + t, IRON[4])
            for dx, dy in ((5, 5), (P - 5, 5), (5, P - 5), (P - 5, P - 5)):   # 铆钉
                wrap_put(a, x0 + dx, y0 + dy, IRON[5])
                wrap_put(a, x0 + dx + 1, y0 + dy + 1, IRON[0])
                wrap_put(a, x0 + dx + 1, y0 + dy, IRON[3])
    for _ in range(26):                                         # 锈斑
        x, y = int(rng.integers(0, n)), int(rng.integers(0, n))
        for _ in range(int(rng.integers(6, 18))):
            wrap_put(a, x + int(rng.integers(-3, 4)), y + int(rng.integers(-2, 3)), RUST[int(rng.integers(0, 3))])
    for _ in range(30):                                         # 锈水往下淌
        x, y = int(rng.integers(0, n)), int(rng.integers(0, n))
        for t in range(int(rng.integers(6, 22))):
            wrap_put(a, x, y + t, RUST[0] if t < 4 else IRON[1])
    for _ in range(40):                                         # 划痕（亮一档的短斜线）
        x, y = int(rng.integers(0, n)), int(rng.integers(0, n))
        for t in range(int(rng.integers(3, 7))):
            wrap_put(a, x + t, y + t // 2, IRON[4])
    return a


def film_tile(n=256, seed=5):
    """备选（banner_1 片库那种）：一排排片盒架，暗棕褐。架板 64 一层，片盒是一摞摞扁圆柱。"""
    rng = np.random.default_rng(seed)
    SEP = [(18, 13, 10), (24, 18, 14), (31, 23, 17), (40, 30, 22), (52, 39, 28)]
    a = np.zeros((n, n, 3), np.uint8)
    a[:] = SEP[1]
    for y in range(0, n, 4):                                    # 墙上的竖条壁纸（很淡）
        pass
    for x in range(0, n, 8):
        a[:, x] = SEP[0]
    for shelf in range(n // 64):
        y0 = shelf * 64
        a[y0 + 56:y0 + 58] = SEP[4]
        a[y0 + 58:y0 + 60] = SEP[0]
        x = int(rng.integers(0, 10))
        while x < n:
            hgt = int(rng.integers(2, 6))
            for k in range(hgt):                                # 一摞片盒
                yy = y0 + 55 - k * 5
                for xx in range(x, x + 14):
                    wrap_put(a, xx, yy - 3, SEP[3])
                    wrap_put(a, xx, yy - 2, SEP[2])
                    wrap_put(a, xx, yy - 1, SEP[2])
                    wrap_put(a, xx, yy, SEP[0])
                wrap_put(a, x + 2, yy - 3, SEP[4])
            x += 16 + int(rng.integers(0, 10))
    return a


# ---------------------------------------------------------------- 小装饰
D = [(34, 28, 26), (52, 42, 36), (74, 60, 48), (104, 84, 64), (140, 114, 84), (176, 146, 106)]
RU = [(70, 36, 24), (104, 54, 32), (140, 76, 40)]
BR = [(96, 72, 36), (150, 116, 60), (206, 168, 98)]


def sprite(rows, key):
    h, w = len(rows), max(len(r) for r in rows)
    a = np.zeros((h, w, 4), np.uint8)
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in key:
                a[y, x] = (*key[ch], 255)
    return a


KEY = {"1": D[0], "2": D[1], "3": D[2], "4": D[3], "5": D[4], "6": D[5], "r": RU[0], "s": RU[1], "t": RU[2],
       "a": BR[0], "b": BR[1], "c": BR[2]}

DECO = {
    "bolt": [                         # 六角螺丝（从上面看）
        "..4444..",
        ".455543.",
        "45566543",
        "45632543",
        "45632543",
        "35554432",
        ".344432.",
        "..2222..",
    ],
    "gear": [                         # 小齿轮
        "....55....",
        "..5.55.5..",
        ".5545544..",
        "..54..43..",
        "5554..4332",
        "5444..3332",
        "..43..32..",
        ".4433322..",
        "..3.33.2..",
        "....22....",
    ],
    "rivet_plate": [                  # 一小块打了铆钉的铁片，边上生锈
        "455555543.",
        "5634443543",
        "5444444443",
        "544s444443",
        "54sts44443",
        "544s4s3443",
        "5444443s32",
        "5634443s32",
        "4333333r2.",
    ],
    "pipe": [                         # 小弯管（带一圈黄铜箍）
        "5555bb....",
        "4444ab....",
        "3333ab55..",
        "2222a4443.",
        "....334332",
        "....233322",
        "....bbbb..",
        "....aaaa..",
        "....3322..",
        "....3322..",
    ],
    "shard": [                        # 碎铁片（斜着的）
        "......54",
        "....5543",
        "..554s3.",
        ".54ts3..",
        "543s32..",
        "4332....",
        "32......",
    ],
    "wrench": [                       # 扳手
        ".55..........",
        "5.4..........",
        "54444444444..",
        ".4333333333..",
        "..........43.",
        "..........4.3",
        "...........33",
    ],
    "film_end": [                     # 断掉的一截胶片头（棕褐，两排齿孔）
        "3333333333",
        "3.33.33.33",
        "3aaaaaaaa3",
        "3abbbbbba3",
        "3abccccba3",
        "3abbbbbba3",
        "3aaaaaaaa3",
        "3.33.33.3.",
        "333333333.",
    ],
}


def deco_sprites():
    return {k: np.kron(sprite(v, KEY), np.ones((4, 4, 1), np.uint8)) for k, v in DECO.items()}


def page_bg(tile, decos, W=1920, H=1200, clear=980, seed=11):
    """整张不平铺的背景：锈铁平铺铺满（整 2 倍），中间 clear 宽的一条再压暗一档留给正文，两侧散装饰。"""
    t2 = np.kron(tile, np.ones((4, 4, 1), np.uint8))           # 和装饰一样 4 倍像素
    n = t2.shape[0]
    reps = (H // n + 1, W // n + 1, 1)
    bg = np.tile(t2, reps)[:H, :W].astype(float)
    x0, x1 = (W - clear) // 2, (W + clear) // 2
    bg[:, x0:x1] *= 0.7
    for k, w in ((6, 0.85), (12, 0.92)):                        # 中间那条的边一档档过渡
        bg[:, x0 - k:x0] = np.minimum(bg[:, x0 - k:x0], bg[:, x0 - k:x0] * w + 0)
        bg[:, x1:x1 + k] = np.minimum(bg[:, x1:x1 + k], bg[:, x1:x1 + k] * w + 0)
    out = Image.fromarray(bg.clip(0, 255).astype(np.uint8)).convert("RGBA")
    rng = np.random.default_rng(seed)
    names = list(decos)
    for side in (0, 1):
        y = 60
        while y < H - 80:
            name = names[int(rng.integers(0, len(names)))]
            im = Image.fromarray(decos[name])
            if rng.random() < 0.5:
                im = im.transpose(Image.FLIP_LEFT_RIGHT)
            if rng.random() < 0.3:
                im = im.transpose(Image.ROTATE_90)
            margin = 70
            span = x0 - margin * 2 - im.width
            x = margin + int(rng.integers(0, max(1, span)))
            if side:
                x = W - x - im.width
            out.alpha_composite(im, (x, y))
            y += 150 + int(rng.integers(0, 140))
    return out.convert("RGB")


PALETTE_MD = """# itch 页面配色（编辑主题里填）

和游戏同一套：黑底 + 马灯的暖黄。

| itch 里的项 | 颜色 | 说明 |
|---|---|---|
| 背景色 Background | `#0C0908` | 页面底色，横幅最外一圈也是这个色，所以横幅融进去看不出边 |
| 正文底色 Inner column / 内栏背景 | `#16110F` | 比底色亮一点点的暖黑；不想要内栏就设成和背景一样 |
| 正文字色 Text | `#D9CBB6` | 暖米白，和游戏里的说明字一样 |
| 链接色 Link | `#FFD38A` | 马灯玻璃的暖黄（游戏里马灯就是这个色） |
| 按钮色 Button | `#FFD38A` | 同上；按钮上的字 `#1A120C` |
| 边框 / 分隔线 Border | `#3A2B22` | 锈铁的暗棕 |
| 标题字 Header | `#F6E2BA` | 和横幅大字同一个米黄 |

字体建议选等宽或像素感强的（itch 里有 "Press Start 2P" 之类），没有就用默认的无衬线。

背景图两种用法（二选一）：
- `bg_rust_tile_512.png`：背景图片 → 平铺（Repeat）。整页都是暗锈铁。
- `page_bg_1920x1200.png`：背景图片 → 不重复、顶部居中（Top center, no repeat），中间留干净、两侧散着螺丝齿轮。
  比 1920 宽的屏幕两边会露出底色 `#0C0908`，和图的最外圈一样暗，看不出断。
备选：作者说的"第一张"如果是 banner_1（序章片库），把背景换成 `bg_film_tile_512.png`（棕褐片盒架）。
"""


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    b = banner()
    b.resize((960, 300), Image.NEAREST).save(OUT / "banner_960x300.png")
    b.resize((1920, 600), Image.NEAREST).save(OUT / "banner_1920x600.png")
    rt = rust_tile()
    k2 = np.ones((2, 2, 1), np.uint8)
    Image.fromarray(np.kron(rt, k2)).save(OUT / "bg_rust_tile_512.png")       # 2 倍像素，平铺用
    Image.fromarray(np.kron(film_tile(), k2)).save(OUT / "bg_film_tile_512.png")
    decos = deco_sprites()
    (OUT / "deco").mkdir(exist_ok=True)
    for k, v in decos.items():
        Image.fromarray(v).save(OUT / "deco" / f"{k}.png")
    page_bg(rt, decos).save(OUT / "page_bg_1920x1200.png")
    (OUT / "配色.md").write_text(PALETTE_MD)
    print("ok")


if __name__ == "__main__":
    main()
