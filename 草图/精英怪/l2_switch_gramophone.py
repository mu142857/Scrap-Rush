"""第二关（"声音"）的两个精英怪：总机台（Switchboard）、留声机（Gramophone）。照 elites.py 的画法（Oscar 的爬虫）。

    python3 l2_switch_gramophone.py      # 草图预览 + 游戏用横条

画法和第一关一样：暖调深灰一个色相，亮框 + 暗芯，光从上面来（上边、左边亮一档），不描边；
腿是几根细线；一只红色指示灯当眼睛。全部朝左，地面是画布最后一行。

输出：
- 本文件夹 l2_switch_gramophone_preview.png：6 倍放大。每只两行：上面是待机 / 放招两格 + 比例尺（爬虫、主角），
  下面是游戏里的全部动画帧。
- oscar-rush/art/enemies/switchboard.png、gramophone.png：横排等宽帧，所有帧同一个外框，身子在帧正中。

switchboard.png 6 帧：0、1 走（垂着的线晃）；2 插线预警（最左边那根线甩到头顶抡）；
                     3 插线（那根线甩出去了，板上的灯全亮）；4 拔线预警（板上两根跳线被往下拽紧）；
                     5 拔线（两根跳线拔掉了，空插孔冒火花）
gramophone.png  6 帧：0、1 走（唱片转，高光换位置）；2 横扫预警（唱臂抬起来）；
                     3 横扫（唱臂甩到前面朝下，游戏里从臂尖往地上画伸长的唱臂）；
                     4 声波预警（喇叭口一圈亮起来）；5 声波（喇叭口张大，往外冒声纹）
运行时打印每只的帧尺寸和要写进脚本的像素位置（红灯、线头、臂尖、喇叭口）。
"""
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from elites import G, legs

HERE = Path(__file__).resolve().parent
GAME = HERE.parents[1] / "oscar-rush/art/enemies"


def bezier(g, p0, p1, p2, c, n=24):
    """二次贝塞尔：p1 是控制点。整像素，不抗锯齿。"""
    pts = []
    for i in range(n + 1):
        t = i / n
        x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
        y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        pts.append((round(x), round(y)))
    g.path(pts, c)


def ellipse(g, cx, cy, rx, ry, c):
    for y in range(g.h):
        for x in range(g.w):
            if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                g.put(x, y, c)


# ---------------------------------------------------------------- 1. 总机台
SW_W, SW_H = 48, 48
SW_OX = 2                                   # 整体往右挪，左边留给甩起来的线
# 插孔：5 列 4 行；(x, y) 是插孔上面那颗小灯的位置，孔在它下面两格
SW_COLS = [14, 19, 24, 29, 34]
SW_ROWS = [8, 12, 16, 20]
# 两根跳线：(从哪个孔, 到哪个孔, 往下垂多少)
SW_PATCH = [((19, 12), (29, 16), 9), ((24, 8), (34, 20), 6)]
# 板子底下垂着的线：(挂在架子哪一格, 垂多长)；第 0 根是插线时甩出去的那根
SW_HANG = [(6, 8), (9, 6), (40, 7), (43, 5)]
SW_SWAY = [[0, 1, 0, -1], [1, 0, -1, 0]]
SW_SHELF_Y = 31


def sw_jack(x, y):
    return x + SW_OX, y + 2


