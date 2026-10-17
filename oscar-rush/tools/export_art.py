"""把 Art_Assets 里 Oscar 的 aseprite 原稿切成游戏用的 PNG。

用法：python3 tools/export_art.py（只导开场动画：加 --intro）
原稿只读，输出写到 art/ 下面。Oscar 改了原稿就重跑一次。
"""
import json
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT.parent / "Art_Assets"
ASEPRITE = "/Applications/Aseprite.app/Contents/MacOS/aseprite"

# 角色·.aseprite：每帧 64×64，上面一排是大号的四个角色（y 28~47），按 16 像素一格横排
CHAR_ROW = (28, 48)
CHARS = {"red": 0, "robot": 16, "bird": 32, "dino": 48}
# 每个角色身上最亮的那一档就是荧光条
STRIP_COLORS = {
    "red": (255, 192, 192),
    "robot": (255, 225, 194),
    "bird": (201, 212, 255),
    "dino": (218, 255, 206),
}


def export_frames(src: Path, tmp: Path, ignore_layers=()) -> list[np.ndarray]:
    sheet, data = tmp / (src.stem + ".png"), tmp / (src.stem + ".json")
    cmd = [ASEPRITE, "-b"]
    for layer in ignore_layers:
        cmd += ["--ignore-layer", layer]
    cmd += [str(src), "--sheet", str(sheet), "--sheet-type", "horizontal",
            "--data", str(data), "--format", "json-array"]
    subprocess.run(cmd, check=True, capture_output=True)
    im = np.array(Image.open(sheet).convert("RGBA"))
    frames = []
    for f in json.loads(data.read_text())["frames"]:
        r = f["frame"]
        frames.append(im[r["y"]:r["y"] + r["h"], r["x"]:r["x"] + r["w"]])
    return frames


