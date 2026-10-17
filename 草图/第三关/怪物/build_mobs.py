"""收集 mobs_*.py 里登记的所有第三关怪物：生成帧、跑检查、出每个场景的预览图，--export 时导进游戏。

    python build_mobs.py                     全部场景出预览（预览/<场景>.png）
    python build_mobs.py kitchen beach       只出这几个场景
    python build_mobs.py --export            另外导出贴图到 oscar-rush/art/enemies/l3/，
                                             并生成 oscar-rush/scripts/levels/level3_mobs.gd
用 "~/Desktop/程序programs/AI Oscar/.venv/bin/python" 跑。
"""
import importlib
import json
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
import mobkit  # noqa: E402

L3 = HERE.parent
GAME = L3.parents[1] / "oscar-rush"
# --files=mobs_a,mobs_b 只读这几个文件（别人的文件还在改的时候用）
_only = next((a.split("=", 1)[1].split(",") for a in sys.argv if a.startswith("--files=")), None)
for f in sorted(HERE.glob("mobs_*.py")):
    if _only is None or f.stem in _only:
        importlib.import_module(f.stem)

args = [a for a in sys.argv[1:] if not a.startswith("--")]
export = "--export" in sys.argv
mobs = [m for m in mobkit.REGISTRY if not args or m.scene in args]

LAYOUT = json.loads((L3 / "l3_layout.json").read_text())
SCREENS_IMG = np.array(Image.open(L3 / "l3_screens.png").convert("RGBA"))
MID_IMG = np.array(Image.open(L3 / "l3_mid.png").convert("RGBA"))
TINTS = {
    "color": None,
    "bw": [(34, 36, 44), (70, 72, 82), (112, 114, 124), (156, 158, 166), (204, 206, 210), (236, 236, 236)],
    "green": [(18, 36, 26), (32, 70, 46), (56, 116, 72), (96, 170, 104), (150, 220, 150), (206, 246, 196)],
    "amber": [(40, 22, 16), (86, 46, 22), (146, 84, 34), (204, 128, 54), (238, 178, 96), (252, 222, 160)],
}
FONT = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 20)


def in_game(a, tint, y_world):
    """和游戏里的着色器一样：按屏幕的显示方式把亮度映射到色阶（红灯不变），偶数行压暗（扫描线）。"""
    a = a.copy().astype(float)
    m = a[..., 3] > 0
    led = np.all(a[..., :3] == mobkit.LED, axis=-1)
    ramp_ = TINTS[tint]
    if ramp_:
        Lm = (0.3 * a[..., 0] + 0.55 * a[..., 1] + 0.15 * a[..., 2]) / 255
        idx = np.clip((Lm * 1.15 * len(ramp_)).astype(int), 0, len(ramp_) - 1)
        a[..., :3] = np.where((m & ~led)[..., None], np.array(ramp_, float)[idx], a[..., :3])
    rows = (np.arange(a.shape[0]) + y_world) % 2 == 0
    a[rows, :, :3] *= np.where(led[rows][..., None], 1.0, 0.93)
    return a.astype(np.uint8)


def scene_shot(scene, ms):
    """这个场景的一块屏幕，把这个场景的怪都摆进去：地上走的站地上，飞的飘在半空。"""
    cands = [s for s in LAYOUT["screens"] if s["name"] == scene]
    if not cands:
        return None
    s = max(cands, key=lambda s: s["screen"][2] - s["screen"][0])
    x0, y0, x1, y1 = s["casing"]
    img = MID_IMG[y0:y1 + 1, x0:x1 + 1].copy()
    scr = SCREENS_IMG[y0:y1 + 1, x0:x1 + 1]
    img[scr[..., 3] > 0] = scr[scr[..., 3] > 0]
    sx0, sy0, sx1, _ = s["screen"]
    n = len(ms)
    for i, m in enumerate(ms):
        fr = m.frames[0]
        fh, fw = fr.shape[:2]
        cx = sx0 + (sx1 - sx0) * (i + 1) // (n + 1)
        fy = s["floor"] - (30 if m.kind == mobkit.FLY else 0)
        px, py = cx - fw // 2 - x0, fy - fh - y0
        spr = in_game(fr if fr[..., 3].any() else fr, s["tint"], py + y0)
        if m.kind != mobkit.ELITE and i % 2:
            spr = spr[:, ::-1]                       # 一半朝右
        mm = spr[..., 3] > 0
        sub = img[py:py + fh, px:px + fw]
        if sub.shape[:2] == mm.shape:
            sub[mm] = spr[mm]
    return Image.fromarray(img), s["tint"]


