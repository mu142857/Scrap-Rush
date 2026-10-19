#!/bin/zsh
# 碰撞 / 地形 / 遭遇战回归测试一键跑（夜间打磨，碰撞会话写的）。改了碰撞、关卡、遭遇战、怪的移动以后跑一遍。
# 用法（在 oscar-rush 目录下）：  tools/qa/run_all.sh <放日志的目录> [quick]
#   quick：每项少跑几次（约 8 分钟）；不加：完整版（约 40 分钟）
# 规则（夜间打磨/规则.md）：一次只开一个 Godot；日志写到自己的目录；看到第一个 SCRIPT ERROR / Parse Error 就停下。
# 每项只打印一行汇总；细节在 <目录>/<项目名>.out 里。

OUT=${1:?"用法：tools/qa/run_all.sh <放日志的目录> [quick]"}
QUICK=$2
mkdir -p "$OUT"
# 规则（夜间打磨/规则.md）：测试不碰作者真正的设置和图鉴存档，都写到日志目录里
export SCRAP_SETTINGS_PATH="$OUT/settings.cfg" SCRAP_BESTIARY_PATH="$OUT/bestiary.cfg" SCRAP_RUN_PATH="$OUT/run.cfg"
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
cd "$(dirname "$0")/../.." || exit 1

n() { [[ "$QUICK" == "quick" ]] && echo $1 || echo $2; }

run() {  # run <名字> <超时秒> <汇总行的 grep 模式> <godot 参数...>
  local name=$1 t=$2 pat=$3; shift 3
  rm -f "$OUT/$name.out"
  $GODOT --log-file "$OUT/$name.log" "$@" > "$OUT/$name.out" 2>&1 &
  local pid=$!
  for i in $(seq 1 $t); do
    sleep 1
    kill -0 $pid 2>/dev/null || break
    if grep -q -E "SCRIPT ERROR|Parse Error" "$OUT/$name.out" 2>/dev/null; then kill $pid; echo "[$name] 脚本报错，已停：$(grep -m1 -A1 -E 'SCRIPT ERROR|Parse Error' "$OUT/$name.out" | tr '\n' ' ')"; return; fi
  done
  kill -0 $pid 2>/dev/null && { kill $pid; echo "[$name] 超时（${t}s）"; return; }
  echo "[$name] $(grep -E "$pat" "$OUT/$name.out" | tail -1)"
}

LEVEL=res://scenes/test_level.tscn BOUNDS=0,0,1006,426 TRIALS=$(n 60 200) SEED=1 run terrain_l1 600 "^FUZZ" --headless --fixed-fps 120 --path . -s tools/qa/terrain_fuzz.gd
LEVEL=res://scenes/level3.tscn BOUNDS=0,0,4994,1200 TRIALS=$(n 60 250) SEED=3 run terrain_l3 900 "^FUZZ" --headless --fixed-fps 120 --path . -s tools/qa/terrain_fuzz.gd
for b in 1 2 3; do
  LEVEL=res://scenes/boss$b.tscn BOUNDS=0,0,320,180 TRIALS=$(n 20 80) SEED=$b run terrain_boss$b 300 "^FUZZ" --headless --fixed-fps 120 --path . -s tools/qa/terrain_fuzz.gd
done
LEVEL=res://scenes/test_level.tscn BOUNDS=0,0,1006,426 SET=encounter TRIALS_PER_KIND=$(n 2 6) SEED=1 run mobs_l1 900 "^MOBFUZZ DONE" --headless --fixed-fps 120 --path . -s tools/qa/mob_fuzz.gd
LEVEL=res://scenes/level3.tscn BOUNDS=0,0,4994,1200 SET=l3 TRIALS_PER_KIND=$(n 1 3) SEED=5 run mobs_l3 1500 "^MOBFUZZ DONE" --headless --fixed-fps 120 --path . -s tools/qa/mob_fuzz.gd
for L in "test_level|0,0,1006,426" "level2|0,0,3700,600" "level3|0,0,4994,1200"; do
  LEVEL=res://scenes/${L%%|*}.tscn BOUNDS=${L##*|} TRIALS=$(n 30 120) SEED=4 run lantern_${L%%|*} 400 "^LANTERN" --headless --fixed-fps 120 --path . -s tools/qa/lantern_fuzz.gd
done
# 击杀碎片、血 / 机油溅会不会卡进墙、停在半空、出地图、删不掉（10-18）
for L in "test_level|0,0,1006,426" "level2|0,0,3700,600" "level3|0,0,4994,1200" "boss3|0,0,320,180"; do
  LEVEL=res://scenes/${L%%|*}.tscn BOUNDS=${L##*|} TRIALS=$(n 40 120) SEED=1 run debris_${L%%|*} 400 "^DEBRIS DONE" --headless --fixed-fps 120 --path . -s tools/qa/debris_fuzz.gd
  grep -E "^DEBRIS .*: n=" "$OUT/debris_${L%%|*}.out" | sed 's/^/    /'
done
run gate_coop 120 "^CASE" --headless --fixed-fps 120 --path . -s tools/qa/gate_coop.gd -- --players=2
grep -E "^CASE" "$OUT/gate_coop.out" | sed 's/^/    /'
run gate_outside 120 "^C after" --headless --fixed-fps 120 --path . -s tools/qa/gate_outside.gd
grep -E "^[AB] after" "$OUT/gate_outside.out" | sed 's/^/    /'
for side in right left; do
  LEVEL=res://scenes/level2.tscn SIDE=$side run gate_escape_l2_$side 500 "^ESCAPE DONE" --headless --fixed-fps 120 --path . -s tools/qa/gate_escape.gd
done
run encounter_death 240 "^3 " --headless --fixed-fps 120 --path . -s tools/qa/encounter_death.gd
grep -E "^[123] " "$OUT/encounter_death.out" | sed 's/^/    /'
LEVEL=res://scenes/test_level.tscn BOUNDS=0,0,1006,426 run checkpoints_l1 300 "^CHECKPOINTS DONE" --headless --fixed-fps 120 --path . -s tools/qa/checkpoint_all.gd
LEVEL=res://scenes/level3.tscn BOUNDS=0,0,4994,1200 run checkpoints_l3 900 "^CHECKPOINTS DONE" --headless --fixed-fps 120 --path . -s tools/qa/checkpoint_all.gd
run route_bot1 600 "^BOT (reached|STUCK)" --headless --fixed-fps 120 --path . -s tools/qa/route_bot1.gd
STEP_TIMEOUT=300 run route_bot3 1500 "^BOT (reached|STUCK)" --headless --fixed-fps 120 --path . -s tools/qa/route_bot3.gd
echo "全部跑完。看不懂哪一项就打开 $OUT/<名字>.out。"
