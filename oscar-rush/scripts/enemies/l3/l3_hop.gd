class_name L3Hop
extends Flea
## 第三关的小怪，打法照搬弹簧跳蚤（朝人弹跳），换成 cfg 里这只怪的贴图，按所在屏幕上色。见 L3Mob。

var cfg: Dictionary = {}
var tint := "color"
var mob_name := ""


func _setup() -> void:
	super._setup()
	L3Mob.apply_cfg(self, cfg)


func _after_ready() -> void:
	super._after_ready()
	L3Mob.apply_look(self, tint)
