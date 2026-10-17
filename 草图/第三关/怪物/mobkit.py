"""第三关画怪的工具库。每只怪只写一个函数画"基本姿势"，各帧由这里自动变出来（打法决定要哪些帧）。

一只怪：
    @mob("kitchen", "toaster", HOP, 14, 11, "吐司机：……")
    def toaster(c, f):
        part(c, c.rect(1, 3, 12, 9), CHROME)          # 用 c.rect / c.ellipse / c.poly 拿到形状的 mask，part 上色
        f.led(c, 3, 6)                                 # 红色指示灯眼睛：每只怪必须有一颗
        if f.up: ...                                    # 飞的怪：翅膀上 / 下两版（f.up），其余姿势工具库自动做

画布约定：c 是 w×h 的透明画布，脚踩在最下面一行，正面朝左（游戏里朝右时自动翻转）。
打法和帧（工具库自动生成，函数里可以用 f 的标记做细节）：
    FLY   飞（扑灯蛾的打法）：0 翅膀下、1 翅膀上（f.up）、2 俯冲（f.dive，自动压扁拉长）
    HOP   跳（弹簧跳蚤）：0 待机、1 蹲（自动压扁）、2 起跳（自动拉长 + 尘土）、3 空中（f.air）
    DASH  冲（剃须刀）：0、1 走路（f.step 0/1，自动颠一下）、2 蓄力（f.windup，自动闪光）、3 冲刺（f.dash，自动前倾 + 速度线）
    SHOOT 射（新）：0、1 走路、2 瞄准（f.aim，枪口发亮）、3 开火（f.fire，后坐 + 枪口火光）；要调 f.muzzle(c, x, y)
    ELITE 精英：0 待机、1 走（自动颠）、2 蓄力（自动压低 + 闪光）、3 出招（f.attack，自动前冲）、4 空中（f.air，自动拉长）、5 亮相（f.pose）
画风（照小奥斯卡 skill 的极简派规则）：
    - 不描边：轮廓靠色块本身的明暗；光从上面来（part 自动做：上亮下暗、顶边亮一档、底边暗一档）
    - 一只小怪 1~2 个色相家族；颜色取自它那个场景里的东西（吐司机是铬色 + 面包色）
    - 硬边、无半透明；小怪 8~20 格高（主角 13 格），精英 30~48 格高
"""
from __future__ import annotations

import sys
from dataclasses import dataclass, field

import numpy as np

sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")
from oscarkit.canvas import Canvas  # noqa: E402,F401
from oscarkit.shade import top_light, step_color  # noqa: E402

FLY, HOP, DASH, SHOOT, ELITE = "fly", "hop", "dash", "shoot", "elite"
FRAMES = {FLY: 3, HOP: 4, DASH: 4, SHOOT: 4, ELITE: 6}
LED = (226, 72, 64)
MUZZLE = (255, 236, 170)
REGISTRY: list["Mob"] = []


def ramp(base, n=5, span=1.0):
    """以 base 为中间的一条窄色阶（暗 → 亮），每档约 0.045 OKLab，亮的偏暖、暗的偏冷。"""
    half = (n - 1) / 2
    return [step_color(base, (i - half) * span) for i in range(n)]


def part(c: Canvas, m: np.ndarray, base, bands=1.0, rim=1, under=1, span=1.0):
    """给一块形状上色：光从上面来，顶边亮一档、底边暗一档，不描边。"""
    top_light(c, m, ramp(base, 5, span), bands=bands, rim=rim, under=under)
    return m


def flat(c: Canvas, m: np.ndarray, col):
    c.fill_mask(m, col)
    return m


def shade(col, k):
    return step_color(col, k)


@dataclass
class Pose:
    kind: str
    i: int
    up: bool = False
    dive: bool = False
    air: bool = False
    step: int = 0
    windup: bool = False
    dash: bool = False
    aim: bool = False
    fire: bool = False
    attack: bool = False
    pose: bool = False
    _muzzle: tuple | None = None

    def led(self, c: Canvas, x: int, y: int, size: int = 1):
        c.rect(x, y, x + size - 1, y + size - 1, LED)

    def muzzle(self, c: Canvas, x: int, y: int):
        self._muzzle = (x, y)


def poses(kind):
    if kind == FLY:
        return [Pose(kind, 0), Pose(kind, 1, up=True), Pose(kind, 2, dive=True)]
    if kind == HOP:
        return [Pose(kind, 0), Pose(kind, 1), Pose(kind, 2), Pose(kind, 3, air=True)]
    if kind == DASH:
        return [Pose(kind, 0), Pose(kind, 1, step=1), Pose(kind, 2, windup=True), Pose(kind, 3, dash=True)]
    if kind == SHOOT:
        return [Pose(kind, 0), Pose(kind, 1, step=1), Pose(kind, 2, aim=True), Pose(kind, 3, fire=True)]
    return [Pose(kind, 0), Pose(kind, 1, step=1), Pose(kind, 2, windup=True), Pose(kind, 3, attack=True),
            Pose(kind, 4, air=True), Pose(kind, 5, pose=True)]


