class_name TutorialMoth
extends Moth
## 教学关阁楼的发条铁皮蛾（10-19 方案 2「训练靶场」）：放下马灯以后从屋顶飞下来扑地上的灯，教"放下的灯会挨打"。
## 打法就是扑灯蛾（扑最亮的东西），血少，一下就掉。阁楼是琥珀屏，按琥珀色调上色。

const M := preload("res://scripts/tutorial/tutorial_mobs.gd")


func _setup() -> void:
	super._setup()
	L3Mob.apply_cfg(self, M.MOBS["tinmoth"])
	max_hp = 50.0
	contact_damage = 8.0


func _after_ready() -> void:
	super._after_ready()
	L3Mob.apply_look(self, "amber")