def switchboard(pose="idle", phase=0):
    """pose：idle / warn_plug / cast_plug / warn_pull / pull。phase 0、1 是走路两帧（线晃、腿换）。"""
    g = G(SW_W, SW_H)
    o = SW_OX
    gy = SW_H - 1
    lit = pose in ("cast_plug", "warn_plug")
    # 顶冠：两层台阶，顶边最亮
    g.rect(o + 11, 1, o + 38, 1, 7)
    g.rect(o + 9, 2, o + 40, 3, 8)
    g.rect(o + 9, 2, o + 40, 2, 9)
    # 柜身：亮框暗芯
    g.box(o + 10, 4, o + 39, 30, base=3, top=6, left=7, right=5, bottom=2)
    # 插孔板：凹进去，上沿在阴影里
    g.rect(o + 12, 6, o + 37, 24, 1)
    g.rect(o + 12, 6, o + 37, 6, 0)
    g.rect(o + 12, 24, o + 37, 24, 3)                                   # 下沿受光
    rng = np.random.default_rng(3)
    for ry, y in enumerate(SW_ROWS):
        for cx_, x in enumerate(SW_COLS):
            on = lit and rng.random() < 0.6
            g.rect(o + x, y, o + x + 1, y, 9 if on else 4)                # 小灯
            g.rect(o + x, y + 2, o + x + 1, y + 2, 0)                    # 孔
            g.rect(o + x, y + 3, o + x + 1, y + 3, 4)                    # 孔下沿受光
    g.led(o + 14, 8, 2)                                                 # 左上角那颗是红灯：眼睛
    # 铜铭牌
    g.rect(o + 20, 26, o + 29, 27, "r2")
    g.rect(o + 20, 26, o + 29, 26, "r3")
    # 跳线：从一个孔垂下来再插进另一个孔
    for i, (a, b, depth) in enumerate(SW_PATCH):
        pa, pb = sw_jack(*a), sw_jack(*b)
        if pose == "pull":
            continue                                                    # 拔掉了，孔空着
        if pose == "warn_pull":
            # 往下拽紧：线绷直到架子左前方，插头拔出来一半
            anchor = (o + 2 + i * 3, SW_SHELF_Y - 1)
            for p in (pa, pb):
                g.line(p[0], p[1] + 1, anchor[0], anchor[1], 6)
                g.rect(p[0], p[1] - 1, p[0] + 1, p[1] - 1, 1)             # 孔口
                g.rect(p[0], p[1], p[0] + 1, p[1], 9)                    # 插头被拽出来一截
            continue
        mid = ((pa[0] + pb[0]) / 2, max(pa[1], pb[1]) + depth)
        bezier(g, (pa[0], pa[1] + 1), mid, (pb[0], pb[1] + 1), 6)
        for p in (pa, pb):
            g.rect(p[0], p[1], p[0] + 1, p[1], 8)                        # 插头
            g.put(p[0], p[1] + 1, 7)
    if pose == "pull":
        # 空孔冒火花
        for a, b, _ in SW_PATCH:
            for p in (sw_jack(*a), sw_jack(*b)):
                g.pts([(p[0] - 1, p[1] - 1), (p[0] + 2, p[1] + 1), (p[0], p[1] + 2)], "S")
    # 前伸的桌板（键架）
    g.box(o + 2, SW_SHELF_Y, o + 44, SW_SHELF_Y + 2, base=5, top=9, left=7, right=5, bottom=3)
    for x in range(o + 13, o + 38, 4):                                  # 架上一排立着的应答插头
        g.put(x, 29, 9)
        g.put(x, 30, 7)
    # 键架下面的柜子
    g.rect(o + 10, SW_SHELF_Y + 3, o + 39, SW_SHELF_Y + 3, 0)            # 桌板下的影子
    g.box(o + 11, 35, o + 38, 39, base=3, top=1, left=5, right=4, bottom=2)
    g.pts([(o + 18, 37), (o + 19, 37), (o + 30, 37), (o + 31, 37)], 7)  # 抽屉把手
    # 鹅颈话筒：从柜子左上角伸出来，喇叭口朝左，像一张嘴
    g.path([(o + 10, 13), (o + 7, 13), (o + 5, 11), (o + 4, 9)], 6)
    g.path([(o + 10, 14), (o + 7, 14)], 4)
    g.poly([(o - 2, 4), (o + 3, 6), (o + 3, 9), (o - 2, 11)], 5)
    g.path([(o - 2, 4), (o + 3, 6)], 9)
    g.path([(o - 2, 11), (o + 3, 9)], 3)
    g.rect(o - 2, 5, o - 2, 10, 1)                                      # 话筒口
    g.put(o + 3, 7, 7)
    # 垂着的线（带插头）
    sway = SW_SWAY[phase % 2]
    for i, (x, ln) in enumerate(SW_HANG):
        x += o
        top = SW_SHELF_Y + 3
        if i == 0 and pose in ("warn_plug", "cast_plug"):
            if pose == "warn_plug":
                # 甩到头顶抡一圈，插头朝前
                g.path([(x, top), (x - 3, top - 3), (x - 4, top - 9), (x - 3, top - 14), (x, top - 17)], 6)
                g.pts([(x + 1, top - 18), (x + 2, top - 18)], 7)
                g.put(x + 3, top - 18, 9)
                g.put(x + 1, top - 19, "r3")
            continue                                                    # 甩出去了：游戏里从架子左下角画到落点
        end = (x + sway[i], top + ln)
        bezier(g, (x, top), (x, top + ln * 0.6), end, 6 if i in (0, 2) else 5, n=12)
        ex, ey = end
        g.put(ex, ey + 1, "r3")                                         # 插头：铜套、壳、尖
        g.put(ex, ey + 2, 7)
        g.put(ex, ey + 3, 9)
    # 腿：外面两条亮，里面两条暗一档（在后面）
    out_spread, in_spread = [(3, 1), (2, 2)][phase % 2]
    legs(g, [(o + 13, 40), (o + 36, 40)], gy, spread=out_spread)
    legs(g, [(o + 20, 40), (o + 29, 40)], gy, spread=in_spread, col=3, knee=4)
    return g


