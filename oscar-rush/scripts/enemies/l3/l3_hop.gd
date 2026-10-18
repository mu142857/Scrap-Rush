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


## 2026-10-18 作者试玩"没有压迫感"：跳蚤原来只看 180 以内，大屏幕里人站远了它就原地小跳。
## 第三关的跳蚤看得更远，一跳一跳追过去（一跳最远还是 120，落点照旧先亮红标记）
func nearest_player(max_dist := INF) -> Player:
	return super.nearest_player(max_dist * 2.2)