def save(arr: np.ndarray, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(arr).save(path)
    print("wrote", path.relative_to(ROOT), arr.shape[1], "x", arr.shape[0])


def export_chars(tmp: Path) -> None:
    frames = export_frames(SRC / "角色·.aseprite", tmp)
    y0, y1 = CHAR_ROW
    for name, x0 in CHARS.items():
        cells = [f[y0:y1, x0:x0 + 16] for f in frames]
        body = np.concatenate(cells, axis=1)
        rgb = body[:, :, :3]
        is_strip = np.all(rgb == STRIP_COLORS[name], axis=2) & (body[:, :, 3] > 0)
        strip = np.zeros_like(body)
        strip[is_strip] = body[is_strip]
        save(body, ROOT / f"art/chars/{name}_body.png")
        save(strip, ROOT / f"art/chars/{name}_strip.png")


def export_crawler(tmp: Path) -> None:
    frames = export_frames(SRC / "爬虫.aseprite", tmp)
    union = np.zeros(frames[0].shape[:2], bool)
    for f in frames:
        union |= f[:, :, 3] > 0
    ys, xs = np.where(union)
    x0, x1 = xs.min(), xs.max() + 1
    y1 = ys.max() + 1
    w = x1 - x0
    w += w % 2
    cells = [f[y1 - 16:y1, x0:x0 + w] for f in frames]
    save(np.concatenate(cells, axis=1), ROOT / "art/enemies/crawler.png")


def export_scene(tmp: Path) -> None:
    clean = ROOT.parent / "ldjam/scene_clean.png"
    arr = np.array(Image.open(clean).convert("RGBA"))
    save(arr, ROOT / "art/levels/scene1.png")


# 场景1.aseprite 的图层，从后往前分成几组做视差。第 0 帧是静止的完整场景
# （后面 26 帧是 Boss 台和右上吊车在动），"图层 12" 是红线路线，不导出。
SCENE_LAYER_GROUPS = {
    "far": ["图层 9", "图层 11"],          # 底色 + 最远的斜梁
    "beams": ["图层 10"],                 # 带橙色格子的斜梁
    "machines": ["图层 8"],               # 远处的大机器、格栅墙
    "truss": ["图层 7"],                  # X 形大桁架
    "near": ["图层 4", "图层 3", "图层 2", "图层 5", "QIAO", "di"],  # 能站的东西和栏杆，跟镜头 1:1
}


def export_scene_layers(tmp: Path) -> None:
    src = SRC / "场景1.aseprite"
    for group, layers in SCENE_LAYER_GROUPS.items():
        out = None
        for i, layer in enumerate(layers):
            png = tmp / f"{group}_{i}.png"
            subprocess.run([ASEPRITE, "-b", "--layer", layer, "--frame-range", "0,0",
                            str(src), "--sheet", str(png)], check=True, capture_output=True)
            im = Image.open(png).convert("RGBA")
            out = im if out is None else Image.alpha_composite(out, im)
        save(np.array(out), ROOT / f"art/levels/scene1_{group}.png")


# 关卡里桥和吊车要动，"near" 那一组在游戏里拆成三层，桥和吊车夹在中间，前后关系和原图一样：
#   near_a（图层 4）→ 吊车（图层 3）→ near_b（图层 2、5）→ 桥（QIAO）→ near_c（di）
# scene1_near.png（全部叠在一起的第 0 帧）留给开始界面等别的地方用。
NEAR_SPLIT = {"near_a": ["图层 4"], "near_b": ["图层 2", "图层 5"], "near_c": ["di"]}
# 会动的两层：(图层名, 输出名, 裁剪框 x0, y0, x1, y1)，27 帧横排
ANIMATED = [("QIAO", "bridge", 449, 343, 809, 380), ("图层 3", "crane", 912, 0, 1003, 161)]


def export_scene_split(tmp: Path) -> None:
    src = SRC / "场景1.aseprite"
    for name, layers in NEAR_SPLIT.items():
        out = None
        for i, layer in enumerate(layers):
            png = tmp / f"{name}_{i}.png"
            subprocess.run([ASEPRITE, "-b", "--layer", layer, "--frame-range", "0,0",
                            str(src), "--sheet", str(png)], check=True, capture_output=True)
            im = Image.open(png).convert("RGBA")
            out = im if out is None else Image.alpha_composite(out, im)
        save(np.array(out), ROOT / f"art/levels/scene1_{name}.png")
    for layer, name, x0, y0, x1, y1 in ANIMATED:
        frames = export_frames(src, tmp, [l for l in _all_layers(src) if l != layer])
        cells = [f[y0:y1, x0:x1] for f in frames]
        save(np.concatenate(cells, axis=1), ROOT / f"art/levels/scene1_{name}.png")


def _all_layers(src: Path) -> list[str]:
    r = subprocess.run([ASEPRITE, "-b", "--list-layers", str(src)], check=True, capture_output=True, text=True)
    return [l.strip() for l in r.stdout.splitlines() if l.strip()]


def export_intro(tmp: Path) -> None:
    """开场动画.aseprite：28 帧 480×270，原样逐帧导出成 art/intro/00.png ……
    每帧时长写在 scripts/ui/intro.gd 的 DURATIONS 里，Oscar 改了帧数或时长要对着改。"""
    src = SRC / "开场动画.aseprite"
    frames = export_frames(src, tmp)
    for i, f in enumerate(frames):
        save(f, ROOT / "art" / "intro" / f"{i:02d}.png")
    data = json.loads((tmp / (src.stem + ".json")).read_text())
    print("intro durations (ms):", [f["duration"] for f in data["frames"]])


if __name__ == "__main__":
    import sys
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        if "--intro" in sys.argv:  # 只导开场动画
            export_intro(tmp)
            sys.exit()
        export_intro(tmp)
        export_chars(tmp)
        export_crawler(tmp)
        export_scene(tmp)
        export_scene_layers(tmp)
        export_scene_split(tmp)