# ---------------------------------------------------------------- 2. 留声机
GR_W, GR_H = 56, 46
GR_OX = 5
# 喇叭口：椭圆中心、半径
GR_MOUTH = (9, 11, 4.0, 11.0)
GR_PIVOT = (46, 18)


def horn(g, o, flare=0, bright=False):
    """牵牛花喇叭：从柜子后面的弯管升起来，往左越张越大，口朝左。"""
    mcx, mcy, mrx, mry = GR_MOUTH
    mcx += o
    mry += flare
    mrx += flare * 0.4
    neck = (o + 44, 9)
    # 喇叭身：上边从脖子到口的上沿，下边到口的下沿
    top_l, bot_l = mcy - mry + 1, mcy + mry - 1
    poly = [(neck[0], neck[1] - 2), (mcx + 1, top_l), (mcx + 1, bot_l), (neck[0], neck[1] + 2)]
    m = Image.new("L", (g.w, g.h), 0)
    ImageDraw.Draw(m).polygon(poly, fill=1)
    mask = np.asarray(m).astype(bool)
    for x in range(g.w):
        ys = np.nonzero(mask[:, x])[0]
        if len(ys) == 0:
            continue
        y0, y1 = ys.min(), ys.max()
        for y in ys:
            v = (y - y0) / max(y1 - y0, 1)
            g.put(x, y, 8 if v < 0.12 else 6 if v < 0.4 else 5 if v < 0.7 else 4 if v < 0.9 else 3)
        g.put(x, y0, 9)
    # 花瓣接缝：从脖子往口沿放射出去的暗线
    for ty in (-0.55, 0.0, 0.55):
        end = (round(mcx + 2), round(mcy + ty * (mry - 1)))
        g.line(neck[0] - 3, neck[1], end[0], end[1], 4 if ty > 0 else 5)
    # 喇叭口：亮的口沿 + 最暗的喉咙，红灯在喉咙深处
    ellipse(g, mcx, mcy, mrx, mry, 7)
    ellipse(g, mcx + 0.6, mcy, mrx - 1.0, mry - 1.2, 1)
    ellipse(g, mcx + 1.0, mcy, mrx - 2.2, mry - 3.5, 0)
    for y in range(g.h):                                                # 口沿：上半圈亮、下半圈暗
        for x in range(g.w):
            if g.a[y, x] == 7:
                if y < mcy - mry * 0.45:
                    g.a[y, x] = 9 if bright or y < mcy - mry * 0.8 else 8
                elif y > mcy + mry * 0.45:
                    g.a[y, x] = 8 if bright else 5
                elif bright:
                    g.a[y, x] = 9
    # 脖子：弯管从唱臂底座后面升上来
    g.rect(neck[0], neck[1] - 1, neck[0] + 1, 17, 6)
    g.rect(neck[0], neck[1] - 1, neck[0], 17, 7)
    g.put(neck[0] + 2, neck[1], 5)
    g.led(round(mcx + 1), mcy)


