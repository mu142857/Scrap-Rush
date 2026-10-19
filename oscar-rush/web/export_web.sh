#!/bin/bash
# 导出网页版（itch.io / Ludum Dare 用），照 meme、《不散》的 bilibili/export_web.sh，去掉了 B 站的部分。
#
#   bash web/export_web.sh              -> ../build/web/ 和 ../build/scrap_rush_web.zip（上传 itch 用这个 zip）
#   bash web/export_web.sh <输出目录>    -> 导出到别的目录（测试用），zip 放在它旁边
#
# 1. 用 web/ 里的精简引擎（只有 2D、单线程、关掉不用的模块，从 meme 拷来，配置见 custom.py，Godot 4.7.2）
#    和 web/shell.html（加载界面：启动画面 + 进度条 + 版本号 + 卡住重试）。这两样在 export_presets.cfg 的 "Web" 预设里已经填好，
#    在编辑器里直接导出也会用上，只是少了下面 3~5 步（文件大一些、没有版本号，照样能玩）。
# 2. 给 Godot 的下载器打补丁：网络半路断一下时它会把错误吞掉、永远卡住，补上以后会重下。
# 3. 版本号：web/VERSION 加北京时间，写进加载界面左下角。每次上传前把 VERSION 加一。
# 4. 引擎和资源包另外压成 *.gz.bin：shell.html 在浏览器里边下边解压，不管服务器压不压缩，下载都小；
#    原文件留着给不支持解压的旧浏览器兜底。
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
OUT="${1:-../build/web}"
ZIP="$(dirname "$OUT")/scrap_rush_web.zip"
rm -rf "${OUT:?}"
mkdir -p "$OUT"
"$GODOT" --headless --export-release "Web" "$OUT/index.html"
python3 - "$OUT/index.js" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
old = """onloadprogress(reader, controller).then(function () {
					controller.close();
				});"""
new = """onloadprogress(reader, controller).then(function () {
					controller.close();
				}, function (err) {
					controller.error(err);
				});"""
if old not in s:
    sys.exit("index.js 里找不到下载器那段代码（Godot 版本变了？），补丁没打上")
open(p, "w").write(s.replace(old, new))
print("index.js：下载器出错重试的补丁已打上")
PY
VERSION="v$(tr -d '[:space:]' < web/VERSION) · $(TZ=Asia/Shanghai date '+%m.%d %H:%M')"
sed -i '' "s/__SCRAP_VERSION__/$VERSION/" "$OUT/index.html"
gzip -9 -c "$OUT/index.wasm" > "$OUT/index.wasm.gz.bin"
gzip -9 -c "$OUT/index.pck" > "$OUT/index.pck.gz.bin"
rm -f "$ZIP"
(cd "$OUT" && zip -q -r "../$(basename "$ZIP")" . -x '.DS_Store')
ls -la "$OUT" "$ZIP"