by_scene = {}
problems = []
names = [m.name for m in mobkit.REGISTRY]
for n in sorted({n for n in names if names.count(n) > 1}):
    problems.append(f"名字重复：{n}")
# 第一关的怪名（遭遇战按名字生怪，撞名会生错）
for n in sorted(set(names) & {"crawler", "moth", "kettle", "shaver", "flea", "cuckoo", "sewing", "register", "piano", "vacuum", "roller"}):
    problems.append(f"和第一关的怪重名：{n}")
for m in mobs:
    m.build()
    for p in mobkit.check(m):
        problems.append(f"{m.scene}/{m.name}: {p}")
    by_scene.setdefault(m.scene, []).append(m)

(HERE / "预览").mkdir(exist_ok=True)
for scene, ms in by_scene.items():
    rows_h = sum(max(120, m.frame_size[1] * 4 + 50) for m in ms)
    shot = scene_shot(scene, ms)
    sw = shot[0].width * 3 if shot else 0
    W_ = max(1400, sw + 40)
    H_ = rows_h + (shot[0].height * 3 + 60 if shot else 0) + 20
    sheet = Image.new("RGB", (W_, H_), (24, 22, 30))
    d = ImageDraw.Draw(sheet)
    y = 10
    for m in ms:
        strip = Image.fromarray(m.strip())
        big = strip.resize((strip.width * 4, strip.height * 4), Image.NEAREST)
        bg = Image.new("RGB", big.size, (44, 40, 54))
        bg.paste(big, (0, 0), big)
        sheet.paste(bg, (20, y + 30))
        tag = f"{m.name}  [{m.kind}]  {m.desc}"
        if m.kind == mobkit.ELITE:
            tag += f"  招式：{' / '.join(m.moves)}  血 {m.hp:.0f}"
        d.text((20, y + 4), tag, fill=(236, 230, 210), font=FONT)
        y += max(120, m.frame_size[1] * 4 + 50)
    if shot:
        img, tint = shot
        sheet.paste(img.resize((img.width * 3, img.height * 3), Image.NEAREST), (20, y + 30))
        d.text((20, y + 4), f"放进 {scene} 的屏幕里（{tint}），游戏里大概就是这样", fill=(190, 186, 200), font=FONT)
    sheet.save(HERE / "预览" / f"{scene}.png")

print(f"{len(mobs)} 只怪，{len(by_scene)} 个场景")
for scene, ms in by_scene.items():
    print(f"  {scene}: " + ", ".join(f"{m.name}({m.kind})" for m in ms))
if problems:
    print("问题：")
    for p in problems:
        print("  " + p)

if export:
    out = GAME / "art/enemies/l3"
    out.mkdir(parents=True, exist_ok=True)
    lines = ["## 第三关的怪，由 草图/第三关/怪物/build_mobs.py --export 生成，别手改。",
             "## 每只：场景、打法（fly/hop/dash/shoot/elite）、贴图、帧数、帧大小、碰撞框、每帧红灯位置、枪口；",
             "## 精英怪另有名字、标语、血量、招式、子弹。", "", "const MOBS := {"]
    for m in mobkit.REGISTRY:
        Image.fromarray(m.strip()).save(out / f"{m.name}.png")
        leds = ", ".join(f"{k}: Vector2i({v[0]}, {v[1]})" for k, v in m.leds.items())
        br = m.body_rect
        extra = f', "bullet": "{m.bullet}"'
        if m.kind == mobkit.ELITE:
            extra += (f', "elite_name": "{m.elite_name or m.name.upper()}", "title": "{m.title}", "hp": {m.hp or 900.0},'
                     f' "moves": {json.dumps(m.moves)}')
        mz = f"Vector2i({m.muzzle[0]}, {m.muzzle[1]})" if m.muzzle else "Vector2i(-1, -1)"
        lines.append(f'\t"{m.name}": {{"scene": "{m.scene}", "kind": "{m.kind}", '
                     f'"texture": "res://art/enemies/l3/{m.name}.png", "hframes": {len(m.frames)}, '
                     f'"frame_size": Vector2i({m.frame_size[0]}, {m.frame_size[1]}), '
                     f'"body_rect": Rect2({br[0]}, {br[1]}, {br[2]}, {br[3]}), "leds": {{{leds}}}, "muzzle": {mz}{extra}}},')
    lines += ["}", ""]
    (GAME / "scripts/levels/level3_mobs.gd").write_text("\n".join(lines))
    print("导出到", out)
