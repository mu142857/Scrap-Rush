"""把 crt_level3.py 画好的第三关导进 Godot 工程。

- 四张分层图拷到 oscar-rush/art/levels/l3_*.png
- 生成 oscar-rush/scripts/levels/level3_data.gd：碰撞方块、单向平台、爬洞、屏幕、起点终点
  碰撞 = 中景层（外壳、杂物、仓库地面）有像素的地方，减去屏幕里面（地面以上）、左右通道、上下的洞，
  再把每一行的连续段往下合并成长方形。

跑法：先跑 crt_level3.py，再 "~/Desktop/程序programs/AI Oscar/.venv/bin/python" export_level3.py
"""
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent
GAME = HERE.parents[1] / "oscar-rush"
L = json.loads((HERE / "l3_layout.json").read_text())
W, H = L["size"]

mid = np.array(Image.open(HERE / "l3_mid.png"))
solid = mid[..., 3] > 0
open_ = np.zeros((H, W), bool)


def cut(x0, y0, x1, y1):
    open_[max(0, y0):max(0, y1 + 1), max(0, x0):max(0, x1 + 1)] = True


for s in L["screens"]:
    sx0, sy0, sx1, sy1 = s["screen"]
    cut(sx0, sy0, sx1, s["floor"] - 1)                       # 屏幕里面，地面以上
for p in L["passages"]:
    cut(p["x0"], p["y0"], p["x1"], p["floor"] - 1)           # 左右通道
SHAFTS = []
for h in L["holes"]:
    lower = next(s for s in L["screens"] if s["floor"] == h["bottom"] and s["screen"][0] <= h["x0"] <= s["screen"][2])
    cut(h["x0"], h["top"] - 2, h["x1"], lower["screen"][1] + 6)
    # 爬的范围：从下面房间的地面一直到上面房间地面以上 30 格（爬出洞口再往旁边走）
    SHAFTS.append((h["ladder_x"] - 7, h["top"] - 30, 16, h["bottom"] - (h["top"] - 30)))


def close_gaps(m, n=8):
    """一行里两段实心之间不到 n 格的缝填上（杂物堆参差的边、外壳之间的细缝）。"""
    m = m.copy()
    for y in range(m.shape[0]):
        row = m[y]
        idx = np.nonzero(row)[0]
        if len(idx) < 2:
            continue
        gaps = np.nonzero(np.diff(idx) > 1)[0]
        for g in gaps:
            a, b = idx[g], idx[g + 1]
            if b - a - 1 <= n:
                row[a + 1:b] = True
    return m


solid = close_gaps(close_gaps(solid).T).T
solid = close_gaps(solid)
solid &= ~open_


def rects(mask):
    """每一行的连续段，和上一行完全一样的就往下延长，最后得到一组不重叠的长方形。"""
    out, active = [], {}
    for y in range(H + 1):
        runs = set()
        if y < H:
            row = mask[y]
            d = np.diff(np.concatenate([[0], row.astype(np.int8), [0]]))
            starts, ends = np.nonzero(d == 1)[0], np.nonzero(d == -1)[0]
            runs = set(zip(starts.tolist(), ends.tolist()))
        for key in list(active):
            if key not in runs:
                y0 = active.pop(key)
                out.append((key[0], y0, key[1] - key[0], y - y0))
        for key in runs:
            active.setdefault(key, y)
    return out


R = [r for r in rects(solid) if r[2] * r[3] >= 12]        # 天线、零星的小点不算
print(len(R), "solid rects")

# 网页版：WebGL 只保证 2048 的贴图，很多手机、集显上限是 4096，第三关整张图 4600 多宽会画不出来。
# 所以每层再切成 TILE 宽的竖条（l3_<层>_<序号>.png），游戏里拼起来显示。整张的也照旧拷过去，
# tools/draw_boss3.py 拿它做 Boss 房背景。
TILE = 2048
n_tiles = 0
for name in ("far", "mid", "screens", "near"):
    shutil.copy(HERE / f"l3_{name}.png", GAME / "art/levels" / f"l3_{name}.png")
    full = Image.open(HERE / f"l3_{name}.png")
    n_tiles = 0
    for i, x in enumerate(range(0, full.width, TILE)):
        full.crop((x, 0, min(full.width, x + TILE), full.height)).save(GAME / "art/levels" / f"l3_{name}_{i}.png")
        n_tiles = i + 1


def v2(p):
    return f"Vector2({p[0]}, {p[1]})"


