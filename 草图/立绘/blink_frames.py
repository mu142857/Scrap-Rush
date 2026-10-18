"""对话框立绘的眨眼帧：在原图上只改眼睛那几格，别的像素一个不动。
红衣：两只眼换成肤色，画一道往下弯的闭眼线（‿），外眼角留一根睫毛。
恐龙：金色的眼睛换成绿色眼皮，沿眼睛下沿画一道深绿的缝。
机器人的眨眼帧是表盘指针甩一下，由 robot_portrait.py --frame blink 出。

跑：python3 草图/立绘/blink_frames.py
出：oscar-rush/art/chars/red_portrait_blink.png、dino_portrait_blink.png
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
CHARS = ROOT / "oscar-rush/art/chars"


def red() -> None:
    im = Image.open(CHARS / "red_portrait.png").convert("RGBA")
    px = im.load()
    SKIN = (255, 224, 203, 255)
    LASH = (92, 36, 32, 255)
    DARK = (90, 30, 28, 255)
    # (x0, x1, 外眼角在哪边)
    for x0, x1, outer in ((35, 43, -1), (50, 58, 1)):
        for y in range(32, 37):
            for x in range(x0, x1 + 1):
                px[x, y] = SKIN
        for x in range(x0 + 1, x1):
            px[x, 35] = LASH
        px[x0, 34] = LASH
        px[x1, 34] = LASH
        ox = x0 if outer < 0 else x1
        px[ox + outer, 33] = DARK
    im.save(CHARS / "red_portrait_blink.png")


def dino() -> None:
    im = Image.open(CHARS / "dino_portrait.png").convert("RGBA")
    px = im.load()
    EYE = {(165, 97, 22), (217, 152, 0), (82, 48, 0), (253, 194, 58), (254, 248, 144)}
    LID = (73, 131, 91, 255)
    LID_LIGHT = (104, 159, 102, 255)
    SLIT = (2, 72, 48, 255)
    SHADE = (32, 96, 72, 255)
    # 只按原来眼睛的像素算每一列的上沿、下沿，眼睛外面一格都不动
    top, bottom, eye = {}, {}, set()
    for x in range(28, 54):
        for y in range(14, 34):
            if px[x, y][:3] in EYE:
                eye.add((x, y))
                top.setdefault(x, y)
                bottom[x] = y
    # 眼皮是鼓起来的：上半截受光亮一档，往下暗，最下沿是闭眼的缝
    for x, yb in bottom.items():
        h = max(yb - top[x], 1)
        for y in range(top[x], yb + 1):
            if (x, y) not in eye:
                continue
            t = (y - top[x]) / h
            px[x, y] = LID_LIGHT if t < 0.4 else (LID if t < 0.8 else SHADE)
        px[x, yb] = SLIT
    im.save(CHARS / "dino_portrait_blink.png")


red()
dino()
print("ok")