def gramophone(pose="idle", phase=0):
    """pose：idle / warn_sweep / sweep / warn_wave / wave。"""
    g = G(GR_W, GR_H)
    o = GR_OX
    gy = GR_H - 1
    # 柜子
    g.box(o + 17, 25, o + 44, 35, base=4, top=8, left=7, right=5, bottom=3)
    g.rect(o + 20, 28, o + 33, 32, 2)                                   # 音箱口：凹进去的格栅
    g.rect(o + 20, 28, o + 33, 28, 1)
    for x in range(o + 21, o + 33, 2):
        g.line(x, 29, x, 32, 4)
    g.rect(o + 36, 29, o + 41, 30, "r2")                                # 铜铭牌
    g.rect(o + 36, 29, o + 41, 29, "r3")
    # 侧面摇把
    crank = [(o + 45, 30), (o + 47, 28), (o + 49, 28)] if phase % 2 == 0 else [(o + 45, 30), (o + 47, 31), (o + 49, 31)]
    g.path(crank, 6)
    g.rect(crank[-1][0], crank[-1][1] - 1, crank[-1][0] + 1, crank[-1][1], 8)
    # 转盘 + 唱片（侧着看是一片扁椭圆）
    g.rect(o + 19, 23, o + 42, 24, 6)
    g.rect(o + 19, 23, o + 42, 23, 7)
    for y, x0, x1 in [(20, 25, 36), (21, 22, 39), (22, 21, 40)]:
        g.rect(o + x0, y, o + x1, y, 1)
    g.rect(o + 22, 21, o + 39, 21, 2)                                   # 纹路
    g.rect(o + 29, 21, o + 32, 21, "r3")                                # 中间的标签
    g.put(o + 30, 20, 8)                                                # 转轴
    # 唱片上一点高光，跟着转换位置；放招前转得飞快，拖成一条
    spin = {0: [(o + 24, 22), (o + 25, 22)], 1: [(o + 35, 22), (o + 36, 22)]}[phase % 2]
    if pose == "warn_wave":
        spin = [(x, 22) for x in range(o + 22, o + 39, 2)]
    g.pts(spin, 5)
    # 喇叭
    horn(g, o, flare=1 if pose == "wave" else 0, bright=pose in ("warn_wave", "wave"))
    # 唱臂：底座在右后方
    px, py = GR_PIVOT[0] + o - GR_OX, GR_PIVOT[1]
    g.rect(px - 1, 22, px + 1, 22, 7)                                   # 底座
    g.line(px, py, px, 21, 6)
    if pose == "warn_sweep":                                            # 抬起来
        tip = (px - 13, 12)
        g.line(px, py, tip[0], tip[1], 8)
        g.pts([(tip[0] - 1, tip[1]), (tip[0] - 1, tip[1] + 1), (tip[0] - 1, tip[1] + 2)], 9)
        g.put(tip[0] - 1, tip[1] + 3, "S")
    elif pose == "sweep":                                               # 甩到前面朝下，伸出去的部分由游戏画
        tip = (o + 13, 29)
        g.line(px, py, tip[0], tip[1], 8)
        g.line(px, py + 1, tip[0] + 1, tip[1], 6)
        g.pts([(tip[0], tip[1] + 1), (tip[0] - 1, tip[1] + 1)], 9)
    else:                                                               # 搭在唱片上
        tip = (o + 27, 19)
        g.line(px, py, tip[0], tip[1], 8)
        g.rect(tip[0] - 1, tip[1], tip[0], tip[1] + 1, 9)
        g.put(tip[0] - 1, tip[1] + 2, 7)
    g.put(px, py - 1, 9)
    if pose == "wave":                                                  # 往外冒的声纹
        mcx, mcy = GR_MOUTH[0] + o, GR_MOUTH[1]
        for r in (6, 9):
            for a in range(-60, 61, 12):
                x = round(mcx - 2 - r * math.cos(math.radians(a)) * 0.45)
                y = round(mcy + r * math.sin(math.radians(a)) * 1.3)
                g.put(x, y, "S" if r == 6 else "s")
    # 腿
    out_spread, in_spread = [(3, 1), (2, 2)][phase % 2]
    legs(g, [(o + 20, 36), (o + 42, 36)], gy, spread=out_spread)
    legs(g, [(o + 26, 36), (o + 36, 36)], gy, spread=in_spread, col=3, knee=4)
    return g


