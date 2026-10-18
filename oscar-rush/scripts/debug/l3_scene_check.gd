extends Node
## 第三关看怪：把 1P 放进某个场景最大的那块屏幕，1 秒后在旁边召一只这个场景的精英怪。
## Godot --path . -w --write-movie /tmp/x.avi --fixed-fps 60 scenes/level3.tscn --quit-after 600 -- --l3scene=kitchen

const D := preload("res://scripts/levels/level3_data.gd")

var scene_name := ""
## 不空的话从第 180 帧起每 60 帧截一张，到 600 帧退出（看怪、子弹在新背景里认不认得出）
var shots_dir := ""
## 不是 (-1, -1) 时，直接把 1P 放到这个位置（看某块特定屏幕，不一定是这种场景最大的那块）
var at := Vector2(-1, -1)
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
		_p.global_position = Vector2(r[0] + 30, _s["floor"] - 2) if at.x < 0 else at
		_p.velocity = Vector2.ZERO
		if _p.crystal:
			_p.crystal.global_position = _p.global_position
		get_viewport().get_camera_2d().call("snap")
	if _f == 60 and at.x < 0:
		var el := L3Mob.elite(scene_name)
		if el != "":
			var e := L3Mob.make(el, _s["tint"])
			e.position = Vector2(r[2] - 50, r[1] + L3Mob.DATA.MOBS[el]["frame_size"].y + 4)
			get_parent().add_child(e)
			print("spawned elite ", el)
	if shots_dir != "" and _f >= 180 and _f % 60 == 0:
		_shot("%s_%d" % [scene_name, _f])
	if shots_dir != "" and _f == 610:
		get_tree().quit()
	if _f % 120 == 0:
		var names := []
		for n in get_tree().get_nodes_in_group("enemy"):
			var e2 := n as Node2D
			if e2 and absf(e2.global_position.x - (r[0] + r[2]) * 0.5) < (r[2] - r[0]) * 0.5 + 20 and absf(e2.global_position.y - _s["floor"]) < 120:
				names.append("%s@%d,%d" % [e2.get("mob_name"), e2.global_position.x, e2.global_position.y])
		print("frame ", _f, " player ", _p.global_position.round(), " enemies ", names)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
