extends Node
## 第三关自检（2026-10-17 作者反馈后）：
## 1. 主角从洞口的格栅上走过去，不会掉下去
## 2. 从洞底下按住跳，能穿过格栅爬上来
## 3. 23 个场子里各放一只这个场景的精英怪，3 秒后都落在屏幕地面上（不站在家具顶上）
## Godot --headless --path . scenes/level3.tscn --fixed-fps 60 --quit-after 800 -- --l3fix（帧数是物理帧，每秒 120）

const D := preload("res://scripts/levels/level3_data.gd")

var _f := 0
var _p: Player
var _elites: Array = []


func _physics_process(_delta: float) -> void:
	if _p == null:
		for n in get_tree().get_nodes_in_group("player"):
			_p = n as Player
		return
	_f += 1
	var h: Array = D.HOLES[1]
	var right := _p.input_prefix + "_right"
	var jump := _p.input_prefix + "_jump"
	match _f:
		5:
			_put(Vector2(h[0] - 24, h[2]))
			Input.action_press(right)
		95:
			Input.action_release(right)
			print("1 walk over hole: x %.0f y %.0f (upper floor %d, fell=%s)" % [_p.global_position.x, _p.global_position.y, h[2], _p.global_position.y > h[2] + 4])
			_put(Vector2(h[0] + 11, h[3]))
			Input.action_press(jump)
		420:
			Input.action_release(jump)
		480:
			print("2 climb up: y %.0f (upper floor %d, made it=%s)" % [_p.global_position.y, h[2], _p.global_position.y <= h[2] + 1])
			for s in D.SCREENS:
				if not s.get("encounter", false):
					continue
				var el := L3Mob.elite(s["name"])
				var r: Array = s["rect"]
				var e := L3Mob.make(el, s["tint"])
				e.position = Vector2((r[0] + r[2]) * 0.5, r[1] + L3Mob.DATA.MOBS[el]["frame_size"].y + 4)
				get_parent().add_child(e)
				_elites.append([e, s["floor"], el])
		720:
			var bad := 0
			for item in _elites:
				var e: Node2D = item[0]
				if not is_instance_valid(e):
					continue
				var off: float = e.global_position.y - item[1]
				if absf(off) > 2.0:
					bad += 1
					print("   elite %s not on floor: y %.0f floor %d" % [item[2], e.global_position.y, item[1]])
			print("3 elites on floor: %d / %d" % [_elites.size() - bad, _elites.size()])


func _put(pos: Vector2) -> void:
	_p.global_position = pos + Vector2(0, -2)
	_p.velocity = Vector2.ZERO
	if _p.crystal:
		_p.crystal.global_position = _p.global_position