# ---------------------------------------------------------------- 导出
SW_FRAMES = [("idle", 0), ("idle", 1), ("warn_plug", 0), ("cast_plug", 0), ("warn_pull", 0), ("pull", 0)]
GR_FRAMES = [("idle", 0), ("idle", 1), ("warn_sweep", 0), ("sweep", 0), ("warn_wave", 0), ("wave", 0)]


def trim_all(frames):
    """所有帧同一个外框，身子（脚底中点）放在帧正中；返回裁好的帧和原画布在帧里的偏移。"""
    al = np.zeros(frames[0].shape[:2], bool)
    for f in frames:
        al |= f[..., 3] > 0
    ys, xs = np.nonzero(al)
    assert ys.max() == frames[0].shape[0] - 1, "地面要是最后一行"
    return [f[ys.min():, xs.min():xs.max() + 1] for f in frames], (xs.min(), ys.min())


def centered(frames, foot_x):
    """左右补透明，让 foot_x（原画布里身子中线）落在帧的正中间。"""
    cut, (x0, y0) = trim_all(frames)
    h, w = cut[0].shape[:2]
    fx = foot_x - x0
    half = max(fx, w - fx)
    out = []
    for f in cut:
        pad = np.zeros((h, half * 2, 4), np.uint8)
        pad[:, half - fx:half - fx + w] = f
        out.append(pad)
    return out, (x0 - (half - fx), y0)


def save_strip(path, frames):
    h, w = frames[0].shape[:2]
    out = np.zeros((h, w * len(frames), 4), np.uint8)
    for i, f in enumerate(frames):
        out[:, i * w:(i + 1) * w] = f
    Image.fromarray(out).save(path)


def font(size):
    for p in [HERE.parents[1] / "oscar-rush/fonts/PixelFont.ttf", Path("/System/Library/Fonts/PingFang.ttc")]:
        try:
            return ImageFont.truetype(str(p), size)
        except OSError:
            pass
    return None


def preview(rows, path):
    S, BG = 6, (104, 102, 110)
    crawler = np.asarray(Image.open(HERE.parents[1] / "oscar-rush/art/enemies/crawler.png").convert("RGBA"))[:, :36]
    hp = HERE.parents[1] / "oscar-rush/art/chars/red_body.png"
    hero = None
    if hp.exists():
        body = np.asarray(Image.open(hp).convert("RGBA"))[:, :16].copy()
        strip = np.asarray(Image.open(hp.with_name("red_strip.png")).convert("RGBA"))[:, :16]
        m = strip[..., 3] > 0
        body[m] = strip[m]
        hero = body
    f = font(22)
    lines = []
    for title, pair, anim, labels in rows:
        lines.append((title + "：待机 / 放招 / 比例尺（爬虫、主角）", list(pair) + [crawler] + ([hero] if hero is not None else []), None))
        lines.append((title + "：游戏帧", anim, labels))
    cell_h = [max(a.shape[0] for a in imgs) * S + 70 for _, imgs, _ in lines]
    W = max(sum(a.shape[1] * S + 24 for a in imgs) + 32 for _, imgs, _ in lines)
    img = Image.new("RGB", (max(W, 1100), sum(cell_h) + 50), BG)
    d = ImageDraw.Draw(img)
    d.text((16, 12), "Scrap Rush · 第二关精英怪：总机台、留声机（照爬虫画风，6 倍放大，朝左）", fill=(235, 232, 228), font=f)
    y0 = 50
    for (title, imgs, labels), ch in zip(lines, cell_h):
        d.text((16, y0 + 4), title, fill=(235, 232, 228), font=f)
        base_y = y0 + ch - 10
        x = 16
        for i, a in enumerate(imgs):
            im = Image.fromarray(a).resize((a.shape[1] * S, a.shape[0] * S), Image.NEAREST)
            img.paste(im, (x, base_y - im.size[1]), im)
            if labels:
                d.text((x, base_y - im.size[1] - 22), labels[i], fill=(220, 215, 210), font=font(16))
            x += im.size[0] + 24
        y0 += ch
    img.save(path)


