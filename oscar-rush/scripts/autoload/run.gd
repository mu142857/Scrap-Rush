extends Node
## 一局游戏的状态：谁在玩、水晶还剩多少血。跨关卡保留。

signal crystal_changed(hp: float, max_hp: float)
signal crystal_broken
## 真正的回血（清场、灯油）：只有 heal_crystal 发。重来拉回存档血量、商店修灯不发
signal crystal_healed(amount: float)
signal parts_changed(parts: int)
## 从存档点重来、人已经挪到存档点以后发出（提示用）
signal resumed
## 打完遭遇战、存了档
signal checkpoint_saved
## 重来（马灯碎了、按 R、Boss 房重打）重载以后、人摆好了、重生动画开始放时发出；有没有存档点都发
signal respawned

## —— 难度（10-18 作者：「选择关卡的换成选择难度」）——
## 0 简单、1 普通（原来的数值）、2 困难。开始菜单选难度时设 Run.difficulty，存进存档；新开一局不重置（记住上次选的）。
## 所有地方读下面三个倍率：马灯受伤（damage_crystal）、怪 / 精英 / Boss 的血（EnemyBase、Crawler、BossArena）、马灯回血（heal_crystal）
const DIFFICULTY_NAMES: Array[String] = ["EASY", "NORMAL", "HARD"]
const DAMAGE_TAKEN_MULT: Array[float] = [0.6, 1.0, 1.3]
const ENEMY_HP_MULT: Array[float] = [0.8, 1.0, 1.3]
const HEAL_MULT: Array[float] = [1.0, 1.0, 0.7]
var difficulty := 1


func damage_taken_mult() -> float:
	return DAMAGE_TAKEN_MULT[clampi(difficulty, 0, 2)]


func enemy_hp_mult() -> float:
	return ENEMY_HP_MULT[clampi(difficulty, 0, 2)]


func heal_mult() -> float:
	return HEAL_MULT[clampi(difficulty, 0, 2)]


## 人越多，水晶血量越少（1~4 人）
const CRYSTAL_MAX_BY_PLAYERS: Array[float] = [100.0, 80.0, 65.0, 55.0]
const SKINS: Array[String] = ["red", "robot", "bird", "dino"]

## 每个玩家一条：{ "input": 输入前缀, "skin": 角色 }
var players: Array[Dictionary] = [{"input": "solo", "skin": "red"}]
var crystal_max := 100.0
var crystal_hp := 100.0
## 进这一关时的水晶血量。水晶碎了从本关开头重来，血量回到这个值
var level_start_hp := 100.0
var emotion := 0.0
## 零件（商店的货币，策划案第十节）。进关时记一下，本关重来时退回去，免得重复捡
var parts := 0
var level_start_parts := 0
## 存档点：每打完一场遭遇战记一次。马灯碎了（或按 R）从最近的存档点重来，不从整关开头。
## {scene, pos, hp, parts, cleared: 已经打完的遭遇战}。换关（不是重来）就清空
var checkpoint := {}
## 重来时马灯至少回到这么多（占满血的比例），免得带着一丝血进来、一碰就碎、死循环
const RETRY_MIN_HP := 0.35
var _resuming := false
## 打完遭遇战掉下来、还没捡的零件数：存档时算作已经拿到
var _drops := 0


func _ready() -> void:
	reset_run()
	_check_launch.call_deferred()


# —— 能不能写作者真正的存档（10-18 监督会话：各会话编译检查时直接开 test_level，进关自动存档覆盖了作者的 run.cfg）——
## 只有"正常开的游戏"才写 user:// 下的存档（run.cfg、图鉴、打到第几关）：
## 正式导出的游戏或编辑器里按运行，并且是从主场景（开始菜单）开起来的，并且不是 headless / 录像 / 带 -- 测试参数。
## 直接打开关卡场景、-s 测试脚本、命令行跑的测试一律不写（设了 SCRAP_*_PATH 的测试照常写到它们自己的文件）。
var _real_launch := false


