extends Node
## 一局游戏的状态：谁在玩、水晶还剩多少血。跨关卡保留。

signal crystal_changed(hp: float, max_hp: float)
signal crystal_broken
signal parts_changed(parts: int)

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


func start_level() -> void:
	level_start_hp = crystal_hp
	level_start_parts = parts
	crystal_changed.emit(crystal_hp, crystal_max)


func retry_level() -> void:
	crystal_hp = level_start_hp
	parts = level_start_parts
	crystal_changed.emit(crystal_hp, crystal_max)


func damage_crystal(amount: float) -> void:
	if crystal_hp <= 0.0:
		return
	crystal_hp = maxf(crystal_hp - amount, 0.0)
	crystal_changed.emit(crystal_hp, crystal_max)
	if crystal_hp <= 0.0:
		crystal_broken.emit()


func add_emotion(amount: float) -> void:
	emotion = clampf(emotion + amount, 0.0, 100.0)


func add_part(n := 1) -> void:
	parts += n
	parts_changed.emit(parts)
