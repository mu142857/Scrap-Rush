"""第一印象改进示意图：标题、选武器、第一关开局。只是示意，不改游戏。
在 480×270 原生分辨率上改（像素感不丢），再放大 2 倍，左边"现在"、右边"改进示意"。
光照一律按 Oscar 的做法：一档一档切开的明暗（不是平滑渐变），灯是画面的焦点。

跑：python3 草图/立绘/第一印象_示意图.py
读：截图/夜间打磨/立绘/第一印象改进方案/first_{title,weapon,level1}.png
出：同一个文件夹下 改进示意_{1标题,2选武器,3第一关}.png
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DIR = ROOT / "截图/夜间打磨/立绘/第一印象改进方案"
FONT = ImageFont.truetype(str(ROOT / "oscar-rush/fonts/PixelFont.ttf"), 11)
WARM = (255, 211, 138)
NOTE = (120, 220, 255)


def native(name: str) -> np.ndarray:
    im = Image.open(DIR / name).convert("RGB")
    return np.asarray(im.resize((480, 270), Image.NEAREST)).astype(np.float32)


def light_pool(a: np.ndarray, cx, cy, radii, levels, warm=0.0, ry_scale=0.8, add=None):
    """以 (cx, cy) 为中心一圈一圈切明暗：radii 是各圈半径，levels 是每圈的亮度倍数（最后一个是圈外）。"""
    h, w = a.shape[:2]
    ys, xs = np.mgrid[0:h, 0:w]
    d = np.sqrt((xs - cx) ** 2 + ((ys - cy) / ry_scale) ** 2)
    k = np.full((h, w), levels[-1], np.float32)
    for r, lv in reversed(list(zip(radii, levels))):
        k[d <= r] = lv
    out = a * k[..., None]
    if add:
        # 每一圈直接叠一层暖光（加法），暗处也看得出灯照到的范围
        for r, amount in reversed(list(zip(radii, add))):
            ring = d <= r
            out[ring] = a[ring] * k[ring][:, None] + np.array([255, 190, 110]) * (amount / 255)
    if warm:
        inner = d <= radii[0]
        out[inner] = out[inner] * (1 - warm) + np.array([255, 196, 120]) * warm * (out[inner].mean(axis=1, keepdims=True) / 255)
    return np.clip(out, 0, 255)


def text_shadow(a: np.ndarray, box, is_text, shadow=(70, 34, 18), hi=(255, 240, 200)):
    """标题字：往右下错 1 格的暗色投影 + 每个字顶边一行亮色。"""
    x0, y0, x1, y1 = box
    sub = a[y0:y1, x0:x1]
    m = is_text(sub)
    sh = np.zeros_like(m)
    sh[1:, 1:] = m[:-1, :-1]
    sub[sh & ~m] = shadow
    top = m & ~np.vstack([np.zeros((1, m.shape[1]), bool), m[:-1]])
    sub[top] = hi
    a[y0:y1, x0:x1] = sub


def annotate(img: Image.Image, items):
    d = ImageDraw.Draw(img)
    for kind, *args in items:
        if kind == "box":
            (x0, y0, x1, y1), label, (lx, ly) = args
            d.rectangle([x0, y0, x1, y1], outline=NOTE)
            d.text((lx, ly), label, font=FONT, fill=NOTE)
        elif kind == "arrow":
            (x0, y0), (x1, y1) = args
            d.line([x0, y0, x1, y1], fill=NOTE)
            d.rectangle([x1 - 1, y1 - 1, x1 + 1, y1 + 1], fill=NOTE)
        elif kind == "text":
            (x, y), label = args
            d.text((x + 1, y + 1), label, font=FONT, fill=(0, 0, 0))
            d.text((x, y), label, font=FONT, fill=NOTE)


def pair(before: np.ndarray, after: np.ndarray, notes, title: str, out: str):
    a = Image.fromarray(before.astype(np.uint8))
    b = Image.fromarray(after.astype(np.uint8))
    annotate(b, notes)
    S = 2
    W, H = 480 * S, 270 * S
    sheet = Image.new("RGB", (W * 2 + 30, H + 40), (240, 240, 240))
    sheet.paste(a.resize((W, H), Image.NEAREST), (10, 30))
    sheet.paste(b.resize((W, H), Image.NEAREST), (W + 20, 30))
    d = ImageDraw.Draw(sheet)
    big = ImageFont.truetype(str(ROOT / "oscar-rush/fonts/PixelFont.ttf"), 22)
    d.text((14, 4), "现在", font=big, fill=(30, 30, 30))
    d.text((W + 24, 4), "改进示意：" + title, font=big, fill=(30, 30, 30))
    sheet.save(DIR / out)


def is_warm_text(sub):
    r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
    return (r > 200) & (g > 150) & (b < 170) & (r - b > 60)


# ---------------------------------------------------------------- 1 标题
t = native("first_title.png")
t2 = light_pool(t, 248, 216, [58, 104, 165], [1.15, 0.8, 0.52, 0.36], add=[34, 14, 4])
# 标题字、副标题、选中的"开始"留原来的亮度（它们是焦点，不跟着压暗）
for (y0, y1) in ((18, 52), (54, 70), (98, 128)):
    keep = t[y0:y1, 120:360].max(axis=2) > 120
    t2[y0:y1, 120:360][keep] = t[y0:y1, 120:360][keep]
# 没选中的菜单项再暗一档（示意"缩小、退后"）
t2[128:200, 175:305] *= 0.55
text_shadow(t2, (140, 18, 340, 52), is_warm_text)
pair(t, t2, [
    ("box", (138, 16, 342, 52), "① 标题字：暗投影", (348, 22)),
    ("text", (348, 34), "   + 顶边一行亮"),
    ("box", (175, 126, 305, 200), "③ 菜单缩小、没选中的再暗一档", (310, 150)),
    ("text", (300, 196), "② 马灯当光源：船员一圈亮"),
    ("text", (300, 208), "   往外三档暗"),
], "标题界面", "改进示意_1标题.png")

# ---------------------------------------------------------------- 2 选武器
w = native("first_weapon.png")
w2 = w.copy()
# 没选中的两张卡片暗两档（卡片在 x 172~456、y 47~219）
w2[47:220, 170:458] *= 0.55
# 选中卡片后面一圈马灯色的光（分档）
w2 = light_pool(w2, 92, 132, [70, 100, 130], [1.3, 1.12, 0.95, 0.75], warm=0.25, ry_scale=1.2)
# 选中卡片的图标放大 1.3 倍：先用卡片底色擦掉原图标，再贴大的
card_bg = w2[90, 30].copy()
bg0 = w[90, 30].copy()
w2[56:112, 66:124] = card_bg
icon = Image.fromarray(w[56:112, 66:124].astype(np.uint8))
big_icon = np.asarray(icon.resize((75, 72), Image.NEAREST)).astype(np.float32)
mask = np.abs(big_icon - bg0).sum(axis=2) > 24
region = w2[42:114, 55:130]
region[mask] = big_icon[mask]
w2[42:114, 55:130] = region
pair(w, w2, [
    ("box", (53, 40, 132, 115), "② 图标放大，名字往下挪", (14, 232)),
    ("box", (168, 45, 460, 222), "① 没选中的卡片暗两档", (300, 232)),
    ("text", (14, 244), "③ 选中卡片后面一圈马灯色的光"),
], "选武器界面", "改进示意_2选武器.png")

# ---------------------------------------------------------------- 3 第一关开局
l1 = native("first_level1.png")
# 远景压暗偏冷：整张先压暗、加一点蓝
l2 = l1 * np.array([0.74, 0.78, 0.92])
# 马灯的光圈放大，分三档（里圈明显亮、偏暖）
l2 = light_pool(l2, 180, 186, [34, 62, 100], [1.2, 1.05, 0.9, 0.7], add=[46, 24, 10])
# 提示牌退后一层：暗一档（示意"缩小、往下放"）
l2[96:152, 250:336] *= 0.55
# HUD 保持原样
l2[0:46] = l1[0:46]
l2[262:270] = l1[262:270]
pair(l1, l2, [
    ("text", (120, 222), "① 马灯光圈放大、分三档切"),
    ("box", (250, 96, 336, 152), "② 提示牌缩小、往下放、暗一档", (250, 156)),
    ("arrow", (196, 204), (300, 204)),
    ("text", (205, 208), "镜头往前多留 1/3"),
    ("text", (240, 52), "③ 远景压暗偏冷，近处偏暖"),
], "第一关开局", "改进示意_3第一关.png")
print("ok")