func _check_launch() -> void:
	var cs := get_tree().current_scene
	var main := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main.begins_with("uid://"):
		main = ResourceUID.get_id_path(ResourceUID.text_to_id(main))
	var from_main := cs != null and cs.scene_file_path == main
	var proper := OS.has_feature("template")
	for a in OS.get_cmdline_args():
		if a == "--editor-pid" or a.begins_with("--remote-debug"):
			proper = true
	_real_launch = from_main and proper and DisplayServer.get_name() != "headless" \
			and Engine.get_write_movie_path() == "" and OS.get_cmdline_user_args().is_empty()


## 这次运行能不能写作者真正的存档文件（图鉴、打到第几关也用这个）
func real_launch() -> bool:
	return _real_launch


func reset_run() -> void:
	load("res://scripts/ui/achievements.gd").call("on_run_start")   # 成就：清这一局的记录（立绘添加会话，10-18）
	Upgrades.reset()
	crystal_max = CRYSTAL_MAX_BY_PLAYERS[clampi(players.size(), 1, 4) - 1]
	crystal_hp = crystal_max
	level_start_hp = crystal_hp
	emotion = 0.0
	parts = 0
	level_start_parts = 0
	checkpoint = {}
	_resuming = false
	# 上一局"重来"留下的静态标记（2026-10-17 夜间，游戏细节讨论会话）：不清的话，新一局第一次进 Boss 房
	# 会被当成重来、跳过入场；气动管会从上一局的存档点开始
	# 用 load 在运行时找脚本，不写成 BossArena / TubeRun：Run 是自动加载，直接引用会把第二关、Boss 房的
	# 脚本和美术全拖进来，那边有一张图没导入，整个游戏就编译不过
	_reset_static("res://scripts/boss/boss_arena.gd", "_retried_scene", "")
	_reset_static("res://scripts/levels/tube_run.gd", "resume_d", 0.0)
	_reset_static("res://scripts/ui/hud.gd", "fights_cleared", 0)
	# 三关的开场动画：新一局每关第一次进都要再播（LevelIntro 按场景记播过没有）
	_reset_static("res://scripts/ui/level_intro.gd", "_played", {})


func _reset_static(path: String, prop: String, value: Variant) -> void:
	var script := load(path) as GDScript
	if script:
		script.set(prop, value)


## 每关 _ready 一开头调用。重来时（retry_level 之后的重载）保留存档点，等关卡建好再把人挪过去
func start_level() -> void:
	crystal_locked = false
	var retrying := _resuming
	if _resuming and checkpoint.get("scene", "") == _scene_path():
		_drops = 0
		_apply_checkpoint.call_deferred()
	else:
		checkpoint = {}
		_drops = 0
		level_start_hp = crystal_hp
		level_start_parts = parts
		# 每进一关存一次（只在三关的第一个场景，重来不存）
		if LEVEL_START_SCENES.has(_scene_path()):
			save_run()
	_resuming = false
	crystal_changed.emit(crystal_hp, crystal_max)
	# 重来的话放重生动画。call_deferred 按顺序跑，排在 _apply_checkpoint 后面：人先挪到存档点再放
	if retrying:
		_play_respawn.call_deferred()


## 重生动画（RespawnFx）：画面从黑亮起来，光柱打到每个主角身上，人从光里出来
func _play_respawn() -> void:
	var root := get_tree().current_scene
	if root == null or get_tree().get_nodes_in_group("player").is_empty():
		return
	root.add_child(RespawnFx.new())
	respawned.emit()


func retry_level() -> void:
	_resuming = true
	if checkpoint.get("scene", "") == _scene_path():
		crystal_hp = checkpoint["hp"]
		parts = checkpoint["parts"]
	else:
		crystal_hp = level_start_hp
		parts = level_start_parts
	crystal_hp = maxf(crystal_hp, crystal_max * RETRY_MIN_HP)
	crystal_changed.emit(crystal_hp, crystal_max)


## 忘掉这一关的存档点：暂停菜单的"重开本关"用，接着 retry_level 就回到本关开头（马灯、零件回到进关时）。
## 按 R 和马灯碎了不调它，回的是最近的存档点。
func forget_checkpoint() -> void:
	checkpoint = {}
	_drops = 0


