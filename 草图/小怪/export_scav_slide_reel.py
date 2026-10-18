"""拾荒者、幻灯机、胶片盘的游戏用动画横条（草图在 small.py，这里只补游戏里要的帧）。

    python3 export_scav_slide_reel.py    # 输出到 oscar-rush/art/enemies/scavenger.png、slide_projector.png、film_reel.png

横排等宽帧，原图朝左，地面是最后一行。每帧左右留白，让身子落在帧的正中间
（EnemyBase 按帧宽的一半对齐脚底中点，朝右时整帧水平翻转）。
红色瞄准线、光弹、马灯都是脚本画的，不在贴图里。
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import small
from elites import G, RGB, legs  # small 已经把 精英怪/ 放进 sys.path

OUT = Path(__file__).resolve().parents[2] / "oscar-rush/art/enemies"


def over(base, top):
    """把 top 里不透明的像素盖到 base 上。"""
    out = base.copy()
    m = top[..., 3] > 0
    out[m] = top[m]
    return out


def clear(img, x0, y0, x1, y1):
    out = img.copy()
    out[y0:y1 + 1, x0:x1 + 1] = 0
    return out


def shift(img, dx):
    """整张图水平挪 dx 格（挪出去的丢掉）。"""
    out = np.zeros_like(img)
    w = img.shape[1]
    if dx >= 0:
        out[:, dx:] = img[:, :w - dx]
    else:
        out[:, :w + dx] = img[:, -dx:]
    return out


def strip(frames, pad_left=0, pad_right=0):
    h = frames[0].shape[0]
    w = frames[0].shape[1] + pad_left + pad_right
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w + pad_left:i * w + pad_left + f.shape[1]] = f
    return out, w


# ---------------------------------------------------------------- 拾荒者（草图 26×14，ox = 10，车斗 x 12～23）
# 帧：0 走 A（草图待机）、1 走 B（轮子转半圈）、2 预警（夹子举起来张开）、3 夹（草图 scavenger(1)）、
#     4 拖着灯跑 A（夹子翻到车斗上面按住灯座）、5 拖着灯跑 B
SCAV_OX = 10
SCAV_LED = (SCAV_OX + 3, 6)


def scav_cart(wheel_b=False):
    """没有夹子的推车。wheel_b：轮子上的亮点换到另一边，走起来像在转。"""
    ox = SCAV_OX
    img = clear(small.scavenger(0), 0, 0, ox + 1, 13)                 # 夹子都在车斗左边
    img = clear(img, ox + 2, 3, ox + 2, 3)
    if wheel_b:
        g = G(26, 14)
        for wx in (ox + 4, ox + 11):
            g.disk(wx, 12, 1.5, 3)
            g.pts([(wx, 11), (wx, 13)], 7)
        img = over(img, g.rgba())
    return img


def scav_claw_tucked():
    ox = SCAV_OX
    g = G(26, 14)
    g.path([(ox + 2, 5), (ox - 1, 3), (ox - 2, 5)], 5)
    g.pts([(ox - 3, 6), (ox - 1, 6)], 7)
    return g.rgba()


def scav_windup():
    """夹子往后上方举起来，爪子张得很开：0.4 秒的预警。"""
    ox = SCAV_OX
    g = G(26, 14)
    g.path([(ox + 2, 5), (ox + 1, 2), (ox - 1, 0)], 5)
    g.put(ox + 1, 2, 7)                                                 # 关节
    g.pts([(ox - 2, 0), (ox - 3, 1), (ox - 4, 2)], 7)                   # 下爪
    g.put(ox - 3, 0, 7)                                                 # 上爪
    g.pts([(ox, 1), (ox - 1, 2)], 8)                                    # 爪尖亮一下
    return over(scav_cart(), g.rgba())


def scav_carry(wheel_b):
    """夹子翻到车斗上面，爪子卡住马灯的灯座（马灯本身由脚本挂在车斗上方）。"""
    ox = SCAV_OX
    g = G(26, 14)
    g.path([(ox + 2, 5), (ox + 1, 3), (ox + 2, 1), (ox + 4, 1)], 5)
    g.put(ox + 1, 3, 7)
    g.pts([(ox + 4, 2), (ox + 4, 0), (ox + 5, 0)], 7)                   # 爪子扣住灯座左角
    return over(scav_cart(wheel_b), g.rgba())


def scav_frames():
    return [
        small.scavenger(0),
        over(scav_cart(True), scav_claw_tucked()),
        scav_windup(),
        small.scavenger(1),
        scav_carry(False),
        scav_carry(True),
    ]


# ---------------------------------------------------------------- 幻灯机（草图 34×13，ox = 16；只取 x ≥ 16 的机身，瞄准线脚本画）
# 帧：0 走 A（草图待机）、1 走 B（腿反过来）、2 瞄准（片盒推进去、散热罩亮）、3 开火（往后坐 1 格、镜头一圈白）
PROJ_OX = 16


def proj_body():
    return small.projector(0)[:, PROJ_OX:]


def proj_walk_b():
    ox = 0
    img = clear(proj_body(), 0, 10, 17, 12)
    g = G(18, 13)
    legs(g, [(ox + 5, 10), (ox + 13, 10)], 12, spread=-1)
    return over(img, g.rgba())


def proj_aim():
    ox = 0
    img = clear(proj_body(), ox + 16, 4, ox + 17, 7)                    # 片盒推进去 1 格
    g = G(18, 13)
    g.rect(ox + 16, 4, ox + 16, 7, 6)
    g.rect(ox + 16, 4, ox + 16, 4, 8)
    g.rect(ox + 6, 0, ox + 11, 0, 9)                                    # 散热罩亮起来（灯泡烧热了）
    g.pts([(ox + 1, 4), (ox + 1, 7)], 7)                                # 镜头筒边缘亮一点
    return over(img, g.rgba())


def proj_fire():
    ox = 0
    img = shift(proj_aim(), 1)                                          # 往后坐 1 格
    img = clear(img, 0, 10, 17, 12)
    img[10:13] = proj_body()[10:13]                                     # 腿不动，只有机身后坐
    g = G(18, 13)
    g.pts([(ox, 4), (ox, 7), (ox + 1, 3), (ox + 1, 8)], "S")            # 镜头口一圈闪光
    g.rect(ox + 1, 4, ox + 1, 7, 9)
    return over(img, g.rgba())


def proj_frames():
    return [proj_body(), proj_walk_b(), proj_aim(), proj_fire()]


# ---------------------------------------------------------------- 胶片盘（草图 22×13，盘心 (14, 6)，半径 6）
# 帧：0、1、2 滚动（三个孔各转 40°，往左滚是逆时针；后面拖的胶片尾巴一甩一甩）、3 没在滚（草图待机，落地前用）
#     4~7：0~3 的亮边层（不吃压暗，暗处也看得清）
REEL_C = (14, 6)


def reel_roll(k):
    cx, cy = REEL_C
    g = G(22, 13)
    g.disk(cx, cy, 6, 6)
    g.disk(cx, cy, 5, 4)
    g.disk(cx, cy, 4, "r1")
    rot = -k * 2 * math.pi / 9                                          # 三个孔 120° 一循环，三帧各 40°
    for i in range(3):                                                  # 孔一律 2×2，转到哪都一样大
        a = rot + i * 2 * math.pi / 3
        hx = round(cx + 2.8 * math.cos(a) - 0.5)
        hy = round(cy + 2.8 * math.sin(a) - 0.5)
        g.rect(hx, hy, hx + 1, hy + 1, 1)
    # 顶上的亮边不跟着转（是光照，不是盘上的花纹）
    g.pts([(cx - 3, cy - 5), (cx - 4, cy - 4), (cx - 5, cy - 3)], 8)
    g.disk(cx, cy, 0.7, 6)
    g.led(cx, cy)
    tails = [[(cx + 5, cy + 4), (cx + 7, cy + 6), (21, cy + 6)],
             [(cx + 5, cy + 4), (cx + 7, cy + 5), (21, cy + 4)],
             [(cx + 5, cy + 4), (cx + 7, cy + 6), (20, cy + 5), (21, cy + 6)]]
    g.path(tails[k], "r2")
    return g.rgba()


def reel_glow(body):
    """亮边层：脚本用不吃场景压暗的 Sprite 叠在盘子上，暗处也看得见轮廓和孔位。
    按本体的颜色挑像素：外圈一圈亮、左上的高光更亮、缠着的胶片微微发亮；孔、盘心、红灯留空，
    所以暗处看到的是一圈亮边里三个黑孔在转。"""
    cx, cy = REEL_C
    out = np.zeros_like(body)
    rim, hi, film = (110, 102, 94, 190), (168, 160, 151, 220), (112, 88, 72, 170)
    for y in range(body.shape[0]):
        for x in range(body.shape[1]):
            if body[y, x, 3] == 0:
                continue
            c = tuple(int(v) for v in body[y, x, :3])
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if c == RGB[8]:
                col = hi
            elif c == RGB[6] and d > 5.0:
                col = rim
            elif c in (RGB["r1"], RGB["r2"]):
                col = film
            else:
                continue
            # 风格检查器不收半透明：把亮边色按原来的透明度和本体那一格先混好，存成不透明
            a = col[3] / 255.0
            mix = [round(col[i] * a + int(body[y, x, i]) * (1.0 - a)) for i in range(3)]
            out[y, x] = (*mix, 255)
    return out


def reel_frames():
    """0~3 本体（同上），4~7 对应的亮边层。"""
    body = [reel_roll(0), reel_roll(1), reel_roll(2), small.reel(0)]
    return body + [reel_glow(b) for b in body]


def check_led(name, img, w, n, led):
    for i in range(n):
        x, y = led
        px = tuple(int(v) for v in img[y, i * w + x, :3])
        assert px == RGB["L"], (name, i, px)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    # 拾荒者：车斗中点 17.5，右边补 10 格 → 36 宽帧，车斗落在正中
    sc, scw = strip(scav_frames(), pad_right=10)
    Image.fromarray(sc).save(OUT / "scavenger.png")
    # 幻灯机：机身 18 宽，左右各补 1 格 → 20 宽帧（开火帧往后坐 1 格也放得下）
    pr, prw = strip(proj_frames(), pad_left=1, pad_right=1)
    Image.fromarray(pr).save(OUT / "slide_projector.png")
    proj_led = (1, 5)
    # 胶片盘：盘心 x = 14，右边补 6 格 → 28 宽帧
    rl, rlw = strip(reel_frames(), pad_right=6)
    Image.fromarray(rl).save(OUT / "film_reel.png")
    print("scavenger", sc.shape[1], "x", sc.shape[0], "帧宽", scw, "帧数 6", "红灯", SCAV_LED)
    print("slide_projector", pr.shape[1], "x", pr.shape[0], "帧宽", prw, "帧数 4", "红灯", proj_led)
    print("film_reel", rl.shape[1], "x", rl.shape[0], "帧宽", rlw, "帧数 8（4 本体 + 4 亮边）", "红灯", REEL_C)
    check_led("scavenger", sc, scw, 6, SCAV_LED)
    check_led("slide_projector", pr, prw, 3, proj_led)                 # 开火帧镜头往后坐了 1 格
    check_led("film_reel", rl, rlw, 4, REEL_C)
    # 放大预览（不进工程）：给了路径才画，python3 export_scav_slide_reel.py /tmp/preview.png
    if len(sys.argv) < 2:
        return
    S = 6
    prev = []
    for img in (sc, pr, rl):
        prev.append(Image.fromarray(img).resize((img.shape[1] * S, img.shape[0] * S), Image.NEAREST))
    W = max(p.size[0] for p in prev) + 20
    H = sum(p.size[1] + 20 for p in prev) + 10
    sheet = Image.new("RGBA", (W, H), (104, 102, 110, 255))
    y = 10
    for p in prev:
        sheet.paste(p, (10, y), p)
        y += p.size[1] + 20
    sheet.save(sys.argv[1])


if __name__ == "__main__":
    main()
