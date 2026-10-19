class_name Ambience
extends Node
## 各区域的环境声（2026-10-17 夜间打磨，游戏细节讨论会话）。挂在 Game 下面，换场景也一直在。
## 每个区域 = 几层循环底噪（sfx/amb_*.wav，tools/gen_ambience.py 合成的）+ 隔一阵随机响一下的点缀（工程里现有的音效）。
## 走到别的区域时各层慢慢淡入淡出。全部走 Ambience 总线：设置里"环境声"一格管音量，暂停时和音乐、音效一起闷掉。
## 音量都很低（底噪约 -34 dB），不盖过战斗音效。背景音乐以后由作者加，走 Music 总线，和这里互不影响。
##
## 区域怎么分：看当前场景；第二关按主角 x 分交换局 / 胶片走廊 / 电影院；第三关走到最后的家（x > 3820）变成风声。

const BUS := &"Ambience"
## 淡入淡出用的时间（秒）
const FADE := 1.2
## 全部再压低这么多（2026-10-18 早上作者嫌吵："场景里有蒸汽的白噪音，很吵"）。
## 同时：循环重新合成成只剩低沉的嗡鸣（tools/gen_ambience.py），蒸汽、雪花这类嘶嘶的点缀删掉了
const GLOBAL_DB := -4.0
## 点缀（铃声、咔哒）再额外轻一点
const BITS_DB := -4.0
## 关掉的层淡到这么低就停掉
const OFF_DB := -60.0
const HOME_X := 3820.0

## 第二关交换局的四间机房：在房间里时铃声、继电器声响一点（+4 dB）
const EXCHANGE_ROOMS: Array[Rect2] = [Rect2(40, 440, 380, 100), Rect2(532, 340, 368, 90), Rect2(52, 150, 388, 100), Rect2(560, 200, 440, 100)]
const ROOM_BOOST := 4.0

## 区域 → { loops: [[循环名, 音量 dB], ...], bits: [[音效, 最小 dB, 最大 dB, 最低音高, 最高音高, 最短间隔, 最长间隔], ...] }
const ZONES := {
	"title": {"loops": [["factory", -26.0]], "bits": []},
	"level1": {"loops": [["factory", -16.0]], "bits": [
		["clang", -36.0, -30.0, 0.5, 0.75, 9.0, 20.0],
	]},
	"boss1": {"loops": [["boiler", -15.0]], "bits": []},
	"exchange": {"loops": [["exchange", -17.0]], "bits": [
		["bell", -36.0, -30.0, 0.9, 1.25, 8.0, 18.0],
		["dial", -30.0, -25.0, 0.8, 1.3, 1.5, 4.5],
		["tvclick", -34.0, -28.0, 1.5, 1.9, 3.0, 7.0],
	]},
	# 胶片天桥：放映机的咔嗒 level2.gd 自己会放（_clatter，只在胶片卷动时响），这里只给一点空旷的风
	"film": {"loops": [["wind", -24.0], ["exchange", -30.0]], "bits": []},
	# 放映间小屋（离放映机最近）和观众大厅（远、轻）
	"booth": {"loops": [["projector", -14.0]], "bits": [["tvclick", -32.0, -28.0, 0.7, 0.9, 5.0, 10.0]]},
	"hall": {"loops": [["projector", -25.0], ["wind", -30.0]], "bits": [["tvclick", -38.0, -34.0, 0.6, 0.8, 8.0, 16.0]]},
	"boss2": {"loops": [["exchange", -18.0]], "bits": [["bell", -36.0, -31.0, 0.8, 1.0, 10.0, 20.0]]},
	"level3": {"loops": [["tv", -18.0]], "bits": []},
	"home": {"loops": [["wind", -16.0]], "bits": []},
	"boss3": {"loops": [["tv", -24.0]], "bits": []},
	"shop": {"loops": [["fire", -14.0], ["factory", -30.0]], "bits": []},
	"results": {"loops": [["wind", -24.0]], "bits": []},
	# 制作人员（CreditsMenu）：空旷的风，底下一点很远的炉火
	"credits": {"loops": [["wind", -22.0], ["fire", -32.0]], "bits": []},
	"": {"loops": [], "bits": []},
}
const SCENE_ZONES := {
	"res://scenes/title.tscn": "title", "res://scenes/weapon_select.tscn": "title",
	"res://scenes/test_level.tscn": "level1", "res://scenes/boss1.tscn": "boss1",
	# 气动管开场有自己的风声（level2_tube_wind.wav，跟胶囊速度走），这里不叠
	"res://scenes/level2_tube.tscn": "", "res://scenes/boss2.tscn": "boss2",
	"res://scenes/boss3.tscn": "boss3", "res://scenes/shop.tscn": "shop", "res://scenes/results.tscn": "results",
}