## 遭遇战打完时调用：key 是这场的编号，pos 是重来时站的地方（场子里出口那一侧）
func save_checkpoint(key: String, pos: Vector2) -> void:
	var scene := _scene_path()
	# 第二关的胶片天桥是自动卷轴，天桥和后半段不能从中间重来：只在天桥之前存
	var root := get_tree().current_scene
	if root and root.get_script():
		var limit = (root.get_script() as Script).get_script_constant_map().get("BRIDGE_TRIGGER")
		if limit != null and pos.x > float(limit):
			return
	if checkpoint.get("scene", "") != scene:
		checkpoint = {"scene": scene, "cleared": []}
	checkpoint["pos"] = pos
	checkpoint["hp"] = crystal_hp
	# 场子中间掉的零件还没捡也算已经拿到（重来时那几场不会再掉）
	_drops += 1
	checkpoint["parts"] = parts + _drops
	(checkpoint["cleared"] as Array).append(key)
	checkpoint_saved.emit()


## 这场遭遇战在存档点里是不是已经打完了（重来时它就直接是打完的样子）
func is_cleared(key: String) -> bool:
	return checkpoint.get("scene", "") == _scene_path() and (checkpoint.get("cleared", []) as Array).has(key)


func _scene_path() -> String:
	var root := get_tree().current_scene
	return root.scene_file_path if root else ""


func _apply_checkpoint() -> void:
	var pos: Vector2 = checkpoint["pos"]
	var i := 0
	for p in get_tree().get_nodes_in_group("player"):
		var pl := p as CharacterBody2D
		pl.global_position = pos + Vector2(i * 12, 0)
		pl.velocity = Vector2.ZERO
		pl.reset_physics_interpolation()
		i += 1
	for c in get_tree().get_nodes_in_group("crystal"):
		if c.get("carrier") == null:
			(c as Node2D).global_position = pos
			(c as Node2D).reset_physics_interpolation()
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("snap"):
		cam.call("snap")
	resumed.emit()


## Boss 打死以后锁住马灯（结局、开门的那几秒里，还在飞的子弹和场上的危险物不能再把灯打碎、把人踢回 Boss 开场）
var crystal_locked := false


func damage_crystal(amount: float) -> void:
	if crystal_hp <= 0.0 or Game.invincible or crystal_locked:
		return
	crystal_hp = maxf(crystal_hp - amount * damage_taken_mult(), 0.0)
	crystal_changed.emit(crystal_hp, crystal_max)
	if crystal_hp <= 0.0:
		# 倒带磁带（变异）：这一关还没用过，就倒回 5 秒前，不碎（商店会话 10-18 加的一行）
		if Mutations.try_rewind():
			return
		crystal_broken.emit()


## 马灯回血（清场回血、灯油、商店修灯都可以走这里），不超过上限
func heal_crystal(amount: float) -> void:
	if crystal_hp <= 0.0 or amount <= 0.0:
		return
	var before := crystal_hp
	crystal_hp = minf(crystal_hp + amount * heal_mult(), crystal_max)
	crystal_changed.emit(crystal_hp, crystal_max)
	if crystal_hp > before:
		crystal_healed.emit(crystal_hp - before)


func add_emotion(amount: float) -> void:
	emotion = clampf(emotion + amount, 0.0, 100.0)


func add_part(n := 1) -> void:
	parts += n
	_drops = maxi(_drops - n, 0)
	parts_changed.emit(parts)



# —— 存档（10-18 作者：「每进一关存一次」，开始菜单的「继续」从最远那关的开头接着打）——
## 存在 user://run.cfg；测试时设环境变量 SCRAP_RUN_PATH=别的文件，不碰作者的存档。
## 存：难度、到了第几关（和那关开头的场景）、零件、四项升级、变异、马灯血量（占满血的比例）、每个玩家（输入方案、角色、武器）、
## 这一局的统计（时间、死了几次、花了多少零件）。
## 给开始菜单用：has_save() 有没有存档、save_info() 读出来显示（第几关、难度、几个人）、continue_run() 恢复并返回要进的场景。

const SAVE_VERSION := 1
## 三关各自的第一个场景 → 第几关（第二关从气动管开始）
const LEVEL_START_SCENES := {"res://scenes/test_level.tscn": 1, "res://scenes/level2_tube.tscn": 2, "res://scenes/level3.tscn": 3}


func save_path() -> String:
	var env := OS.get_environment("SCRAP_RUN_PATH")
	return env if env != "" else "user://run.cfg"


