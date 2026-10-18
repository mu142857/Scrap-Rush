extends Node
## 第三关特殊玩法自测（游戏剧情主题讨论会话）：把主角放进某块场子屏幕，开打遭遇战，主角无敌，站着看。
## 配合录像截图：Godot --windowed --resolution 960x540 --position 0,0 --always-on-top --write-movie x.avi --fixed-fps 60 \
##   --quit-after 1200 --path . scenes/level3.tscn -- --l3mode=harbor
## --l3signal=0.3：信号干扰直接从 30% 开始（不用等一分钟看雪花）。--l3revisit：清场后走出去再走回来，看回访刷怪
const D := preload("res://scripts/levels/level3_data.gd")

var scene_name := ""
var signal_start := 1.0
var revisit := false
var shots_dir := ""
var _flash_seen := 0
var _p: Player
var _f := 0
var _rect := Rect2()
var _floor := 0.0


func _ready() -> void:
	for s in D.SCREENS:
		if s["name"] == scene_name and s.get("encounter", false):
			var r: Array = s["rect"]
			_rect = Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
			_floor = s["floor"]


func _physics_process(_delta: float) -> void:
	Engine.time_scale = 1.0
	if _p == null:
		for n in get_tree().get_nodes_in_group("player"):
			_p = n as Player
		return
	_f += 1
	_p.set("_invuln", 0.5)
	if revisit and shots_dir != "":
		var fl := get_tree().get_nodes_in_group("revisit_flash")
		if fl.size() > 0 and _flash_seen == 0:
			_flash_seen = _f
		if _flash_seen > 0 and _f == _flash_seen + 40:
			_shot("revisit_flash")
		if _flash_seen > 0 and _f == _flash_seen + 140:
			_shot("revisit_after")
	if _f == 20:
		if revisit:
			get_parent().set("revisit_chance", 1.0)
		_put(Vector2(_rect.position.x + 60.0, _floor))
		print("l3mode: %s at %s" % [scene_name, _rect])
	if signal_start < 1.0 and _f % 30 == 0 and _f > 120 and _f < 700:
		for m in get_parent().get("_modes"):
			if m.rect.position.x == _rect.position.x:
				print("l3mode: frame %d signal %.2f" % [_f, m.get("_signal")])
	if _f == 120 and signal_start < 1.0:
		for m in get_parent().get("_modes"):
			if m.rect.position.x == _rect.position.x:
				m.set("_signal", signal_start)
	if revisit:
		# 120 帧时把场上的怪清掉，清场后走出屏幕、再走回来，重复三次
		if _f >= 200 and _f % 30 == 0 and not _cleared():
			for e in get_tree().get_nodes_in_group("enemy"):
				if _rect.has_point((e as Node2D).global_position):
					e.call("hurt", 99999.0, Vector2.LEFT, true)
		if _f in [1000, 1400, 1800]:
			_put(Vector2(_rect.position.x - 40.0, _floor))
		if _f in [1060, 1460, 1860]:
			_put(Vector2(_rect.position.x + 60.0, _floor))
		if _f % 60 == 0 and _f > 960:
			var n := 0
			for e in get_tree().get_nodes_in_group("enemy"):
				if _rect.has_point((e as Node2D).global_position) and not e.get("dead"):
					n += 1
			var cl := false
			var names := []
			for r in get_parent().get("_revisit"):
				if (r["rect"] as Rect2).position.x == _rect.position.x:
					cl = (r["enc"] as Encounter).cleared
			for e in get_tree().get_nodes_in_group("enemy"):
				if _rect.has_point((e as Node2D).global_position) and not e.get("dead"):
					names.append("%s@%s" % [e.get("mob_name"), (e as Node2D).global_position.round()])
			print("l3mode: frame %d enemies in screen %d cleared %s %s player %s" % [_f, n, cl, names, _p.global_position.round()])


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))


func _cleared() -> bool:
	for r in get_parent().get("_revisit"):
		if (r["rect"] as Rect2).position.x == _rect.position.x:
			return (r["enc"] as Encounter).cleared
	return false


func _put(pos: Vector2) -> void:
	_p.global_position = pos + Vector2(0, -2)
	_p.velocity = Vector2.ZERO
	if _p.crystal:
		_p.crystal.global_position = _p.global_position
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("snap"):
		cam.snap()
