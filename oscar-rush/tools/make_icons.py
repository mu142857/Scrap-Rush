"""把 art/icon/icon_<尺寸>.png 拼成各平台要的图标（2026-10-19，游戏细节讨论会话）。

用法：python3 tools/make_icons.py [图标目录，默认 art/icon]
读 icon_16 / 32 / 64 / 128 / 256 / 512.png（放映机会话画的，小尺寸是单独对过像素的），写到同一个目录：
- icon.ico：Windows（project.godot 的 application/config/windows_native_icon，导出 exe 也用它）。16 / 32 / 48 / 64 / 128 / 256 都放进去，
  48 是 16 的 3 倍最近邻放大（没有单画的 48）。
- icon.icns：macOS（application/config/macos_native_icon，Dock 和导出的 .app 用它）。用系统自带的 iconutil 拼，
  1024（512@2x）是 512 的 2 倍最近邻放大。
- favicon_16.png / favicon_32.png / apple_touch_180.png：网页版。web/export_web.sh 拷到导出目录，并往 index.html 的 <head> 里加 <link>（编辑器直接导出就没有这两张，用 Godot 的 128）。
  180 不是哪张的整数倍：从 64 放大 3 倍成 192 再最近邻缩到 180（像素差一点点，手机主屏上看不出来）。
网页的 index.icon.png（128）是 Godot 导出时用 application/config/icon 生成的，config/icon 指着 icon_128.png，所以不缩放、不糊。
"""
import io
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "art" / "icon"
SIZES = [16, 32, 64, 128, 256, 512]


def load(size: int) -> Image.Image:
    im = Image.open(DIR / f"icon_{size}.png").convert("RGBA")
    if im.size != (size, size):
        sys.exit(f"icon_{size}.png 是 {im.size}，应该是 {size}×{size}")
    return im


def nearest(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.NEAREST)


def write_ico(path: Path, images: list) -> None:
    blobs = []
    for im in images:
        buf = io.BytesIO()
        im.save(buf, format="PNG")
        blobs.append(buf.getvalue())
    out = struct.pack("<HHH", 0, 1, len(images))
    offset = 6 + 16 * len(images)
    for im, blob in zip(images, blobs):
        w, h = im.size
        out += struct.pack("<BBBBHHII", w % 256, h % 256, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    path.write_bytes(out + b"".join(blobs))


def main() -> None:
    icons = {s: load(s) for s in SIZES}
    # Windows：自己拼 .ico（每个尺寸一张 PNG），Pillow 存 .ico 会从一张图缩出其他尺寸、像素图会糊
    ico_imgs = [icons[16], icons[32], nearest(icons[16], 48), icons[64], icons[128], icons[256]]
    write_ico(DIR / "icon.ico", ico_imgs)
    # macOS
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "icon.iconset"
        iconset.mkdir()
        pairs = {
            "icon_16x16.png": icons[16], "icon_16x16@2x.png": icons[32],
            "icon_32x32.png": icons[32], "icon_32x32@2x.png": icons[64],
            "icon_128x128.png": icons[128], "icon_128x128@2x.png": icons[256],
            "icon_256x256.png": icons[256], "icon_256x256@2x.png": icons[512],
            "icon_512x512.png": icons[512], "icon_512x512@2x.png": nearest(icons[512], 1024),
        }
        for name, im in pairs.items():
            im.save(iconset / name)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(DIR / "icon.icns")], check=True)
    # 网页
    icons[16].save(DIR / "favicon_16.png")
    icons[32].save(DIR / "favicon_32.png")
    nearest(icons[64], 192).resize((180, 180), Image.NEAREST).save(DIR / "apple_touch_180.png")
    for f in ["icon.ico", "icon.icns", "favicon_16.png", "favicon_32.png", "apple_touch_180.png"]:
        print(f"wrote {DIR / f} ({(DIR / f).stat().st_size} bytes)")


if __name__ == "__main__":
    main()
