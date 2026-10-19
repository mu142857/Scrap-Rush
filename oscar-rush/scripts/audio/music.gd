class_name Music
extends Node
## 背景音乐（2026-10-18，本2兔的两首；游戏细节讨论会话接的）。挂在 Game 下面，换场景也一直在，所以同一首跨场景不断。
##   backhome（"home"）：安静、稀疏 → 开始界面、选难度 / 选武器、商店、结算、制作人员，以及第三关走到最后的家里（"This is it... just like the tape."）
##   back_to_the_game（"game"）：120 BPM、低音推着走 → 三关、气动管、三个 Boss 房
## 两首都是处理好的整段循环（tools/gen_music.py：22050Hz 立体声，按小节切、首尾无缝），QOA 导入，循环点按采样数设。
## 换曲：两个播放器交叉淡入淡出（等功率，XFADE 秒）。同一首就不重开，接着放。
## 暂停菜单开着时（Music 总线的低通开着，Settings.set_muffled）再压低 PAUSE_DB。
## 音乐响着的时候，环境声让位（Ambience.duck_db = AMB_DUCK_DB）；设置里音乐关到 0 就不让。
## 走 Music 总线，设置里的"音乐"一档管它。

const BUS := &"Music"
const XFADE := 1.8
const PAUSE_DB := -6.0
const AMB_DUCK_DB := -8.0
const OFF_DB := -60.0
## 曲目：[文件, 循环长度（22050Hz 下的采样数）, 音量修正 dB]
const TRACKS := {
	"home": ["res://music/backhome.ogg", 1411200, 0.0],
	"game": ["res://music/back_to_the_game.ogg", 1587600, -2.0],
}
## 场景 → 曲目（第二关、第三关的主场景按区域再细分，见 _want）
const SCENES := {
	"res://scenes/title.tscn": "home", "res://scenes/weapon_select.tscn": "home",
	"res://scenes/shop.tscn": "home", "res://scenes/results.tscn": "home",
	"res://scenes/test_level.tscn": "game", "res://scenes/boss1.tscn": "game",
	"res://scenes/level2_tube.tscn": "game", "res://scenes/level2.tscn": "game", "res://scenes/boss2.tscn": "game",
	"res://scenes/level3.tscn": "game", "res://scenes/boss3.tscn": "game",
}
## 不按场景、强行放这首（制作人员页叠在开始界面上时用 "home"）。空 = 照常
static var override := ""

var track := ""
var _players := {}
## 每个播放器现在的淡入进度 0~1（等功率曲线算音量）
var _k := {}
var _last_ticks := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_last_ticks = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	# 按真实时间走：顿帧、暂停时淡入淡出也照常
	var now := Time.get_ticks_msec()
	var dt := minf((now - _last_ticks) / 1000.0, 0.1)
	_last_ticks = now
	var want := _want()
	if want != "" and want != track:
		track = want
		_player(track)
	var muffled := _muffled()
	for name in _players.keys():
		var p: AudioStreamPlayer = _players[name]
		var k: float = _k[name]
		k = move_toward(k, 1.0 if name == track else 0.0, dt / XFADE)
		_k[name] = k
		if k <= 0.0 and name != track:
			p.queue_free()
			_players.erase(name)
			_k.erase(name)
			continue
		# 等功率：淡入用 sin、淡出也是同一条曲线反着走，交叉时总响度不塌
		var amp := sin(k * PI * 0.5)
		p.volume_db = linear_to_db(maxf(amp, 0.001)) + float(TRACKS[name][2]) + (PAUSE_DB if muffled else 0.0)
	Ambience.duck_db = AMB_DUCK_DB if (track != "" and Settings.music > 0) else 0.0


func _want() -> String:
	if override != "":
		return override
	var cur := get_tree().current_scene
	if cur == null:
		return ""
	var path := cur.scene_file_path
	if not SCENES.has(path):
		return ""   # 不认识的场景（测试场景、过渡）：照旧放现在这首
	var t: String = SCENES[path]
	# 第三关走到最后的家：换成 backhome（和环境声的 "home" 区域同一条线）
	if path == "res://scenes/level3.tscn":
		for p in get_tree().get_nodes_in_group("player"):
			if (p as Node2D).global_position.x > Ambience.HOME_X:
				return "home"
			break
	return t


func _muffled() -> bool:
	var i := AudioServer.get_bus_index(BUS)
	return i >= 0 and AudioServer.get_bus_effect_count(i) > 0 and AudioServer.is_bus_effect_enabled(i, 0)


func _player(name: String) -> AudioStreamPlayer:
	if _players.has(name):
		return _players[name]
	var info: Array = TRACKS[name]
	# 10-19（游戏设计会话）：作者"游戏还是声音卡顿"。网页版改用 Sample 方式放声音（浏览器自己混音，不跟着画面卡），
	# QOA 压缩的 wav 在 Sample 方式下是哑的，所以音乐换成 ogg（原 wav 留在 music/ 里，不再加载）
	var s := load(info[0]) as AudioStream
	if s == null:
		return null
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.bus = BUS
	p.volume_db = OFF_DB
	add_child(p)
	p.play()
	_players[name] = p
	_k[name] = 0.0
	return p
