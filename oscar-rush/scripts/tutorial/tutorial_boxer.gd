class_name TutorialBoxer
extends Shaver
## 教学关厨房的发条拳击手（10-19 方案 2「训练靶场」）：打法照剃须刀（晃到你面前、收拳、往前冲一拳），
## 教"头上冒 ! 就躲"（后面所有精英出招前都冒 !）。比剃须刀慢、前摇长、打完歇得久，好让新手看清楚。
## 帧：0、1 走，2 收拳（前摇），3 出拳。贴图 草图/教学关/tutorial_mobs.py 画的。

const M := preload("res://scripts/tutorial/tutorial_mobs.gd")
const WINDUP_LONG := 0.7
const REST_LONG := 1.1

## 教学关看这个：第一次收拳时出提示
var wound_up := false


func _setup() -> void:
	super._setup()
	L3Mob.apply_cfg(self, M.MOBS["boxer"])
	max_hp = 100.0
	contact_damage = 10.0


func _after_ready() -> void:
	super._after_ready()
	L3Mob.apply_look(self, "color")


func _circle() -> void:
	var before := _state
	super._circle()
	if before == CIRCLE and _state == WINDUP:
		_timer = WINDUP_LONG
		wound_up = true
		# 剃须刀的 ! 只亮 0.35 秒，拉长到整个前摇
		for c in get_children():
			if c is EliteFx.WarnMark:
				c.life = WINDUP_LONG


func _dash() -> void:
	super._dash()
	if _state == REST:
		_timer = REST_LONG


func is_winding() -> bool:
	return not dead and _state == WINDUP