# ---------------------------------------------------------------- 自动变形（锚在脚底中间）
def resample(a: np.ndarray, sx: float, sy: float, out_w: int, out_h: int, shear: float = 0.0) -> np.ndarray:
    """最近邻缩放 + 水平错切：脚底中间不动。shear>0 时上半身往前（左）倾。"""
    h, w = a.shape[:2]
    out = np.zeros((out_h, out_w, 4), np.uint8)
    cx_in, cx_out = w / 2, out_w / 2
    for oy in range(out_h):
        up = out_h - 1 - oy                       # 离脚底多少行
        iy = h - 1 - int(up / sy)
        if iy < 0 or iy >= h:
            continue
        off = shear * up
        for ox in range(out_w):
            ix = int(np.floor((ox - cx_out + off) / sx + cx_in))
            if 0 <= ix < w:
                out[oy, ox] = a[iy, ix]
    return out


def bob(a: np.ndarray, keep_rows=2) -> np.ndarray:
    """走路颠一下：脚以外的部分往上 1 格。"""
    out = a.copy()
    h = a.shape[0]
    body = a[:h - keep_rows]
    out[:h - keep_rows] = 0
    out[:h - keep_rows - 1] = body[1:]
    # 原来那一行如果有身体就补上，免得身体和脚之间断开
    out[h - keep_rows - 1] = np.where(a[h - keep_rows - 1][..., 3:] > 0, a[h - keep_rows - 1], out[h - keep_rows - 1])
    return out


def glint(a: np.ndarray) -> np.ndarray:
    """蓄力：指示灯变成 2×2 并在朝前（左）的轮廓上点几颗亮点。"""
    out = a.copy()
    led = np.all(a[..., :3] == LED, axis=-1) & (a[..., 3] > 0)
    ys, xs = np.nonzero(led)
    for y, x in zip(ys, xs):
        for dy, dx in [(0, -1), (-1, 0), (-1, -1)]:
            if 0 <= y + dy < a.shape[0] and 0 <= x + dx < a.shape[1] and a[y + dy, x + dx, 3] > 0:
                out[y + dy, x + dx, :3] = LED
    alpha = a[..., 3] > 0
    for y in range(0, a.shape[0], 3):
        xs_ = np.nonzero(alpha[y])[0]
        if len(xs_):
            out[y, xs_[0], :3] = (255, 246, 220)
    return out


def speedlines(a: np.ndarray, col=(236, 236, 236)) -> np.ndarray:
    out = a.copy()
    alpha = a[..., 3] > 0
    h, w = alpha.shape
    for y in range(1, h - 1, 3):
        xs_ = np.nonzero(alpha[y])[0]
        if len(xs_) and xs_[-1] + 3 < w:
            x0 = xs_[-1] + 2
            out[y, x0:min(w, x0 + 3)] = (*col, 255)
    return out


def dust(a: np.ndarray, col=(200, 196, 186)) -> np.ndarray:
    out = a.copy()
    h, w = a.shape[:2]
    for x in (1, 2, w - 3, w - 2):
        out[h - 1, x] = (*col, 255)
    out[h - 2, 0] = (*col, 255)
    out[h - 2, w - 1] = (*col, 255)
    return out


