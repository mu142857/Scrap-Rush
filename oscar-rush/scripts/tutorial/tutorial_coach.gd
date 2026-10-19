class_name TutorialCoach
extends L3Elite
## 教学关儿童房的精英「大陪练」（10-19 方案 2「训练靶场」，换掉原来借用的第一关布谷鸟钟）。
## 底子是第三关精英（L3Elite）的冲撞型，只留两招：冲撞、跳起砸地，轮着出；两招预警时都整只闪白、地上标出路线 / 落点。
## 不狂暴（教学关不该半血突然变快）。血量由教学关在出场后设（450，不吃难度倍率，和原来的布谷鸟钟一样）。

const M := preload("res://scripts/tutorial/tutorial_mobs.gd")


func _init() -> void:
	cfg = M.MOBS["coach"]
	mob_name = "coach"
	tint = "color"


func _setup() -> void:
	super._setup()
	arch = "charger"
	_tp = TYPE[arch]
	reveal_moves = ["charge", "slam"]


func _pick_move() -> void:
	_move = "slam" if _last_move == "charge" else "charge"
	_last_move = _move


func _enrage() -> void:
	pass