var zone := ""
## 背景音乐响着时环境声整体让位多少（dB，Music 每帧设）。音乐和这些低沉的嗡鸣在同一个频段，不让会糊
static var duck_db := 0.0
## 各区域的空间感：Ambience 总线上的混响（Settings 建总线时加在第 1 格）。克制：湿声都在 0.2 以下，
## 锅炉房大而硬、交换局中等偏干、屏幕世界小而亮、商店小而暖、家里贴近，制作人员最空旷。[房间大小, 阻尼, 湿声]
const ROOMS := {
	"title": [0.6, 0.45, 0.12], "level1": [0.78, 0.3, 0.18], "boss1": [0.85, 0.3, 0.2],
	"exchange": [0.45, 0.55, 0.11], "film": [0.6, 0.45, 0.13], "booth": [0.3, 0.6, 0.08], "hall": [0.7, 0.4, 0.16],
	"boss2": [0.55, 0.5, 0.14], "level3": [0.28, 0.25, 0.08], "boss3": [0.35, 0.3, 0.1], "home": [0.32, 0.65, 0.07],
	"shop": [0.3, 0.7, 0.06], "results": [0.6, 0.5, 0.12], "credits": [0.9, 0.4, 0.2], "": [0.4, 0.5, 0.0],
}
## 不按场景、强行用这个区域（制作人员页叠在开始界面上时用）。空 = 照常按场景
static var override := ""
## 循环名 → AudioStreamPlayer
var _loops := {}
## 循环名 → 现在的音量（dB）。按分贝匀速变化，听起来是均匀的淡入淡出
var _db := {}
var _bit_t: Array[float] = []
var _last_ticks := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ticks = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	# 按真实时间走：顿帧（time_scale = 0）时淡入淡出也不卡住
	var now := Time.get_ticks_msec()
	var dt := minf((now - _last_ticks) / 1000.0, 0.1)
	_last_ticks = now
	var z := _current_zone()
	if z != zone:
		zone = z
		_apply_room(zone)
		_bit_t.clear()
		for b in ZONES[zone]["bits"]:
			_bit_t.append(randf_range(b[5], b[6]) * 0.5)
	_fade_loops(dt)
	if not get_tree().paused:
		_tick_bits(dt)


## 换区域时调混响参数（Ambience 总线第 1 格的 AudioEffectReverb）
func _apply_room(z: String) -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0 or AudioServer.get_bus_effect_count(i) < 2:
		return
	var rv := AudioServer.get_bus_effect(i, 1) as AudioEffectReverb
	if rv == null:
		return
	var r: Array = ROOMS.get(z, ROOMS[""])
	rv.room_size = r[0]
	rv.damping = r[1]
	rv.wet = r[2]
	rv.dry = 1.0
	rv.spread = 0.8


func _current_zone() -> String:
	if override != "":
		return override
	var cur := get_tree().current_scene
	if cur == null:
		return ""
	var path := cur.scene_file_path
	if SCENE_ZONES.has(path):
		return SCENE_ZONES[path]
	var x := _lead_x()
	if path == "res://scenes/level2.tscn":
		# 第二关（分区和第二关会话 10-17 夜里对过，见 夜间打磨/第二关_报告.md 第 31 条）：
		# x < 1000 交换局（坐气动管穿行那几秒压低），1000~2840 胶片天桥，2840~3116 放映间，再往后观众大厅
		if x < 1000.0:
			return "" if bool(cur.get("_transit")) else "exchange"
		if x < 2840.0:
			return "film"
		return "booth" if x < 3116.0 else "hall"
	if path == "res://scenes/level3.tscn":
		return "home" if x > HOME_X else "level3"
	return ""


func _in_room() -> bool:
	for p in get_tree().get_nodes_in_group("player"):
		var at := (p as Node2D).global_position
		for r in EXCHANGE_ROOMS:
			if r.has_point(at):
				return true
		return false
	return false


func _lead_x() -> float:
	for p in get_tree().get_nodes_in_group("player"):
		return (p as Node2D).global_position.x
	return 0.0


func _fade_loops(dt: float) -> void:
	var want := {}
	for l in ZONES[zone]["loops"]:
		want[l[0]] = float(l[1]) + GLOBAL_DB + duck_db
	var names := _db.keys()
	for n in want:
		if not n in names:
			names.append(n)
	# 每秒走这么多分贝：从关着（-60）到 -16 左右大约 FADE 秒
	var rate := (absf(OFF_DB) - 16.0) / FADE * dt
	for n in names:
		var target: float = want.get(n, OFF_DB)
		var d: float = _db.get(n, OFF_DB)
		d = move_toward(d, target, rate)
		_db[n] = d
		if d <= OFF_DB and target <= OFF_DB:
			if _loops.has(n):
				(_loops[n] as AudioStreamPlayer).queue_free()
				_loops.erase(n)
			_db.erase(n)
			continue
		_player(n).volume_db = d


func _player(n: String) -> AudioStreamPlayer:
	if _loops.has(n):
		return _loops[n]
	var p := AudioStreamPlayer.new()
	p.stream = load("res://sfx/amb_%s.wav" % n)
	p.bus = BUS
	p.volume_db = -80.0
	add_child(p)
	# 每层从循环里的随机位置开始，几层叠在一起不会每次都一个样
	p.play(randf_range(0.0, 7.5))
	_loops[n] = p
	return p


func _tick_bits(dt: float) -> void:
	var bits: Array = ZONES[zone]["bits"]
	for i in mini(bits.size(), _bit_t.size()):
		_bit_t[i] -= dt
		if _bit_t[i] > 0.0:
			continue
		var b: Array = bits[i]
		_bit_t[i] = randf_range(b[5], b[6])
		var p := AudioStreamPlayer.new()
		p.stream = Game.load_sound(b[0])
		p.bus = BUS
		p.volume_db = randf_range(b[1], b[2]) + Game.SFX_TRIM.get(b[0], 0.0) + GLOBAL_DB + BITS_DB + duck_db + (ROOM_BOOST if zone == "exchange" and _in_room() else 0.0)
		p.pitch_scale = randf_range(b[3], b[4])
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
