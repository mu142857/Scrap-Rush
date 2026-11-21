"""《情绪稳定》体检报告特写：480×270 像素，放大 3 倍出 1440×810，用游戏的像素字体（fonts/PixelFont.ttf）。
第一页能看清，"情绪稳定"被红笔圈起来；第二页的字只画成看不清的灰块（内容不展示）。

python3 report.py 输出目录
"""
import sys, os, math, subprocess
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, "..", "fonts", "PixelFont.ttf")
W, H, S = 480, 270, 3
FPS = 30

DESK = (34, 26, 24)
DESK_L = (46, 34, 30)
PAPER = (236, 232, 222)
PAPER_SH = (220, 214, 202)
INK = (52, 50, 58)
INK_L = (120, 116, 112)
RED = (196, 52, 44)

PX = (100, 8, 380, 300)     # 纸：左、上、右、下（下边出画）


def font(size):
    return ImageFont.truetype(FONT, size)


def desk():
    im = Image.new("RGB", (W, H), DESK)
    d = ImageDraw.Draw(im)
    for y in range(0, H, 9):   # 木纹：几条连续的长横线（不是虚线）
        d.line([(0, y + (y * 7) % 5), (W, y + (y * 7) % 5)], fill=DESK_L)
    return im


def page1(circle=1.0):
    """第一页。circle：红圈画了多少（0~1）"""
    x0, y0, x1, y1 = PX
    im = Image.new("RGBA", (x1 - x0, y1 - y0), PAPER + (255,))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    big, small = font(24), font(12)
    d.text((86, 14), "体检报告", font=big, fill=INK)
    d.line([(16, 44), (x1 - x0 - 16, 44)], fill=INK)
    rows = [("姓名", "＊＊"), ("身高", "正常"), ("体重", "正常"), ("血压", "正常"),
            ("心率", "正常"), ("视力", "正常"), ("睡眠", "良好")]
    y = 56
    for k, v in rows:
        d.text((24, y), k, font=small, fill=INK_L)
        d.text((80, y), v, font=small, fill=INK)
        y += 18
    d.line([(16, y + 2), (x1 - x0 - 16, y + 2)], fill=INK_L)
    y += 12
    d.text((24, y), "结论", font=small, fill=INK_L)
    ty = y + 18
    d.text((48, ty), "情绪稳定", font=big, fill=INK)
    bx0, by0, bx1, by1 = d.textbbox((48, ty), "情绪稳定", font=big)
    d.text((x1 - x0 - 110, y1 - y0 - 40), "第 1 页 / 共 2 页", font=small, fill=INK_L)
    if circle > 0:
        draw_circle(d, (bx0 + bx1) // 2, (by0 + by1) // 2 + 1, (bx1 - bx0) // 2 + 14, (by1 - by0) // 2 + 9, circle)
    return im


def draw_circle(d, cx, cy, rx, ry, amount):
    """手画的红圈：从左上起笔，顺时针多绕一点、首尾错开，2 像素粗"""
    total = 2 * math.pi * 1.12
    n = int(220 * amount)
    pts = []
    for i in range(n + 1):
        a = -2.4 + total * i / 220
        wob = 1.0 + 0.06 * math.sin(a * 3.0) + 0.04 * (i / 220)
        pts.append((round(cx + math.cos(a) * rx * wob), round(cy + math.sin(a) * ry * wob)))
    for (x, y) in pts:
        d.rectangle([x, y, x + 1, y + 1], fill=RED)


def page2():
    """第二页：字只是灰块，看不清写了什么"""
    x0, y0, x1, y1 = PX
    im = Image.new("RGBA", (x1 - x0, y1 - y0), PAPER + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle([80, 16, 200, 34], fill=PAPER_SH)
    d.line([(16, 44), (x1 - x0 - 16, 44)], fill=PAPER_SH)
    y = 58
    for k in range(9):
        w = [180, 210, 150, 200, 120, 220, 170, 90, 200][k]
        d.rectangle([24, y, 24 + w, y + 7], fill=PAPER_SH)
        y += 18
    return im


def shadow(im, x, y, w, h):
    d = ImageDraw.Draw(im)
    d.rectangle([x + 4, y + 4, x + w + 4, y + h + 4], fill=(22, 16, 16))


def compose(top, under=None, flip=0.0, offset=(0, 0)):
    """top 是上面那页；flip 0~1：上面那页从下往上翻起来（钉在顶边），露出 under"""
    im = desk()
    x0, y0, x1, y1 = PX
    ox, oy = offset
    w, h = x1 - x0, y1 - y0
    shadow(im, x0 + ox, y0 + oy, w, h)
    if under is not None:
        im.paste(under.convert("RGB"), (x0 + ox, y0 + oy))
    if flip < 1.0:
        hh = max(1, int(h * (1.0 - flip)))
        if flip == 0:
            im.paste(top.convert("RGB"), (x0 + ox, y0 + oy))
        else:
            # 翻起来的那页：竖着压扁、背面一点阴影
            part = top.resize((w, hh), Image.NEAREST).convert("RGB")
            im.paste(part, (x0 + ox, y0 + oy))
            d = ImageDraw.Draw(im)
            d.line([(x0 + ox, y0 + oy + hh), (x0 + ox + w, y0 + oy + hh)], fill=PAPER_SH)
    else:
        d = ImageDraw.Draw(im)
    # 顶边订书钉
    d = ImageDraw.Draw(im)
    d.rectangle([x0 + ox + 12, y0 + oy + 4, x0 + ox + 20, y0 + oy + 5], fill=(150, 150, 160))
    return im.resize((W * S, H * S), Image.NEAREST)


def ease(t):
    return t * t * (3 - 2 * t)


def write(frames_fn, secs, path):
    tmp = path + ".frames"
    os.makedirs(tmp, exist_ok=True)
    n = int(secs * FPS)
    last_key, last = None, None
    for i in range(n):
        key, fn = frames_fn(i / FPS)
        if key != last_key:
            last = fn()
            last_key = key
        last.save(os.path.join(tmp, "%05d.png" % i))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", os.path.join(tmp, "%05d.png"),
                    "-c:v", "libx264", "-crf", "12", "-pix_fmt", "yuv420p", path], check=True)
    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    p2 = page2()
    # 静帧：圈好的第一页、没圈的第一页
    compose(page1(1.0), p2).save(os.path.join(out, "01_报告第一页_情绪稳定已圈.png"))
    compose(page1(0.0), p2).save(os.path.join(out, "01_报告第一页_未圈.png"))

    # 开场：第一页，2 秒后红圈一笔画上，然后一直停着（台词约 10 秒 → 30 秒）
    def opening(t):
        c = min(1.0, max(0.0, (t - 2.0) / 1.2))
        k = int(c * 60)
        return k, lambda: compose(page1(k / 60), p2)
    write(opening, 30.0, os.path.join(out, "01_开场_报告第一页_红圈画上.mp4"))

    # 结尾：第一页 → 翻到第二页（钉在顶边往上翻）→ 第二页往下递过来（台词约 4 秒 → 15 秒）
    def to_page2(t):
        if t < 2.0:
            return ("a",), lambda: compose(page1(1.0), p2)
        if t < 2.8:
            f = round(ease((t - 2.0) / 0.8) * 24) / 24
            return ("f", f), lambda: compose(page1(1.0), p2, flip=f)
        if t < 4.0:
            return ("b",), lambda: compose(page1(1.0), p2, flip=1.0)
        if t < 4.8:
            o = round(ease((t - 4.0) / 0.8) * 30)
            return ("o", o), lambda: compose(page1(1.0), p2, flip=1.0, offset=(0, o))
        return ("c",), lambda: compose(page1(1.0), p2, flip=1.0, offset=(0, 30))
    write(to_page2, 15.0, os.path.join(out, "40_结尾_医生翻到第二页递回来.mp4"))

    # 结尾：主角停一下，把纸翻回第一页（台词约 2 秒 → 10 秒）
    def back_to_1(t):
        if t < 2.5:
            return ("a",), lambda: compose(page1(1.0), p2, flip=1.0, offset=(0, 30))
        if t < 3.3:
            f = round((1 - ease((t - 2.5) / 0.8)) * 24) / 24
            return ("f", f), lambda: compose(page1(1.0), p2, flip=f, offset=(0, 30))
        return ("b",), lambda: compose(page1(1.0), p2, offset=(0, 30))
    write(back_to_1, 10.0, os.path.join(out, "42_结尾_主角翻回第一页.mp4"))
