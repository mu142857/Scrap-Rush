"""布谷鸟钟、缝纫机、收银机的游戏用动画横条（草图在 elites.py，这里只补游戏里要的帧，不改 elites.py）。

    python3 export_clock_sew_cash.py             # 输出到 oscar-rush/art/enemies/cuckoo.png、sewing.png、register.png
    python3 export_clock_sew_cash.py <目录>      # 另外在 <目录> 里放一张 6 倍放大的预览图

横排等宽帧，原图朝左，地面是最后一行。帧宽都是奇数，身子的中线落在第 w//2 列
（EnemyBase 按帧宽的一半对齐脚底中点，朝右时整帧水平翻转，奇数宽翻过来中线不动）。
放招时伸出去的东西（钟摆横扫、钱箱抽屉）也要装进帧里，所以帧比身子宽不少。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import elites
from elites import G

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


def pad(img, left, right):
    h, w = img.shape[:2]
    out = np.zeros((h, w + left + right, 4), np.uint8)
    out[:, left:left + w] = img
    return out


def with_legs(fn, pose, mode):
    """临时换掉 elites.legs 再画：mode = "none" 不画腿，"flip" 膝盖朝另一边（走路第二帧）。"""
    orig = elites.legs

    def patched(g, roots, ground, spread=2, col=4, knee=5):
        if mode == "flip":
            orig(g, roots, ground, -spread, col, knee)

    elites.legs = patched
    try:
        return fn(pose)
    finally:
        elites.legs = orig


def strip(frames):
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        assert f.shape[:2] == (h, w), (f.shape, (h, w))
        out[:, i * w:(i + 1) * w] = f
    return out, w


# ---------------------------------------------------------------- 布谷鸟钟（草图 38×40，ox = 12）
# 帧宽 53：钟摆（草图 x=24）落在第 26 列，左边补 2 格、右边补 13 格。
# 帧：0、1 走路，2 预警（门里亮起铁鸟的红眼），3、4 门开着、钟摆左右晃（弱点窗口），
#     5 横扫前摇（钟摆往后拉），6 横扫（钟摆伸长甩到身前）
CK_OX, CK_H, CK_L, CK_R = 12, 40, 2, 13
CK_LED = (CK_OX + 12 + CK_L, 21)


def ck_x(x):
    return x + CK_L


def ck_body():
    """不带腿、不带钟摆的钟。"""
    img = with_legs(elites.cuckoo, 0, "none")
    img = clear(img, CK_OX + 10, 28, CK_OX + 14, 37)
    return pad(img, CK_L, CK_R)


def ck_pendulum(g, ex, ey, bob=1.8, rod=5):
    """钟摆：从钟底（草图 x=24, y=28）到 (ex, ey) 的杆，末端一个锈色坠子。"""
    px, py = ck_x(CK_OX + 12), 28
    g.line(px, py, px + ex, py + ey, rod)
    n = max(abs(ex), abs(ey))
    bx, by = px + ex * (n + 1.5) / n, py + ey * (n + 1.5) / n
    g.disk(bx, by, bob, "r3")
    g.pts([(round(bx) - 1, round(by - bob)), (round(bx), round(by - bob))], 8)


def ck_legs(g, flip=False):
    s = -1 if flip else 1
    elites.legs(g, [(ck_x(CK_OX + 5), 28), (ck_x(CK_OX + 20), 28)], CK_H - 1, spread=3 * s)
    elites.legs(g, [(ck_x(CK_OX + 9), 28), (ck_x(CK_OX + 16), 28)], CK_H - 1, spread=1 * s, col=3, knee=4)


def ck_frame(swing=(0, 5), flip=False, door=None, sweep=False):
    w = ck_body().shape[1]
    img = ck_body()
    g = G(w, CK_H)
    if not sweep:
        ck_pendulum(g, *swing)
    ck_legs(g, flip)
    ox = ck_x(CK_OX)
    if door == "warn":                                                    # 门里亮起铁鸟的红眼，门框发亮
        g.put(ox + 12, 13, "L")
        g.pts([(ox + 10, y) for y in range(12, 16)] + [(ox + 11, 11), (ox + 14, 11)], 8)
    elif door == "open":                                                  # 门板往右甩开，弹簧还伸在外面
        g.pts([(ox + 15, 12), (ox + 16, 12), (ox + 15, 13), (ox + 16, 13)], 8)
        g.path([(ox + 11, 13), (ox + 9, 11), (ox + 8, 14), (ox + 6, 12)], 7)
    img = over(img, g.rgba())
    if sweep:                                                             # 钟摆最后画，盖在腿上面
        g2 = G(w, CK_H)
        ck_pendulum(g2, -15, 3, bob=2.2)
        for x, y in [(ox + 3, 37), (ox + 6, 38), (ox + 9, 38), (ox + 1, 36), (ox - 1, 35)]:
            g2.put(x, y, "S")                                             # 甩过来的那道弧
        img = over(img, g2.rgba())
    return img


def cuckoo_frames():
    return [
        ck_frame((0, 5)),
        ck_frame((1, 5), flip=True),
        ck_frame((0, 5), door="warn"),
        ck_frame((-3, 5), door="open"),
        ck_frame((3, 5), door="open"),
        ck_frame((5, 3)),
        ck_frame(sweep=True),
    ]


# ---------------------------------------------------------------- 缝纫机（草图 42×28）
# 帧宽 43：中线在第 21 列，右边补 1 格。
# 帧：0、1 走路（手轮转、踏板晃），2 针抬起来（扎之前），3 针扎到地上，4 抛线轴（线轴没了），
#     5 抛线轴前摇（线轴发亮，和 0 来回切）
SW_H, SW_R = 28, 1
SW_LED = (6, 6)
SW_NEEDLE = (8, 27)
SW_SPOOL = (20, 0)


def sw_wheel(img, turned):
    """手轮上那四个刻痕：turned 时转 45°。"""
    if not turned:
        return img
    g = G(img.shape[1], SW_H)
    g.pts([(36, 5), (37, 12), (33, 8), (40, 9)], 6)
    g.pts([(39, 6), (34, 11), (34, 6), (39, 11)], 5)
    return over(img, g.rgba())


def sw_frame(pose=0, turned=False, pedal=False, needle_up=False, spool="on"):
    img = elites.sewing(pose)
    if pose == 1:                                                         # 地上那道线由脚本画
        for x in range(0, 8, 2):
            img[SW_H - 1, x] = 0
    img = pad(img, 0, SW_R)
    img = sw_wheel(img, turned)
    g = G(img.shape[1], SW_H)
    if pedal:
        img = clear(img, 14, 23, 25, 23)
        g.line(14, 22, 25, 23, 5)
    if needle_up:
        img = clear(img, 8, 14, 8, 17)
        g.line(8, 13, 8, 15, 9)
        g.rect(5, 14, 10, 14, 7)                                          # 压脚抬起来，亮一档
        g.put(8, 14, 9)
    if spool == "off":
        img = clear(img, 19, 0, 21, 1)
        g.put(20, 1, 7)
    elif spool == "glow":
        g.rect(19, 0, 21, 1, "r3")
        g.pts([(19, 0), (21, 1)], 9)
    return over(img, g.rgba())


def sewing_frames():
    return [
        sw_frame(),
        sw_frame(turned=True, pedal=True),
        sw_frame(needle_up=True),
        sw_frame(pose=1),
        sw_frame(turned=True, spool="off"),
        sw_frame(spool="glow"),
    ]


# ---------------------------------------------------------------- 收银机（草图 40×32，ox = 9）
# 帧宽 53：中线（草图 x=23）在第 26 列，左边补 3 格（抽屉伸到草图 x=-3）、右边补 10 格。
# 帧：0、1 走路，2 咬之前抽屉松开 3 格（预警），3 抽屉出来 8 格，4 抽屉全出来 14 格（咬），
#     5 抛硬币（摇把拉下来，顶上弹起一块牌子）
RG_OX, RG_H, RG_L, RG_R = 9, 32, 3, 10
RG_LED = (RG_OX + 15 + RG_L, 4)


def rg_x(x):
    return x + RG_L


def rg_open_body():
    """钱箱拉开、抽屉不画的机身（不带腿）：用草图的放招姿势，把伸出来的抽屉擦掉，机身里补成黑洞。"""
    ox = RG_OX
    img = with_legs(elites.register, 1, "none")
    img = clear(img, 0, 16, ox + 1, 24)
    img = clear(img, ox + 2, 24, ox + 4, 24)
    img[19:24, ox + 2:ox + 5] = 0
    g = G(img.shape[1], RG_H)
    g.rect(ox + 2, 19, ox + 4, 23, 0)
    return pad(over(img, g.rgba()), RG_L, RG_R)


def rg_tray(g, out):
    """抽屉：前沿比机身前脸（草图 x=11）多出 out 格，长 14，上面一排分隔板像牙。"""
    f = rg_x(RG_OX + 2 - out)
    g.box(f, 20, f + 13, 24, base=5, top=7, left=7, right=5, bottom=3)
    g.rect(f, 20, f + 11, 20, 1)
    for x in range(f, f + 13, 3):
        g.put(x, 19, 8)
        g.put(x, 20, 7)
    g.pts([(f + 2, 22), (f + 3, 22), (f + 4, 22)], 9)


def rg_legs(g, flip=False):
    ox = RG_OX
    roots = [(rg_x(ox + 4), 24), (rg_x(ox + 11), 24), (rg_x(ox + 17), 24), (rg_x(ox + 24), 24)]
    elites.legs(g, roots, RG_H - 1, spread=-2 if flip else 2)


def rg_bite(out):
    img = rg_open_body()
    g = G(img.shape[1], RG_H)
    rg_tray(g, out)
    rg_legs(g)
    return over(img, g.rgba())


def rg_coin_toss():
    ox = RG_OX
    img = pad(elites.register(0), RG_L, RG_R)
    img = clear(img, rg_x(ox + 27), 12, rg_x(ox + 30), 17)                # 擦掉原来的摇把
    g = G(img.shape[1], RG_H)
    g.line(rg_x(ox + 27), 14, rg_x(ox + 28), 18, 6)
    g.pts([(rg_x(ox + 28), 19), (rg_x(ox + 29), 19)], 8)
    g.rect(rg_x(ox + 12), 0, rg_x(ox + 14), 0, 9)                          # 弹起来的价签牌
    return over(img, g.rgba())


def register_frames():
    return [
        pad(elites.register(0), RG_L, RG_R),
        pad(with_legs(elites.register, 0, "flip"), RG_L, RG_R),
        rg_bite(3),                   # 前沿在草图 x=8：只松开 3 格
        rg_bite(8),
        rg_bite(14),
        rg_coin_toss(),
    ]


# ----------------------------------------------------------------
def preview(path, sheets):
    S, BG, GAP = 6, (104, 102, 110), 12
    w = max(s.shape[1] for s, _ in sheets) * S
    h = sum(s.shape[0] * S + GAP for s, _ in sheets) + GAP
    img = Image.new("RGB", (w + 2 * GAP, h), BG)
    y = GAP
    for s, fw in sheets:
        im = Image.fromarray(s).resize((s.shape[1] * S, s.shape[0] * S), Image.NEAREST)
        img.paste(im, (GAP, y), im)
        for i in range(s.shape[1] // fw + 1):                            # 帧的分界线和中线
            for yy in range(y, y + s.shape[0] * S, 2):
                img.putpixel((GAP + i * fw * S, yy), (140, 140, 150))
                if i < s.shape[1] // fw:
                    img.putpixel((GAP + (i * fw + fw // 2) * S + S // 2, yy), (90, 150, 90))
        y += s.shape[0] * S + GAP
    img.save(path)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    sheets = []
    for name, frames, leds in [("cuckoo", cuckoo_frames(), CK_LED), ("sewing", sewing_frames(), SW_LED),
                               ("register", register_frames(), RG_LED)]:
        sh, fw = strip(frames)
        Image.fromarray(sh).save(OUT / f"{name}.png")
        sheets.append((sh, fw))
        n = sh.shape[1] // fw
        # 核对：红灯那一格每帧都是红色，帧宽是奇数
        bad = [i for i in range(n) if tuple(sh[leds[1], i * fw + leds[0], :3]) != elites.RGB["L"]]
        print(f"{name}: {sh.shape[1]}x{sh.shape[0]} 帧宽 {fw} 帧数 {n} 红灯 {leds}",
              "OK" if not bad and fw % 2 == 1 else f"红灯不对的帧 {bad} / 帧宽 {fw}")
    if len(sys.argv) > 1:
        preview(Path(sys.argv[1]) / "preview_clock_sew_cash.png", sheets)


if __name__ == "__main__":
    main()