@dataclass
class Mob:
    scene: str
    name: str
    kind: str
    w: int
    h: int
    desc: str
    fn: object
    # 精英怪：招式（charge 冲撞 / slam 跳起来砸 / spray 扇形弹幕 / volley 抛物线弹 / summon 叫小怪）
    moves: list = field(default_factory=list)
    title: str = ""
    elite_name: str = ""
    hp: float = 0.0
    bullet: str = "rivet"
    frames: list = field(default_factory=list)
    leds: dict = field(default_factory=dict)
    muzzle: tuple | None = None
    frame_size: tuple = (0, 0)
    body_rect: tuple = (0, 0, 0, 0)

    def build(self):
        pad_x = 6 if self.kind in (DASH, ELITE) else 4
        pad_y = 6 if self.kind in (HOP, ELITE) else 3
        fw, fh = self.w + pad_x * 2, self.h + pad_y
        self.frame_size = (fw, fh)
        self.frames, self.leds = [], {}
        for p in poses(self.kind):
            c = Canvas(self.w, self.h)
            self.fn(c, p)
            if p.i == 0 and p._muzzle:
                self.muzzle = p._muzzle
            a = c.a
            sx, sy, shear = 1.0, 1.0, 0.0
            if self.kind == HOP:
                sy = {1: 0.78, 2: 1.15, 3: 1.06}.get(p.i, 1.0)
                sx = {1: 1.12, 2: 0.92}.get(p.i, 1.0)
            elif self.kind == FLY and p.dive:
                sx, sy = 1.12, 0.88
            elif self.kind == DASH and p.dash:
                shear = 0.18
            elif self.kind == ELITE:
                sy = {2: 0.9, 4: 1.08}.get(p.i, 1.0)
                sx = {2: 1.05}.get(p.i, 1.0)
                shear = 0.12 if p.attack else 0.0
            if p.step or (self.kind == ELITE and p.i == 1):
                a = bob(a)
            frame = resample(a, sx, sy, fw, fh, shear)
            # 压扁 / 拉长时红灯那一格可能被采样丢掉：按同样的变换算出它的新位置，补回去
            src = np.all(a[..., :3] == LED, axis=-1) & (a[..., 3] > 0)
            if src.any() and not (np.all(frame[..., :3] == LED, axis=-1) & (frame[..., 3] > 0)).any():
                ly, lx = [int(v) for v in np.argwhere(src)[0]]
                up = (self.h - 1 - ly) * sy
                oy = int(round(fh - 1 - up))
                ox = int(round((lx - self.w / 2) * sx + fw / 2 - shear * up))
                if 0 <= oy < fh and 0 <= ox < fw:
                    frame[oy, ox] = (*LED, 255)
            if p.windup:
                frame = glint(frame)
            if p.dash or (self.kind == ELITE and p.attack):
                frame = speedlines(frame)
            if self.kind == HOP and p.i == 2:
                frame = dust(frame)
            if self.kind == SHOOT and (p.aim or p.fire) and self.muzzle:
                mx = self.muzzle[0] + pad_x - (2 if p.fire else 0)
                my = self.muzzle[1] + (fh - self.h)
                frame = frame.copy()
                pts = [(0, 0)] if p.aim else [(0, 0), (-1, 0), (-2, 0), (-1, -1), (-1, 1)]
                for dx, dy in pts:
                    if 0 <= my + dy < fh and 0 <= mx + dx < fw:
                        frame[my + dy, mx + dx] = (*MUZZLE, 255)
                if p.fire:                                 # 后坐：整体往后（右）1 格
                    frame = np.roll(frame, 1, axis=1)
            self.frames.append(frame)
            led = np.all(frame[..., :3] == LED, axis=-1) & (frame[..., 3] > 0)
            ys, xs = np.nonzero(led)
            self.leds[p.i] = (int(xs.min()), int(ys.min())) if len(xs) else (-1, -1)
        if self.muzzle:
            self.muzzle = (self.muzzle[0] + pad_x, self.muzzle[1] + (fh - self.h))
        alpha = self.frames[0][..., 3] > 0
        ys, xs = np.nonzero(alpha)
        x0, x1, y0, y1 = xs.min() + 1, xs.max() - 1, ys.min() + 1, ys.max()
        self.body_rect = (int(x0 - fw // 2), int(y0 - fh), int(max(4, x1 - x0 + 1)), int(max(4, y1 - y0 + 1)))
        return self

    def strip(self) -> np.ndarray:
        return np.concatenate(self.frames, axis=1)


def mob(scene, name, kind, w, h, desc, **elite):
    def deco(fn):
        REGISTRY.append(Mob(scene, name, kind, w, h, desc, fn, **elite))
        return fn
    return deco


def check(m: Mob) -> list[str]:
    """几条硬规则：有红灯、不越界、没有半透明、高度在范围里、颜色别太多。"""
    out = []
    f0 = m.frames[0]
    if m.leds.get(0, (-1, -1))[0] < 0:
        out.append("第 0 帧没有红色指示灯")
    if np.any((f0[..., 3] > 0) & (f0[..., 3] < 255)):
        out.append("有半透明像素")
    alpha = f0[..., 3] > 0
    ys = np.nonzero(alpha.any(1))[0]
    hh = ys.max() - ys.min() + 1
    lo, hi = (26, 50) if m.kind == ELITE else (6, 22)
    if not lo <= hh <= hi:
        out.append(f"高度 {hh} 不在 {lo}~{hi}")
    cols = {tuple(px) for px in f0[alpha][:, :3]}
    if len(cols) > (40 if m.kind == ELITE else 18):
        out.append(f"颜色太多（{len(cols)}）")
    if m.kind == SHOOT and not m.muzzle:
        out.append("射击怪没有调 f.muzzle")
    if m.kind == ELITE and not m.moves:
        out.append("精英怪没有写 moves")
    return out