lines = [
    "class_name Level3Data",
    "## 第三关的数据，由 草图/第三关/export_level3.py 生成，别手改：改地图就重跑 crt_level3.py 和 export_level3.py。",
    "",
    f"const BOUNDS := Rect2(0, 0, {W}, {H})",
    f"const START := {v2(L['start'])}",
    f"const END := {v2(L['end'])}",
    "## 每层切成几条（网页版贴图不能超过 2048 宽），见 export_level3.py",
    f"const TILE_W := {TILE}",
    f"const TILES := {n_tiles}",
    "## 实心的地方：外壳、电视之间的杂物、仓库地面",
    "const SOLIDS: Array[Rect2] = [",
]
lines += [f"\tRect2({x}, {y}, {w}, {h})," for x, y, w, h in R]
lines += ["]", "## 单向平台（家具、屋顶、伞……）：[x0, x1, y]", "const PLATFORMS := ["]
lines += [f"\t[{p['x0']}, {p['x1']}, {p['y']}]," for p in L["platforms"]]
lines += ["]", "## 上下的洞：按住跳就顺着电线往上爬", "const SHAFTS: Array[Rect2] = ["]
lines += [f"\tRect2({x}, {y}, {w}, {h})," for x, y, w, h in SHAFTS]
lines += ["]", "## 每块屏幕：名字、显示方式、屏幕框 [x0, y0, x1, y1]、地面、[层, 段]、是不是这种场景的精英战场子", "const SCREENS := ["]
for s in L["screens"]:
    lines.append(f"\t{{\"name\": \"{s['name']}\", \"tint\": \"{s['tint']}\", \"rect\": {s['screen']}, "
                 f"\"floor\": {s['floor']}, \"row\": {s['row']}, \"seg\": {s['seg']}, "
                 f"\"encounter\": {str(s.get('encounter', False)).lower()}, "
                 f"\"wall_left\": {str(s.get('wall_left', False)).lower()}}},")
# 路线路点（自动驾驶测试用）：每条路线一串 [x, 地面 y, 动作]，动作是 "walk"（走到 x）、"climb"（在 x 爬到 y）、"exit"
routes_wp = []
for route in L.get("routes", []):
    wp = []
    for (r, sg), (nr, nsg) in zip(route, route[1:]):
        h = next(h for h in L["holes"] if tuple(h["lower"]) == (r, sg) and tuple(h["upper"]) == (nr, nsg))
        wp.append(f'[{h["ladder_x"]}, {h["bottom"]}, "walk"]')
        wp.append(f'[{h["ladder_x"]}, {h["top"]}, "climb"]')
    wp.append(f'[{L["end"][0]}, {L["end"][1]}, "exit"]')
    routes_wp.append("[" + ", ".join(wp) + "]")
lines += ["]", "## 每条路线的路点（scripts/debug/l3_autopilot.gd 用）：[x, 地面 y, 动作]", "const ROUTES := ["]
lines += [f"\t{r}," for r in routes_wp]
lines += ["]", "## 洞的位置，摆怪的时候避开：[x0, x1, 上面的地面, 下面的地面]", "const HOLES := ["]
lines += [f"\t[{h['x0']}, {h['x1']}, {h['top']}, {h['bottom']}]," for h in L["holes"]]
lines += ["]", ""]
(GAME / "scripts/levels/level3_data.gd").write_text("\n".join(lines))
print("wrote", GAME / "scripts/levels/level3_data.gd")


# ---------------------------------------------------------------- 结局录像：家乡（2026-10-17 夜）
# 结局里老电视放的录像、老电视屏幕上的家乡画面，都用这张 444×245 的图（boss3_room.gd、tv_boss.gd 读它）。
# 以前 tools/draw_boss3.py 按旧地图坐标切，地图改了以后只剩左边一窄条。现在单独干净地画一张家乡：
# 和地图里终点那块屏幕是同一个场景函数、同样大小，但没有左边通道砍出来的缺口。
def export_hometown():
    import random as _r
    import crt_wall_v2 as k
    from crt_wall_v2 import KHAKI, TV
    k.setup(480, 300, 290)
    _r.seed(3)
    k.rng = np.random.default_rng(3)
    import l3_registry as reg
    tv = TV(10, 10, 460, 270, KHAKI, "meter", "color", top="vents")
    tv.tint, tv.flat, tv.outdoor, tv.name = "color", False, True, "hometown"
    k.set_vp(tv)
    reg.draw("hometown", tv)
    glass = k.scr.a[tv.sy0:tv.sy1 + 1, tv.sx0:tv.sx1 + 1].copy()
    glass[glass[..., 3] == 0] = (0, 0, 0, 255)            # 圆角外面填黑，像显像管的边
    out = GAME / "art/boss/hometown.png"
    Image.fromarray(glass).save(out)
    print("wrote", out, glass.shape[1], "x", glass.shape[0])


export_hometown()
