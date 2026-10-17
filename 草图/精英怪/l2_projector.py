"""第二关精英怪：放映机（CinemaProjector）。照第一关精英怪（elites.py）的画法画：
暖调深灰一个色相，亮框暗芯，光从上面来，不描边，腿是几根细线，一只红色指示灯当眼睛（在镜头上方），原图朝左。

    python3 l2_projector.py          # 草图 projector_sketch.png（1 倍：平时、放招两格）+ 放大预览 projector_preview.png
                                     # 再导出游戏用的 oscar-rush/art/enemies/projector.png

造型：老式 35mm 电影放映机。上面一个送片盘、下面一个收片盘，中间是机芯，左边伸出镜头筒，
右边是灯箱（顶上一个散热烟囱），底下铸铁立柱和底座，底座下面长了腿。

projector.png 横排等宽帧，帧号 = 姿势 × 4 + 片盘相位（片盘一直在转，每个姿势都有 4 个相位）：
  姿势 0 站着、1 走（左脚在前）、2 走（右脚在前）、3 预警（镜头缩回、腿撑开）、4 放光（镜头伸出、镜片亮、灯箱缝发红）
光柱、银幕光框、镜头的光晕都由 projector.gd 用代码画（不吃压暗），这里不画。
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import elites
from elites import G, RGB

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[1] / "oscar-rush/art/enemies"

# 镜片亮起来的暖白（光效，和红灯一样算点缀色）
RGB["W"] = (244, 226, 192)
RGB["w"] = (176, 150, 112)

W, H = 46, 56
GROUND = H - 1
LENS_Y = 24          # 镜头中心那一行
LED = (11, 20)       # 红灯
UP_REEL = (24.5, 9.0, 8.6)
LOW_REEL = (21.5, 37.0, 7.1)


def reel(g, cx, cy, r, phase):
    """片盘：亮边框（上亮下暗）+ 盘面 + 三个镂空孔（随 phase 转，每格 30°）+ 轮毂。"""
    for y in range(g.h):
        for x in range(g.w):
            d = math.hypot(x - cx, y - cy)
            if d <= r + 0.3:
                if d > r - 0.9:
                    # 边框：上面亮、两侧中、下面暗
                    s = (cy - y) / r
                    g.put(x, y, 8 if s > 0.55 else 7 if s > 0.0 else 5 if s > -0.6 else 4)
                else:
                    g.put(x, y, 4)
    # 盘面左上一小段亮弧（光从上面来）
    for a in range(200, 290, 12):
        x = round(cx + (r - 1.8) * math.cos(math.radians(a)))
        y = round(cy + (r - 1.8) * math.sin(math.radians(a)))
        g.put(x, y, 5)
    # 三个镂空孔
    hr = r * 0.55
    for k in range(3):
        a = math.radians(phase * 30 + k * 120 - 90)
        hx, hy = cx + hr * math.cos(a), cy + hr * math.sin(a)
        rad = r * 0.24
        for y in range(int(hy - 3), int(hy + 4)):
            for x in range(int(hx - 3), int(hx + 4)):
                if math.hypot(x - hx, y - hy) <= rad + 0.35:
                    g.put(x, y, 0)
        # 孔的下沿受光亮一档
        g.put(round(hx), round(hy + rad), 3)
    # 轮毂
    g.disk(cx, cy, 1.6, 6)
    g.put(round(cx - 0.5), round(cy - 1), 9)


def leg(g, x, y, ground, d, spread, foot_dx=0):
    """细线腿（照爬虫）：从底座往外撇，膝盖高高折一下，再落到地上（d=-1 往左撇，1 往右撇）。"""
    kx, ky = x + d * spread, y + 1
    g.line(x, y, kx, ky, 5)
    fx = kx + d + foot_dx
    g.line(kx, ky, fx, ground, 4)
    g.put(fx + d, ground, 4)


def body(pose, phase):
    g = G(W, H)
    # ---- 灯箱（后面）+ 散热烟囱 ----
    g.rect(34, 12, 37, 16, 5)
    g.rect(34, 12, 34, 16, 7)
    g.rect(33, 11, 38, 11, 9)
    g.rect(33, 12, 38, 12, 7)
    g.box(30, 17, 41, 30, base=4, top=8, left=6, right=5, bottom=3)
    for y in (21, 24, 27):                                           # 散热缝
        g.rect(33, y, 39, y, "r3" if pose == 4 else 1)
        g.rect(33, y + 1, 39, y + 1, 5)
    g.rect(31, 18, 31, 29, 7)
    # 电源线从灯箱后面垂下来，拖到底座上
    g.path([(41, 27), (43, 31), (44, 37), (42, 43)], 3)

    # ---- 上片盘和支臂 ----
    g.rect(24, 15, 25, 19, 5)
    reel(g, *UP_REEL, phase)

    # ---- 机芯 ----
    g.box(14, 19, 30, 31, base=4, top=8, left=7, right=5, bottom=3)
    g.rect(15, 20, 29, 20, 6)
    g.disk(23.5, 25.5, 2.6, 6, ring=1)                                # 输片齿轮
    g.disk(23.5, 25.5, 0.9, 7)
    for x in range(18, 29, 2):                                        # 底边一排铆钉
        g.put(x, 29, 6)
    # 片子：从上片盘左边进机芯，从机芯底下出来进下片盘
    g.path([(16, 11), (15, 15), (16, 19)], 2)
    g.path([(15, 32), (14, 36)], 2)

    # ---- 镜头筒（朝左）----
    ext = {3: 1, 4: -1}.get(pose, 0)                                  # 预警缩回 1 格，放光伸出 1 格
    g.box(10, LENS_Y - 3, 13, LENS_Y + 3, base=5, top=8, left=6, right=4, bottom=3)
    x0 = 5 + ext
    g.rect(x0 + 1, LENS_Y - 2, 9, LENS_Y + 2, 4)
    g.rect(x0 + 1, LENS_Y - 2, 9, LENS_Y - 2, 7)
    g.rect(x0 + 1, LENS_Y + 2, 9, LENS_Y + 2, 3)
    g.put(8, LENS_Y - 3, 6)                                           # 调焦钮
    g.rect(x0, LENS_Y - 3, x0, LENS_Y + 3, 6)                         # 镜头口的圈
    g.put(x0, LENS_Y - 3, 8)
    gx = x0 - 1
    if pose == 4:
        g.rect(gx, LENS_Y - 2, gx, LENS_Y + 2, "W")
        g.put(gx, LENS_Y + 2, "w")
    else:
        g.rect(gx, LENS_Y - 2, gx, LENS_Y + 2, 1)
        g.put(gx, LENS_Y - 2, 7)

    # ---- 镜头上方的小罩子和红灯 ----
    g.box(9, 18, 14, 20, base=3, top=8, left=6, right=4, bottom=2)
    g.led(*LED)

    # ---- 下片盘、铸铁立柱、底座 ----
    g.box(29, 31, 34, 45, base=4, top=6, left=6, right=3, bottom=3)
    g.rect(30, 33, 30, 43, 5)
    reel(g, *LOW_REEL, (phase + 2) % 4)
    g.poly([(12, 48), (15, 45), (41, 45), (44, 48)], 4)
    g.path([(15, 45), (41, 45)], 7)
    g.path([(12, 48), (15, 45)], 6)
    g.path([(13, 48), (43, 48)], 3)

    # ---- 腿 ----
    # 前两条往左撇、后两条往右撇；走路时前后两对交替迈
    roots = [(15, 49), (21, 49), (35, 49), (41, 49)]
    ds = [-1, -1, 1, 1]
    if pose in (3, 4):
        spreads, dxs = [3, 2, 2, 3], [-1, 0, 0, 1]                    # 撑开站稳
    elif pose == 1:
        spreads, dxs = [3, 2, 2, 3], [-1, 1, -1, 1]
    elif pose == 2:
        spreads, dxs = [3, 2, 2, 3], [1, -1, 1, -1]
    else:
        spreads, dxs = [2, 2, 2, 2], [0, 0, 0, 0]
    for (x, y), d, s, dx in zip(roots, ds, spreads, dxs):
        leg(g, x, y, GROUND, d, s, dx)
    return g.rgba()


# ---------------------------------------------------------------- 预览
def sketch_pair():
    return [body(0, 0), body(4, 1)]


def beam_mock(img):
    """预览里示意光柱：从镜头往地面打一道半透明暖白光（游戏里用代码画）。"""
    S = img.shape
    pad = 120
    out = np.zeros((S[0], S[1] + pad, 4), np.uint8)
    out[:, pad:] = img
    ov = Image.new("RGBA", (out.shape[1], out.shape[0]), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    lx, ly = pad + 3, LENS_Y
    d.polygon([(lx, ly - 2), (lx, ly + 2), (20, GROUND + 1), (2, GROUND + 1)], fill=(255, 236, 200, 90))
    d.polygon([(lx, ly - 1), (lx, ly + 1), (16, GROUND + 1), (6, GROUND + 1)], fill=(255, 244, 220, 120))
    d.rectangle([0, GROUND - 1, 24, GROUND], fill=(255, 240, 210, 200))
    base = Image.fromarray(out)
    base.alpha_composite(ov)
    return np.asarray(base)


def preview():
    from PIL import ImageFont
    font = None
    for p in [HERE.parents[1] / "oscar-rush/fonts/PixelFont.ttf", Path("/System/Library/Fonts/PingFang.ttc")]:
        try:
            font = ImageFont.truetype(str(p), 22)
            break
        except OSError:
            pass
    pair = sketch_pair()
    # 1 倍草图：平时、放招两格并排
    sk = np.zeros((H, W * 2 + 4, 4), np.uint8)
    sk[:, :W] = pair[0]
    sk[:, W + 4:] = pair[1]
    Image.fromarray(sk).save(HERE / "projector_sketch.png")

    crawler = np.asarray(Image.open(HERE.parents[1] / "oscar-rush/art/enemies/crawler.png").convert("RGBA"))[:, :36]
    hp = HERE.parents[1] / "oscar-rush/art/chars/red_body.png"
    hero = None
    if hp.exists():
        hb = np.asarray(Image.open(hp).convert("RGBA"))[:, :16].copy()
        st = np.asarray(Image.open(hp.with_name("red_strip.png")).convert("RGBA"))[:, :16]
        m = st[..., 3] > 0
        hb[m] = st[m]
        hero = hb
    S, BG = 6, (104, 102, 110)
    items = [pair[0], pair[1], beam_mock(pair[1]), crawler] + ([hero] if hero is not None else [])
    total_w = sum(f.shape[1] * S + 30 for f in items) + 30
    img = Image.new("RGB", (total_w, H * S + 110), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "Scrap Rush · 第二关精英怪：放映机（6 倍；平时 / 放招 / 光柱示意 / 比例尺：爬虫、主角）",
           fill=(235, 232, 228), font=font)
    # 光柱示意在暗底上看
    x = 16
    base_y = img.size[1] - 20
    for i, f in enumerate(items):
        im = Image.fromarray(f).resize((f.shape[1] * S, f.shape[0] * S), Image.NEAREST)
        if i == 2:
            dark = Image.new("RGBA", im.size, (24, 22, 26, 255))
            dark.alpha_composite(im)
            im = dark
            img.paste(im, (x, base_y - im.size[1]))
        else:
            img.paste(im, (x, base_y - im.size[1]), im)
        x += im.size[0] + 30
    img.save(HERE / "projector_preview.png")

    # 动画逐帧放大（看片盘转、走路腿）
    frames = game_frames()
    s2 = 4
    fw, fh = frames[0].shape[1], frames[0].shape[0]
    sheet = Image.new("RGB", (4 * (fw * s2 + 12) + 12, 5 * (fh * s2 + 12) + 12), BG)
    for i, f in enumerate(frames):
        im = Image.fromarray(f).resize((fw * s2, fh * s2), Image.NEAREST)
        sheet.paste(im, (12 + (i % 4) * (fw * s2 + 12), 12 + (i // 4) * (fh * s2 + 12)), im)
    sheet.save(HERE / "projector_frames_preview.png")


# ---------------------------------------------------------------- 游戏帧
def game_frames():
    return [body(pose, ph) for pose in range(5) for ph in range(4)]


def trim_all(frames):
    al = np.zeros(frames[0].shape[:2], bool)
    for f in frames:
        al |= f[..., 3] > 0
    ys, xs = np.nonzero(al)
    assert ys.max() == H - 1, "地面要是最后一行"
    x0, x1, y0 = xs.min(), xs.max(), ys.min()
    # 宽度凑成偶数，脚底中点落在整格上
    if (x1 - x0 + 1) % 2:
        x0 -= 1
    return [f[y0:, x0:x1 + 1] for f in frames], (x0, y0)


def export():
    frames, (x0, y0) = trim_all(game_frames())
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w:(i + 1) * w] = f
    Image.fromarray(out).save(OUT / "projector.png")
    print(f"projector.png: {len(frames)} 帧，每帧 {w}x{h}")
    pts = {"红灯": LED, "镜片（平时）": (4, LENS_Y), "镜片（放光）": (3, LENS_Y),
           "身子左（镜头根）": (10, 18), "身子右（灯箱）": (41, 17), "上片盘顶": (24, 0),
           "底座左": (12, 48), "底座右": (44, 48)}
    for k, (px, py) in pts.items():
        print(f"  {k}: 帧内 ({px - x0}, {py - y0})，相对脚底中点 ({px - x0 - w // 2}, {py - y0 - h})")


if __name__ == "__main__":
    preview()
    export()
