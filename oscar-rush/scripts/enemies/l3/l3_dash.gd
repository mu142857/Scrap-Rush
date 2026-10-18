class_name L3Dash
extends Shaver
## 第三关的小怪，打法照搬剃须刀（晃一晃再冲），换成 cfg 里这只怪的贴图，按所在屏幕上色。见 L3Mob。

var cfg: Dictionary = {}
var tint := "color"
var mob_name := ""


func _setup() -> void:
	super._setup()
	L3Mob.apply_cfg(self, cfg)


func _after_ready() -> void:
	super._after_ready()
	L3Mob.apply_look(self, tint)


## 2026-10-18 作者试玩"没有压迫感"：剃须刀原来只看水平 160、高度 24 以内，人站在家具上或稍远一点
## 它就来回巡逻。第三关的看得更远、更高，在面前晃的时间也短一点，冲得更勤
func _sees(p: Player, dist: float, height: float) -> bool:
	return super._sees(p, dist * 2.2, height * 2.5)


func _start_circle() -> void:
	_state = CIRCLE
	_timer = randf_range(0.45, 0.85)
