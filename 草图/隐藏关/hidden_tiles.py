"""隐藏关「第四盘 · 倒带」的地块（放映机会话，10-18）。

    "/Users/jiamulin/Desktop/程序programs/AI Oscar/.venv/bin/python" hidden_tiles.py   # 出 oscar-rush/art/hidden/tiles.png + 放大预览

一张 64×128 的图集，每格 16×16，4 列 × 8 行：
  列：0 左端  1 中间（可以重复铺）  2 右端  3 单块（只有一格宽）
  行 0  回忆木板 · 实（光里）         暖色蜂蜜木：亮顶边、横向木纹、两头钉子、底下一道影
  行 1  回忆木板 · 虚（光外）         只剩一排暖色虚线（顶边和底边），中间透明：看得见、踩不住
  行 2  回忆木板 · 要变虚了（闪）    实的那张，每隔一行横着错开一格 + 一条白噪线（像信号不好），实 → 虚之前 0.35 秒用
  行 3  覆盖层废铁 · 实（暗处）       冷色铁板：斜条纹、铆钉、亮的冷边
  行 4  覆盖层废铁 · 化成雪花 A       光照上去：一半像素变成雪花点、一半透明
  行 5  覆盖层废铁 · 化成雪花 B       只剩零星雪花（化完前最后一帧）
  行 6  中性地面 · 顶                录像带的黑褐磁带面：紫灰顶边 + 一道亮线，底下是磁带的细横纹（任何时候都能站）
  行 7  中性地面 · 里面              同一种磁带面，没有顶边，往下铺
平台（行 0~5）只画在格子的上面 8 行，下面 8 行透明（碰撞框按 16×8 或者自己定都行）。

三种东西一眼分得开（单色屏也分得开）：
  回忆木板最亮、横纹；废铁最暗、斜纹；中性是中间的灰、平的、带一条亮顶边。
光从左上来；不描边；硬边、没有半透明。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, "/Users/jiamulin/Desktop/程序programs/AI Oscar")

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OUT = ROOT / "oscar-rush/art/hidden"

# 回忆：蜂蜜色木头（暗 → 亮）
WARM = [(112, 70, 50), (150, 98, 62), (190, 132, 80), (222, 168, 104), (240, 198, 132), (250, 224, 170)]
# 覆盖层：冷色废铁（暗 → 亮），偏蓝
COLD = [(28, 32, 48), (40, 48, 70), (56, 68, 98), (78, 96, 132), (112, 136, 172)]
SNOW = [(150, 166, 196), (206, 216, 232)]
# 中性：磁带的紫灰
NEUT = [(30, 26, 36), (40, 35, 48), (52, 46, 62), (70, 62, 82), (104, 94, 120)]
WHITE = (236, 232, 222)


def cell():
    return np.zeros((16, 16, 4), np.uint8)


def put(a, x, y, c):
    if 0 <= x < a.shape[1] and 0 <= y < a.shape[0]:
        a[y, x] = (*c, 255)


def plank(kind):
    """回忆木板实心的一格。kind: L / M / R / S。高 7 行（y 0~6），第 7 行透明。"""
    a = cell()
    x0 = 1 if kind in "LS" else 0
    x1 = 14 if kind in "RS" else 15
    for x in range(x0, x1 + 1):
        put(a, x, 0, WARM[5] if x < 11 else WARM[4])       # 顶边：左边受光最亮
        put(a, x, 1, WARM[4])
        put(a, x, 2, WARM[3])
        put(a, x, 3, WARM[3])
        put(a, x, 4, WARM[2])
        put(a, x, 5, WARM[1])
        put(a, x, 6, WARM[0])                               # 底下一道影
    # 横向木纹：两段错开的暗一档短线
    for x in range(x0 + 2, min(x1, x0 + 8)):
        put(a, x, 3, WARM[2])
    for x in range(x0 + 9, x1 - 1):
        put(a, x, 2, WARM[2] if x % 5 else WARM[3])
    # 端头：圆角 + 钉子
    if kind in "LS":
        put(a, x0, 0, WARM[4])
        put(a, x0, 6, (0, 0, 0)) if False else None
        a[6, x0] = 0
        put(a, x0 + 2, 3, WARM[0])
        put(a, x0 + 2, 2, WARM[5])
    if kind in "RS":
        a[0, x1] = (*WARM[3], 255)
        a[6, x1] = 0
        put(a, x1 - 2, 3, WARM[0])
        put(a, x1 - 2, 2, WARM[4])
    if kind == "M":                                         # 中间一格右边一道板缝（铺起来是一块块木板）
        for y in range(1, 6):
            put(a, 15, y, WARM[1])
        put(a, 15, 0, WARM[3])
    return a


def ghost(kind):
    """光外的回忆木板：只剩暖色虚线（顶边 2 亮 2 空，底边 2 暗 2 空），两头一小截竖线。"""
    a = cell()
    x0 = 1 if kind in "LS" else 0
    x1 = 14 if kind in "RS" else 15
    for x in range(x0, x1 + 1):
        if (x // 2) % 2 == 0:
            put(a, x, 0, WARM[2])
        if ((x + 2) // 2) % 2 == 0:
            put(a, x, 6, WARM[1])
    if kind in "LS":
        put(a, x0, 2, WARM[1])
        put(a, x0, 3, WARM[1])
    if kind in "RS":
        put(a, x1, 3, WARM[1])
        put(a, x1, 4, WARM[1])
    return a


def flicker(kind):
    """要变虚之前：实心木板每隔一行横着错开一格（录像带跟踪不好），中间一条白噪线。"""
    a = plank(kind)
    out = a.copy()
    for y in (1, 3, 5):
        out[y] = np.roll(a[y], 1 if y != 3 else -1, axis=0)
    rng = np.random.default_rng({"L": 1, "M": 2, "R": 3, "S": 4}[kind])
    for x in range(16):
        if out[4, x, 3] and rng.random() < 0.45:
            out[4, x] = (*WHITE, 255)
    return out


def scrap(kind):
    """覆盖层废铁实心的一格：冷色铁板，斜条纹（左下到右上），两头铆钉，顶边一条冷亮边。"""
    a = cell()
    x0 = 1 if kind in "LS" else 0
    x1 = 14 if kind in "RS" else 15
    for x in range(x0, x1 + 1):
        put(a, x, 0, COLD[4] if x % 4 else COLD[3])
        for y in range(1, 6):
            put(a, x, y, COLD[3] if (x + y) % 4 == 0 else (COLD[2] if (x + y) % 4 == 1 else COLD[1]))
        put(a, x, 6, COLD[0])
    if kind in "LS":
        put(a, x0 + 2, 3, COLD[4])
        put(a, x0 + 2, 4, COLD[0])
    if kind in "RS":
        put(a, x1 - 2, 3, COLD[4])
        put(a, x1 - 2, 4, COLD[0])
    if kind == "M":
        for y in range(1, 6):
            put(a, 15, y, COLD[0])
    return a


def dissolve(kind, step):
    """光一照，废铁化成雪花。step 1：一半像素变雪花、一半透明；step 2：只剩零星雪花。"""
    a = scrap(kind)
    rng = np.random.default_rng(10 + step * 7 + {"L": 1, "M": 2, "R": 3, "S": 4}[kind])
    out = a.copy()
    for y in range(16):
        for x in range(16):
            if not a[y, x, 3]:
                continue
            r = rng.random()
            if step == 1:
                if r < 0.4:
                    out[y, x] = 0
                elif r < 0.65:
                    out[y, x] = (*SNOW[(x + y) % 2], 255)
            else:
                out[y, x] = 0
                if r < 0.16:
                    out[y, x] = (*SNOW[(x * 3 + y) % 2], 255)
    if step == 2:                                          # 雪花往下落一点
        out = np.roll(out, 1, axis=0)
        out[0] = 0
    return out


def ground(kind, top):
    """中性地面（磁带面）：top=True 是顶上那一格（紫灰顶边 + 一道亮线），否则是里面。
    kind: L / M / R / S（L、R 是端头，侧边亮 / 暗一档）。"""
    a = cell()
    for y in range(16):
        for x in range(16):
            c = NEUT[1] if (y % 4) else NEUT[2]            # 磁带的细横纹
            if y > 9:
                c = NEUT[0] if (y % 4) else NEUT[1]
            put(a, x, y, c)
    if top:
        for x in range(16):
            put(a, x, 0, NEUT[4] if x < 12 else NEUT[3])
            put(a, x, 1, NEUT[3])
            put(a, x, 2, NEUT[2])
    if kind in "LS":
        for y in range(16):
            put(a, 0, y, NEUT[3] if y < 3 or not top else NEUT[2])
    if kind in "RS":
        for y in range(16):
            put(a, 15, y, NEUT[0])
    return a


def atlas():
    rows = [
        [plank(k) for k in "LMRS"],
        [ghost(k) for k in "LMRS"],
        [flicker(k) for k in "LMRS"],
        [scrap(k) for k in "LMRS"],
        [dissolve(k, 1) for k in "LMRS"],
        [dissolve(k, 2) for k in "LMRS"],
        [ground(k, True) for k in "LMRS"],
        [ground(k, False) for k in "LMRS"],
    ]
    return np.concatenate([np.concatenate(r, axis=1) for r in rows], axis=0)


def mono(a):
    """单色屏自查：按亮度映射到 6 档灰。"""
    out = a.copy()
    al = a[..., 3] > 0
    L = (0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]) / 255.0
    g = (np.clip((L * 6).astype(int), 0, 5) * 42 + 20).astype(np.uint8)
    for i in range(3):
        out[..., i] = np.where(al, g, 0)
    return out


def preview(a, path):
    """放大 8 倍预览：上面彩色、下面单色屏；另外拼一小段"一排木板 + 一排废铁 + 地面"的样子。"""
    S = 8
    bg = np.zeros((a.shape[0] * 2 + 8, a.shape[1] * 2 + 8, 4), np.uint8)
    bg[..., :3] = (26, 22, 30)
    bg[..., 3] = 255
    for i, img in enumerate((a, mono(a))):
        m = img[..., 3] > 0
        sub = bg[4:4 + a.shape[0], 4 + i * (a.shape[1] + 0):4 + i * a.shape[1] + a.shape[1]]
        sub[m] = img[m]
    # 小样：两排平台、地面
    W = 160
    demo = np.zeros((64, W, 4), np.uint8)
    demo[..., :3] = (26, 22, 30)
    demo[..., 3] = 255

    def tile(r, c):
        return a[r * 16:(r + 1) * 16, c * 16:(c + 1) * 16]

    def lay(img, x, y):
        m = img[..., 3] > 0
        demo[y:y + 16, x:x + 16][m] = img[m]

    for i, c in enumerate([0, 1, 1, 2]):
        lay(tile(0, c), 8 + i * 16, 10)
        lay(tile(1, c), 8 + i * 16, 28)
        lay(tile(3, c), 84 + i * 16, 10)
        lay(tile(4, c), 84 + i * 16, 28)
    for i in range(10):
        lay(tile(6, 1 if 0 < i < 9 else (0 if i == 0 else 2)), i * 16, 46)
    big = Image.fromarray(np.concatenate([demo, mono(demo)], axis=1)).resize((W * 2 * 4, 64 * 4), Image.NEAREST)
    at = Image.fromarray(bg).resize((bg.shape[1] * S, bg.shape[0] * S), Image.NEAREST)
    sheet = Image.new("RGB", (max(big.width, at.width), big.height + at.height + 10), (26, 22, 30))
    sheet.paste(at.convert("RGB"), (0, 0))
    sheet.paste(big.convert("RGB"), (0, at.height + 10))
    sheet.save(path)


# ---------------------------------------------------------------- 接口约定的那几张（夜间打磨/隐藏关接口.md 第 7 节）
# plank_*.png 16×6 横向平铺；block.png 16×16 四向平铺
PINK = [(110, 52, 74), (168, 82, 112), (214, 120, 150), (240, 168, 190)]     # 跳帧 A：粉
CYAN = [(36, 82, 92), (60, 126, 138), (98, 178, 186), (160, 222, 222)]     # 跳帧 B：青


def strip6(a):
    """从 16×16 的平台格里取 16×6：顶边、木纹 / 条纹、底下一道影（去掉一行身子）。"""
    return np.concatenate([a[0:3], a[4:7]], axis=0)


def frame_plank(ramp, pat):
    """跳帧平台：A 粉色，顶上一排胶片齿孔（2 亮 2 空）；B 青色，身子上一排点。单色屏里 A 比 B 亮一档。"""
    a = np.zeros((6, 16, 4), np.uint8)
    for x in range(16):
        put(a, x, 0, ramp[3])
        for y in (1, 2, 3):
            put(a, x, y, ramp[2])
        put(a, x, 4, ramp[1])
        put(a, x, 5, ramp[0])
    if pat == "A":
        for x in range(16):
            if (x // 2) % 2 == 0:
                put(a, x, 1, ramp[3])
        put(a, 15, 2, ramp[1])
        put(a, 15, 3, ramp[1])
    else:
        for x in range(1, 16, 4):
            put(a, x, 2, ramp[3])
            put(a, x + 2, 3, ramp[1])
    return a


def block16():
    """中性实心块：磁带面紫灰，细横纹，每 16 行一道很淡的亮线（铺起来像一层层缠紧的磁带）。"""
    a = ground("M", False)
    for x in range(16):
        put(a, x, 0, NEUT[3] if x < 12 else NEUT[2])
    return a


def export_interface():
    files = {
        "plank_memory.png": strip6(plank("M")),
        "plank_junk.png": strip6(scrap("M")),
        "plank_a.png": frame_plank(PINK, "A"),
        "plank_b.png": frame_plank(CYAN, "B"),
        "block.png": block16(),
        # 可选的状态帧（关卡愿意用就用）：光外的虚线、要变虚前的闪、废铁化成雪花两帧
        "plank_memory_ghost.png": strip6(ghost("M")),
        "plank_memory_flicker.png": strip6(flicker("M")),
        "plank_junk_melt1.png": strip6(dissolve("M", 1)),
        "plank_junk_melt2.png": strip6(dissolve("M", 2)),
    }
    for name, img in files.items():
        Image.fromarray(img).save(OUT / name)
    return files


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    a = atlas()
    Image.fromarray(a).save(OUT / "tiles.png")
    files = export_interface()
    # 平铺小样：每种铺 6 格，彩色和单色屏并排
    rows = []
    for n in ("plank_memory", "plank_memory_ghost", "plank_junk", "plank_junk_melt1", "plank_a", "plank_b"):
        t = np.concatenate([files[n + ".png"]] * 6, axis=1)
        pad = np.zeros((10, 96, 4), np.uint8)
        rows += [t, pad]
    blk = np.concatenate([np.concatenate([files["block.png"]] * 6, axis=1)] * 2, axis=0)
    demo = np.concatenate(rows + [blk], axis=0)
    bg = np.zeros(demo.shape, np.uint8)
    bg[..., :3] = (26, 22, 30)
    bg[..., 3] = 255
    m = demo[..., 3] > 0
    bg[m] = demo[m]
    both = np.concatenate([bg, np.zeros((bg.shape[0], 8, 4), np.uint8) + 255, mono(bg)], axis=1)
    Image.fromarray(both).resize((both.shape[1] * 6, both.shape[0] * 6), Image.NEAREST).save(HERE / "预览" / "planks_6x.png")
    (HERE / "预览").mkdir(exist_ok=True)
    preview(a, HERE / "预览" / "tiles_8x.png")
    print("tiles.png", a.shape[1], "x", a.shape[0])


if __name__ == "__main__":
    main()
