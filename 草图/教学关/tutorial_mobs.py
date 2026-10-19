"""教学关专属的怪（10-19 作者挑的方案 2「训练靶场」）：都是训练器材 / 发条铁皮玩具，画法借第三关的 mobkit。
    "~/Desktop/程序programs/AI Oscar/.venv/bin/python" 草图/教学关/tutorial_mobs.py            出预览（草图/教学关/预览_教学关怪.png）
    "~/Desktop/程序programs/AI Oscar/.venv/bin/python" 草图/教学关/tutorial_mobs.py --export   另外导出贴图到 oscar-rush/art/enemies/tutorial/，
                                                                                              生成 oscar-rush/scripts/tutorial/tutorial_mobs.gd
  - 铁皮打靶机 target / target_shield / target_rail（客厅）：游乐场打靶那种圆靶立在木座上，打中往后翻倒。
    帧：0 立着、1 翻到一半、2 倒平。挡板款靶面前面多一块铆钉铁板；轨道款底下是带轮子的小车（轨道游戏里画）。
  - 发条拳击手 boxer（厨房，打法照剃须刀 DASH）：0、1 走，2 前摇（拳头往后收），3 出拳往前冲
  - 发条铁皮蛾 tinmoth（阁楼，打法照扑灯蛾 FLY）
  - 大陪练 coach（儿童房精英 ELITE）：冲撞、跳砸
不进第三关的 REGISTRY 导出（level3_mobs.gd 是别的会话的），只借 mobkit 的画法和自动变帧。
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "第三关" / "怪物"))
import mobkit  # noqa: E402
from mobkit import part, flat, shade, FLY, DASH, ELITE, Pose  # noqa: E402
from oscarkit.canvas import Canvas  # noqa: E402

GAME = HERE.parent.parent / "oscar-rush"
OUT = GAME / "art/enemies/tutorial"

TIN = (186, 192, 204)
DARK = (70, 66, 74)
WOOD = (150, 100, 64)
CREAM = (236, 226, 200)
RING = (192, 62, 54)          # 靶环的红，和指示灯的红（226,72,64）分得开
GLOVE = (214, 104, 58)        # 拳套橙红
BRASS = (206, 170, 92)


def key(c, x, y, turn):
    """发条钥匙：x、y 是钥匙杆根部，turn 0/1 两种转角。"""
    flat(c, c.rect(x, y, x + 1, y), shade(TIN, -2))
    if turn:
        flat(c, c.rect(x + 2, y - 2, x + 2, y + 2), BRASS)
        flat(c, c.rect(x + 3, y - 1, x + 3, y + 1), shade(BRASS, -2))
    else:
        flat(c, c.rect(x + 2, y - 1, x + 4, y + 1), BRASS)
        c.put(x + 3, y, shade(BRASS, -3))


# ---------------------------------------------------------------- 发条拳击手（DASH）
def boxer(c, f):
    body = (96, 132, 190)                     # 蓝色铁皮短裤 / 身子
    key(c, 11, 8, f.step)
    part(c, c.rect(4, 7, 11, 12), body)
    flat(c, c.rect(4, 10, 11, 10), CREAM)                     # 腰带
    part(c, c.ellipse(7.5, 4, 3.6, 3.6), TIN)                 # 圆脑袋
    flat(c, c.rect(5, 3, 7, 4), shade(body, -3))              # 护头的眼缝
    leg = 1 if f.step else 0
    flat(c, c.rect(5, 13, 6, 15 - leg), shade(TIN, -3)); flat(c, c.rect(9, 13, 10, 15 - (1 - leg)), shade(TIN, -3))
    flat(c, c.rect(4, 15, 6, 15), shade(TIN, -3)); flat(c, c.rect(9, 15, 11, 15), shade(TIN, -3))
    # 拳套：平时举在胸前，前摇收到身后，出拳伸到最前面
    if f.windup:
        gx = 8
    elif f.dash:
        gx = 0
    else:
        gx = 2
    if gx < 4:
        flat(c, c.rect(gx + 2, 8, 4, 8), shade(TIN, -2))      # 胳膊
    part(c, c.ellipse(gx + 1.5, 8.5, 1.8, 1.8), GLOVE)
    part(c, c.ellipse(10.5, 9, 1.6, 1.6), GLOVE)              # 后手
    f.led(c, 5, 3)


# ---------------------------------------------------------------- 发条铁皮蛾（FLY）
def tinmoth(c, f):
    wing = (222, 176, 82)
    if f.up:
        wings = ([(6, 6), (0, 0), (5, 1), (8, 5)], [(9, 6), (15, 0), (10, 1), (7, 5)])
    else:
        wings = ([(6, 5), (0, 6), (1, 10), (6, 8)], [(9, 5), (15, 6), (14, 10), (9, 8)])
    for pts in wings:
        part(c, c.poly(pts), wing)
    for x, y in ((2, 2), (12, 2)) if f.up else ((2, 8), (12, 8)):
        flat(c, c.rect(x, y, x + 1, y), RING)                 # 铁皮上印的圆点
    part(c, c.ellipse(7.5, 6.5, 2.6, 3.4), TIN)
    flat(c, c.rect(6, 8, 9, 8), shade(TIN, -3))               # 身上的接缝
    flat(c, c.rect(7, 1, 7, 2), shade(TIN, -2)); flat(c, c.rect(6, 0, 8, 0), BRASS)   # 头顶的小钥匙
    f.led(c, 6, 5)


# ---------------------------------------------------------------- 大陪练（ELITE）
def coach(c, f):
    body = (96, 132, 190)
    yy = -2 if f.pose else 0
    key(c, 31, 14 + yy, f.step)                               # 背上的大钥匙
    flat(c, c.rect(33, 11 + yy, 33, 17 + yy), BRASS)
    part(c, c.rect(10, 12 + yy, 31, 27), body)                # 铁皮桶身
    flat(c, c.rect(10, 22, 31, 22), shade(body, -2))
    for x in (12, 18, 24, 29):
        c.put(x, 14 + yy, shade(body, 3))                     # 铆钉
    flat(c, c.rect(17, 16 + yy, 24, 19 + yy), CREAM)          # 胸口的号码牌
    flat(c, c.rect(20, 17 + yy, 21, 18 + yy), DARK)
    part(c, c.ellipse(20.5, 7 + yy, 7, 6), TIN)               # 圆脑袋
    flat(c, c.rect(15, 6 + yy, 23, 8 + yy), DARK)             # 护面的眼缝
    flat(c, c.rect(19, 0 + yy, 21, 1 + yy), RING)             # 头顶的红绒球
    for x0 in (12, 24):                                       # 两条腿，底下一对小轮
        flat(c, c.rect(x0, 28, x0 + 4, 31), shade(TIN, -3))
        part(c, c.ellipse(x0 + 2.5, 32.5, 2.6, 1.6), DARK)
    # 拳套：平时一前一后；蓄力时前手收回来；出招时前手伸到最前；空中两手举高；亮相两手举在脸边
    if f.windup:
        front, back = (13, 15), (28, 17)
    elif f.attack:
        front, back = (3, 16), (26, 18)
    elif f.air:
        front, back = (8, 6), (32, 6)
    elif f.pose:
        front, back = (9, 9), (31, 9)
    else:
        front, back = (7, 15), (30, 18)
    part(c, c.ellipse(back[0], back[1] + yy * 0, 3.6, 3.4), shade(GLOVE, -1))
    if front[0] < 10:
        flat(c, c.rect(front[0] + 2, front[1], 11, front[1] + 1), shade(TIN, -2))   # 胳膊
    part(c, c.ellipse(front[0], front[1], 3.8, 3.6), GLOVE)
    f.led(c, 16, 7 + yy, 2)


MOBS = [
    mobkit.Mob("tutorial", "boxer", DASH, 14, 16, "发条拳击手：晃到你面前，头上冒 ! 收拳，然后往前冲一拳", boxer),
    mobkit.Mob("tutorial", "tinmoth", FLY, 16, 11, "发条铁皮蛾：扑向地上的马灯", tinmoth),
    mobkit.Mob("tutorial", "coach", ELITE, 38, 34, "大陪练：冲撞、跳砸，两招都先冒 !", coach,
               moves=["charge", "slam"], elite_name="SPARRING BOT", title="PRACTICE ROUND", hp=450),
]


# ---------------------------------------------------------------- 铁皮打靶机（自己出帧：立着、翻一半、倒平）
TW, TH = 40, 22                 # 一帧的大小；原点在脚底中间（x = 20）
PIVOT = (20, 17)                # 靶杆根部（往后翻倒绕的点）


def _target_top(shield: bool) -> Canvas:
    """靶杆 + 圆靶（+ 挡板），画在整帧大小的画布上，杆根在 PIVOT。"""
    c = Canvas(TW, TH)
    px, py = PIVOT
    flat(c, c.rect(px - 1, py - 7, px, py), shade(TIN, -3))   # 靶杆
    cx, cy = px - 0.0, py - 11.5
    part(c, c.ellipse(cx, cy, 5.6, 5.6), CREAM)
    flat(c, c.ellipse(cx, cy, 4.4, 4.4) & ~c.ellipse(cx, cy, 3.2, 3.2), RING)
    flat(c, c.ellipse(cx, cy, 2.0, 2.0), CREAM)
    if shield:
        # 前面（左边）一块铆钉铁板，靠一根短杆撑着
        flat(c, c.rect(px - 9, py - 9, px - 6, py - 9), shade(TIN, -2))
        part(c, c.rect(px - 12, py - 17, px - 8, py - 3), TIN)
        for y in (py - 15, py - 10, py - 5):
            c.put(px - 10, y, shade(TIN, 3))
    return c


def _target_base(rail: bool) -> Canvas:
    c = Canvas(TW, TH)
    px, py = PIVOT
    if rail:
        part(c, c.rect(px - 5, py + 1, px + 4, py + 2), (120, 140, 160))
        for x in (px - 3.5, px + 3.5):
            part(c, c.ellipse(x, py + 3.5, 1.6, 1.6), DARK)
    else:
        part(c, c.rect(px - 5, py + 1, px + 4, TH - 1), WOOD)
    flat(c, c.rect(px - 1, py, px, py), BRASS)               # 合页
    return c


def _flip_back(a: np.ndarray, sy: float, py: int) -> np.ndarray:
    """往后翻倒：靶面朝着人，往后倒就是绕杆根那一行竖着压扁（最近邻），压扁后整块往右挪一点（倒向后面）。"""
    h, w = a.shape[:2]
    out = np.zeros_like(a)
    shift = int(round((1.0 - sy) * 6))
    for oy in range(h):
        up = py - oy
        if up < 0:
            continue
        iy = py - int(up / sy)
        if iy < 0:
            continue
        for ox in range(w):
            ix = ox - shift
            if 0 <= ix < w:
                out[oy, ox] = a[iy, ix]
    return out


def target_frames(shield=False, rail=False):
    top = _target_top(shield)
    px, py = PIVOT
    top.put(px, py - 12, mobkit.LED)                          # 靶心就是指示灯
    base = _target_base(rail).a
    frames = []
    for sy in (1.0, 0.5, 0.18):
        t = _flip_back(top.a, sy, PIVOT[1]) if sy < 1.0 else top.a.copy()
        f = base.copy()
        m = t[..., 3] > 0
        f[m] = t[m]
        frames.append(f)
    return frames


def target_cfg(name, frames):
    f0 = frames[0]
    ys, xs = np.nonzero(f0[..., 3] > 0)
    body = (int(xs.min() - TW // 2), int(ys.min() - TH), int(xs.max() - xs.min() + 1), int(TH - ys.min()))
    leds = {}
    for i, fr in enumerate(frames):
        led = np.all(fr[..., :3] == mobkit.LED, axis=-1) & (fr[..., 3] > 0)
        yy, xx = np.nonzero(led)
        leds[i] = (int(xx.min()), int(yy.min())) if len(xx) and i == 0 else (-1, -1)
    return {"name": name, "frames": frames, "frame_size": (TW, TH), "body_rect": body, "leds": leds}


TARGETS = [target_cfg("target", target_frames()),
           target_cfg("target_shield", target_frames(shield=True)),
           target_cfg("target_rail", target_frames(rail=True))]


# ---------------------------------------------------------------- 出预览、导出
def main():
    problems = []
    for m in MOBS:
        m.build()
        problems += [f"{m.name}: {p}" for p in mobkit.check(m)]
    rows = [(m.name, m.strip()) for m in MOBS] + [(t["name"], np.concatenate(t["frames"], axis=1)) for t in TARGETS]
    k = 4
    W = max(s.shape[1] for _, s in rows) * k + 40
    H = sum(s.shape[0] * k + 16 for _, s in rows) + 20
    sheet = Image.new("RGB", (W, H), (44, 40, 54))
    y = 10
    for _, s in rows:
        im = Image.fromarray(s)
        im = im.resize((im.width * k, im.height * k), Image.NEAREST)
        sheet.paste(im, (20, y), im)
        y += s.shape[0] * k + 16
    sheet.save(HERE / "预览_教学关怪.png")
    # 摆进房间里看看：客厅三个靶、阁楼一只蛾（琥珀屏）、厨房两只拳击手、儿童房大陪练
    rooms = [Image.open(GAME / f"art/tutorial/room_{i}.png").convert("RGBA") for i in range(5)]
    def put(img, arr, x, foot_y, flip=False):
        a = arr[:, ::-1] if flip else arr
        im = Image.fromarray(a)
        img.alpha_composite(im, (int(x - a.shape[1] // 2), int(foot_y - a.shape[0])))
    fy = 237
    for i, t in enumerate(TARGETS):
        put(rooms[1], t["frames"][0 if i else 2], 200 + i * 70, fy)
    put(rooms[2], MOBS[1].frames[0], 120, 150)
    put(rooms[3], MOBS[0].frames[0], 200, fy)
    put(rooms[3], MOBS[0].frames[2], 280, fy, True)
    put(rooms[4], MOBS[2].frames[5], 330, fy)
    strip = Image.new("RGBA", (rooms[1].width * 4, rooms[1].height))
    for j, i in enumerate((1, 2, 3, 4)):
        strip.alpha_composite(rooms[i], (j * rooms[1].width, 0))
    strip.resize((strip.width * 2, strip.height * 2), Image.NEAREST).save(HERE / "预览_教学关怪_房间里.png")
    print("预览写好了")
    if problems:
        print("问题：\n  " + "\n  ".join(problems))
    if "--export" not in sys.argv:
        return
    OUT.mkdir(parents=True, exist_ok=True)
    lines = ["## 教学关专属的怪，由 草图/教学关/tutorial_mobs.py --export 生成，别手改。",
             "## 格式和 level3_mobs.gd 一样（L3Mob.apply_cfg 能直接用）；TARGETS 是铁皮打靶机（帧：0 立着、1 翻一半、2 倒平）。",
             "", "const MOBS := {"]
    for m in MOBS:
        Image.fromarray(m.strip()).save(OUT / f"{m.name}.png")
        leds = ", ".join(f"{i}: Vector2i({v[0]}, {v[1]})" for i, v in m.leds.items())
        br = m.body_rect
        extra = f', "bullet": "{m.bullet}"'
        if m.kind == ELITE:
            extra += f', "elite_name": "{m.elite_name}", "title": "{m.title}", "hp": {m.hp}, "moves": {json.dumps(m.moves)}'
        lines.append(f'\t"{m.name}": {{"scene": "tutorial", "kind": "{m.kind}", '
                     f'"texture": "res://art/enemies/tutorial/{m.name}.png", "hframes": {len(m.frames)}, '
                     f'"frame_size": Vector2i({m.frame_size[0]}, {m.frame_size[1]}), '
                     f'"body_rect": Rect2({br[0]}, {br[1]}, {br[2]}, {br[3]}), "leds": {{{leds}}}, '
                     f'"muzzle": Vector2i(-1, -1){extra}}},')
    lines += ["}", "", "const TARGETS := {"]
    for t in TARGETS:
        Image.fromarray(np.concatenate(t["frames"], axis=1)).save(OUT / f"{t['name']}.png")
        leds = ", ".join(f"{i}: Vector2i({v[0]}, {v[1]})" for i, v in t["leds"].items())
        br = t["body_rect"]
        lines.append(f'\t"{t["name"]}": {{"texture": "res://art/enemies/tutorial/{t["name"]}.png", "hframes": 3, '
                     f'"frame_size": Vector2i({TW}, {TH}), "body_rect": Rect2({br[0]}, {br[1]}, {br[2]}, {br[3]}), '
                     f'"leds": {{{leds}}}}},')
    lines += ["}", ""]
    (GAME / "scripts/tutorial/tutorial_mobs.gd").write_text("\n".join(lines))
    print("导出到", OUT)


if __name__ == "__main__":
    main()
