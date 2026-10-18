"""制作人员页每页播的小动画：拼成精灵图 art/credits/<名字>.png（scripts/ui/credits_clip.gd 播）。
每帧 192×108，10 列一行，从左到右、从上到下。帧数、帧率要和 credits_clip.gd 的 CLIPS 对上。

两种来源：
- 从游戏里录的帧（<帧目录>/<名字>_00.png …）：mumu_*、oscar_run、oscar_elite、music_furnace、finale。
  录像场景不在工程里（立绘添加会话的 scratchpad），重录以后把帧目录传进来。
- 这里直接拼的：oscar_intro（开场动画 art/intro 中间裁一块）、wutong_portraits（三张立绘一张张淡入）。

跑：python3 tools/make_credits_clips.py [帧目录]   （不给帧目录就只重做 oscar_intro 和 wutong_portraits）
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "art"
OUT = ART / "credits"
W, H = 192, 108
COLS = 10

# 录的段：名字 → 帧数（和 credits_clip.gd 一致）
RECORDED = {
    "mumu_lamp": 36,
    "mumu_hammer": 36,
    "mumu_pressure": 36,
    "oscar_run": 36,
    "oscar_elite": 36,
    "music_furnace": 36,
    "finale": 40,
}

# 开场动画里裁的那块：机器从头到尾都在这块里
INTRO_BOX = (144, 140, 144 + W, 140 + H)

# 立绘页：背景色、每张立绘的帧安排
BG = (18, 16, 24)
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
PORTRAITS = [
    # (立绘, 停住时中间换的那张, 换几帧)
    ("red_portrait", "red_portrait_blink", 2),
    ("robot_portrait", "robot_portrait_talk", 3),
    ("dino_portrait", "dino_portrait_blink", 2),
]
FADE_IN = [4, 8, 12, 16]   # 淡入 4 帧：抖动阈值（16 = 全显）
FADE_OUT = [12, 6, 0]      # 淡出 3 帧
PER_PORTRAIT = [14, 13, 13]  # 加起来 40 帧


def sheet(frames: list) -> Image.Image:
    rows = (len(frames) + COLS - 1) // COLS
    out = Image.new("RGBA", (COLS * W, rows * H), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f.convert("RGBA"), ((i % COLS) * W, (i // COLS) * H))
    return out


def save(name: str, frames: list) -> None:
    OUT.mkdir(exist_ok=True)
    img = sheet(frames)
    assert img.width <= 2048 and img.height <= 2048, (name, img.size)
    # 减到 256 色（八叉树、不抖动）：录的画面带光照有上万种颜色，减完几乎没有像素变化超过 24 级，
    # 进包的贴图从 3.6MB 降到约 0.86MB（10-18）。空着的格子会变成黑色，播放时用不到
    img = img.convert("RGB").quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE)
    img.save(OUT / f"{name}.png", optimize=True)
    print(name, len(frames), "frames", img.size)


def recorded(frames_dir: Path) -> None:
    for name, n in RECORDED.items():
        files = [frames_dir / f"{name}_{i:02d}.png" for i in range(n)]
        missing = [f.name for f in files if not f.exists()]
        if missing:
            print("skip", name, "missing", missing[:3])
            continue
        frames = [Image.open(f).convert("RGB") for f in files]
        assert all(f.size == (W, H) for f in frames), name
        save(name, frames)


def oscar_intro() -> None:
    files = sorted((ART / "intro").glob("[0-9][0-9].png"))
    save("oscar_intro", [Image.open(f).convert("RGB").crop(INTRO_BOX) for f in files])


def dithered(base: Image.Image, top: Image.Image, at: tuple, level: int) -> Image.Image:
    """top 按 4×4 抖动只显出一部分（level/16），硬边、不出半透明"""
    out = base.copy()
    src = top.load()
    dst = out.load()
    for y in range(top.height):
        for x in range(top.width):
            r, g, b, a = src[x, y]
            if a < 128:
                continue
            gx, gy = at[0] + x, at[1] + y
            if not (0 <= gx < W and 0 <= gy < H):
                continue
            if BAYER[gy % 4][gx % 4] < level:
                dst[gx, gy] = (r, g, b)
    return out


def background() -> Image.Image:
    bg = Image.new("RGB", (W, H), BG)
    px = bg.load()
    # 底下一道暗一点的地面线，跟对话框底色一样不抢眼
    for x in range(W):
        for y in range(H - 6, H):
            px[x, y] = (12, 10, 16)
    return bg


def wutong_portraits() -> None:
    chars = ART / "chars"
    bg = background()
    frames = []
    for (main, alt, alt_n), total in zip(PORTRAITS, PER_PORTRAIT):
        a = Image.open(chars / f"{main}.png").convert("RGBA")
        b = Image.open(chars / f"{alt}.png").convert("RGBA")
        x = (W - a.width) // 2
        y_end = H - a.height
        hold = total - len(FADE_IN) - len(FADE_OUT)
        # 淡入：从下面 2 格浮上来
        for i, lv in enumerate(FADE_IN):
            dy = max(0, 2 - i)
            frames.append(dithered(bg, a, (x, y_end + dy), lv))
        mid = hold // 2 - alt_n // 2
        for i in range(hold):
            img = b if mid <= i < mid + alt_n else a
            frames.append(dithered(bg, img, (x, y_end), 16))
        for lv in FADE_OUT:
            frames.append(dithered(bg, a, (x, y_end), lv))
    assert len(frames) == sum(PER_PORTRAIT)
    save("wutong_portraits", frames)


def main() -> None:
    if len(sys.argv) > 1:
        recorded(Path(sys.argv[1]))
    oscar_intro()
    wutong_portraits()


if __name__ == "__main__":
    main()
