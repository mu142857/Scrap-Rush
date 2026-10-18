class_name L3Fly
extends Moth
## 第三关的小怪，打法照搬扑灯蛾（飞，扑向亮的东西），换成 cfg 里这只怪的贴图，按所在屏幕上色。见 L3Mob。

var cfg: Dictionary = {}
var tint := "color"
var mob_name := ""


func _setup() -> void:
	super._setup()
	L3Mob.apply_cfg(self, cfg)


func _after_ready() -> void:
	super._after_ready()
	L3Mob.apply_look(self, tint)


## 2026-10-18 作者试玩"没有压迫感"：扑灯蛾只扑亮的东西，人把马灯放下、又不蓄力时它就在原地打转。
## 第三关的飞怪没有亮东西可扑就直接扑人（屏幕外的怪本来就定住，不会隔着屏幕追）
func _brightest() -> Node2D:
	var b := super._brightest()
	return b if b else nearest_player(SENSE_RANGE * 1.8)