def main():
    out = {}
    # 总机台：身子中线在柜子中间
    sw = [switchboard(p, ph) for p, ph in SW_FRAMES]
    sw_f, (sx0, sy0) = centered([g.rgba() for g in sw], SW_OX + 25)
    save_strip(GAME / "switchboard.png", sw_f)
    w, h = sw_f[0].shape[1], sw_f[0].shape[0]
    print(f"switchboard: {w}x{h} x {len(sw_f)} 帧")
    print("  红灯（帧内）", (SW_OX + 14 - sx0, 8 - sy0))
    print("  甩出去那根线的根（帧内）", (SW_OX + SW_HANG[0][0] - sx0, SW_SHELF_Y + 3 - sy0))
    print("  键架前沿（帧内）", (SW_OX + 2 - sx0, SW_SHELF_Y - sy0))
    print("  柜身 x", SW_OX + 10 - sx0, "~", SW_OX + 39 - sx0, " 顶", 1 - sy0)
    out["sw"] = sw_f
    # 留声机：身子中线在柜子中间
    gr = [gramophone(p, ph) for p, ph in GR_FRAMES]
    gr_f, (gx0, gy0) = centered([g.rgba() for g in gr], GR_OX + 30)
    save_strip(GAME / "gramophone.png", gr_f)
    w, h = gr_f[0].shape[1], gr_f[0].shape[0]
    print(f"gramophone: {w}x{h} x {len(gr_f)} 帧")
    print("  红灯（帧内）", (GR_MOUTH[0] + GR_OX + 1 - gx0, GR_MOUTH[1] - gy0))
    print("  喇叭口中心（帧内）", (GR_MOUTH[0] + GR_OX - gx0, GR_MOUTH[1] - gy0))
    print("  横扫时臂尖（帧内）", (GR_OX + 13 - gx0, 30 - gy0))
    print("  柜子 x", GR_OX + 17 - gx0, "~", GR_OX + 44 - gx0, " 喇叭顶", 0 - gy0)
    out["gr"] = gr_f

    def pair(fs, a, b):
        cut, _ = trim_all([fs[a], fs[b]])
        return cut

    preview([
        ("总机台 OPERATOR SWITCHBOARD", pair(sw_f, 0, 2), sw_f, ["0 走", "1 走", "2 插线预警", "3 插线", "4 拔线预警", "5 拔线"]),
        ("留声机 GRAMOPHONE", pair(gr_f, 0, 5), gr_f, ["0 走", "1 走", "2 横扫预警", "3 横扫", "4 声波预警", "5 声波"]),
    ], HERE / "l2_switch_gramophone_preview.png")
    # 检查器用的单帧（放在本文件夹不合适，写到 /tmp 下由调用的人自己指定）
    return out


if __name__ == "__main__":
    import sys
    res = main()
    if len(sys.argv) > 1:                                               # python3 l2_switch_gramophone.py <目录>：另存单帧给检查器
        d = Path(sys.argv[1])
        d.mkdir(parents=True, exist_ok=True)
        for k, fs in res.items():
            for i, f in enumerate(fs):
                Image.fromarray(f).save(d / f"{k}_{i}.png")
