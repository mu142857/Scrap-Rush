extends Node
## 第三关看怪：把 1P 放进某个场景最大的那块屏幕，1 秒后在旁边召一只这个场景的精英怪。
## Godot --path . -w --write-movie /tmp/x.avi --fixed-fps 60 scenes/level3.tscn --quit-after 600 -- --l3scene=kitchen

const D := preload("res://scripts/levels/level3_data.gd")

var scene_name := ""
var _f := 0
var _p: Player
var _s: Dictionary = {}


func _process(_delta: float) -> void:
	if _p == null:
		for n in get_tree().get_nodes_in_group("player"):
			_p = n as Player
		var best := -1.0
		for s in D.SCREENS:
			var r: Array = s["rect"]
			if s["name"] == scene_name and r[2] - r[0] > best:
				best = r[2] - r[0]
				_s = s
		return
	_f += 1
	var r: Array = _s["rect"]
	if _f == 2:
		_p.global_position = Vector2(r[0] + 30, _s["floor"] - 2)
		_p.velocity = Vector2.ZERO
		if _p.crystal:
			_p.crystal.global_position = _p.global_position
		get_viewport().get_camera_2d().call("snap")
	if _f == 60:
		var el := L3Mob.elite(scene_name)
		if el != "":
			var e := L3Mob.make(el, _s["tint"])
			e.position = Vector2(r[2] - 50, r[1] + L3Mob.DATA.MOBS[el]["frame_size"].y + 4)
			get_parent().add_child(e)
			print("spawned elite ", el)
	if _f % 120 == 0:
		var names := []
		for n in get_tree().get_nodes_in_group("enemy"):
			var e2 := n as Node2D
			if e2 and absf(e2.global_position.x - (r[0] + r[2]) * 0.5) < (r[2] - r[0]) * 0.5 + 20 and absf(e2.global_position.y - _s["floor"]) < 120:
				names.append("%s@%d,%d" % [e2.get("mob_name"), e2.global_position.x, e2.global_position.y])
		print("frame ", _f, " player ", _p.global_position.round(), " enemies ", names)
