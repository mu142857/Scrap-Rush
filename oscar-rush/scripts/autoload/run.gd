extends Node
## 一局游戏的状态：谁在玩、水晶还剩多少血。跨关卡保留。

signal crystal_changed(hp: float, max_hp: float)
signal crystal_broken
signal parts_changed(parts: int)
## 从存档点重来、人已经挪到存档点以后发出（提示用）
signal resumed
## 打完遭遇战、存了档
signal checkpoint_saved
## 重来（马灯碎了、按 R、Boss 房重打）重载以后、人摆好了、重生动画开始放时发出；有没有存档点都发
signal respawned

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


func reset_run() -> void:
	Upgrades.reset()
	crystal_max = CRYSTAL_MAX_BY_PLAYERS[clampi(players.size(), 1, 4) - 1]
	crystal_hp = crystal_max
	level_start_hp = crystal_hp
	emotion = 0.0
	parts = 0
	level_start_parts = 0
	checkpoint = {}
	_resuming = false


## 每关 _ready 一开头调用。重来时（retry_level 之后的重载）保留存档点，等关卡建好再把人挪过去
func start_level() -> void:
	var retrying := _resuming
	if _resuming and checkpoint.get("scene", "") == _scene_path():
		_drops = 0
		_apply_checkpoint.call_deferred()
	else:
		checkpoint = {}
		_drops = 0
		level_start_hp = crystal_hp
		level_start_parts = parts
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


func damage_crystal(amount: float) -> void:
	if crystal_hp <= 0.0 or Game.invincible:
		return
	crystal_hp = maxf(crystal_hp - amount, 0.0)
	crystal_changed.emit(crystal_hp, crystal_max)
	if crystal_hp <= 0.0:
		crystal_broken.emit()


func add_emotion(amount: float) -> void:
	emotion = clampf(emotion + amount, 0.0, 100.0)


func add_part(n := 1) -> void:
	parts += n
	_drops = maxi(_drops - n, 0)
	parts_changed.emit(parts)