## 进关时自动调（start_level 里）；别处一般不用调。没设 SCRAP_RUN_PATH 又不是正常开的游戏（直接开关卡、测试）就不写
func save_run() -> void:
	if OS.get_environment("SCRAP_RUN_PATH") == "" and not _real_launch:
		return
	var scene := _scene_path()
	var c := ConfigFile.new()
	c.set_value("run", "version", SAVE_VERSION)
	c.set_value("run", "difficulty", difficulty)
	c.set_value("run", "level", int(LEVEL_START_SCENES.get(scene, 1)))
	c.set_value("run", "scene", scene)
	c.set_value("run", "parts", parts)
	c.set_value("run", "hp_ratio", crystal_hp / maxf(crystal_max, 1.0))
	c.set_value("run", "upgrades", Upgrades.levels.duplicate())
	c.set_value("run", "mutation", Upgrades.mutation)
	c.set_value("run", "weapon", Upgrades.weapon)
	var ps: Array = []
	for e in players:
		ps.append({"input": e.get("input", "solo"), "skin": e.get("skin", "red"), "weapon": e.get("weapon", Upgrades.weapon)})
	c.set_value("run", "players", ps)
	c.set_value("run", "stats", Game.run_stats.duplicate())
	c.set_value("run", "saved_at", Time.get_datetime_string_from_system())
	c.save(save_path())


func has_save() -> bool:
	var c := ConfigFile.new()
	return c.load(save_path()) == OK and int(c.get_value("run", "version", 0)) == SAVE_VERSION


## 给开始菜单显示用：{level: 1~3, difficulty: 0~2, players: 人数, weapons: [每人的武器 id], saved_at}；没有存档返回 {}
func save_info() -> Dictionary:
	var c := ConfigFile.new()
	if c.load(save_path()) != OK:
		return {}
	var ps: Array = c.get_value("run", "players", [])
	return {"level": int(c.get_value("run", "level", 1)), "difficulty": int(c.get_value("run", "difficulty", 1)),
		"players": ps.size(), "weapons": ps.map(func(e): return e.get("weapon", "flash")),
		"saved_at": str(c.get_value("run", "saved_at", ""))}


## 「继续」：把存档读回来（难度、人、武器、零件、升级、变异、马灯），返回要进的场景路径（那关的开头）；
## 调的人负责切过去（SceneFade.go）。没有存档返回 ""
func continue_run() -> String:
	var c := ConfigFile.new()
	if c.load(save_path()) != OK:
		return ""
	var ps: Array = c.get_value("run", "players", [])
	if not ps.is_empty():
		var restored: Array[Dictionary] = []
		for e in ps:
			restored.append({"input": e.get("input", "solo"), "skin": e.get("skin", "red"), "weapon": e.get("weapon", "flash")})
		players = restored
	reset_run()
	difficulty = int(c.get_value("run", "difficulty", 1))
	var ups: Dictionary = c.get_value("run", "upgrades", {})
	for k in ups:
		Upgrades.levels[k] = int(ups[k])
	Upgrades.mutation = str(c.get_value("run", "mutation", ""))
	# reset_run 会清掉每人的武器：从存档里再放回去
	for i in mini(players.size(), ps.size()):
		players[i]["weapon"] = ps[i].get("weapon", "flash")
	Upgrades.weapon = players[0].get("weapon", str(c.get_value("run", "weapon", "flash"))) if not players.is_empty() else "flash"
	parts = int(c.get_value("run", "parts", 0))
	crystal_hp = crystal_max * clampf(float(c.get_value("run", "hp_ratio", 1.0)), 0.1, 1.0)
	level_start_hp = crystal_hp
	level_start_parts = parts
	var st = c.get_value("run", "stats", null)
	if st is Dictionary:
		for k in st:
			Game.run_stats[k] = st[k]
	parts_changed.emit(parts)
	crystal_changed.emit(crystal_hp, crystal_max)
	return str(c.get_value("run", "scene", "res://scenes/test_level.tscn"))


## 删掉存档（通关、或者开始菜单里玩家选了「新游戏」并确认覆盖时可以调）
func clear_save() -> void:
	if OS.get_environment("SCRAP_RUN_PATH") == "" and not _real_launch:
		return
	if FileAccess.file_exists(save_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path()) if save_path().begins_with("user://") else save_path())
