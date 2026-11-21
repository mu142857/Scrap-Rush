#!/bin/zsh
# 录一个镜头：./rec.sh 镜头名 输出文件.mp4
# 存档全部指到临时目录，不碰作者的设置、图鉴、继续游戏、进度。
set -e
SHOT=$1; OUT=$2
HERE=${0:a:h}
TMP=${TMPDIR:-/tmp}/oscar_rec_$$; mkdir -p $TMP
cp "$HOME/Library/Application Support/Godot/app_userdata/Scrap Rush/settings.cfg" $TMP/s.cfg 2>/dev/null || true
sed -i "" "s/^fullscreen=true/fullscreen=false/" $TMP/s.cfg 2>/dev/null || true
export SCRAP_LEVEL_INTRO=${SCRAP_LEVEL_INTRO:-1} SCRAP_ACHIEVE_PATH=$TMP/a.cfg SCRAP_NO_AUTOPAUSE=1
export REC_SHOT=$SHOT
export SCRAP_SETTINGS_PATH=$TMP/s.cfg SCRAP_BESTIARY_PATH=$TMP/b.cfg SCRAP_RUN_PATH=$TMP/run.cfg SCRAP_PROGRESS_PATH=$TMP/p.cfg
/Applications/Godot.app/Contents/MacOS/Godot --windowed --resolution 1920x1080 --position 0,0 \
  --write-movie $TMP/raw.avi --fixed-fps 60 --quit-after 43200 --log-file $TMP/godot.log \
  --path $HERE/.. res://video/rec.tscn
ffmpeg -y -loglevel error -i $TMP/raw.avi -c:v libx264 -crf 14 -preset slow -pix_fmt yuv420p -c:a aac -b:a 192k "$OUT"
echo "done $OUT  log=$TMP/godot.log"
