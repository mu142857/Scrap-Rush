extends Node
## 蒸汽压路机自动检查（无窗口）：进桥上那场遭遇战，把前几波小怪秒掉，留下压路机，
## 主角站在桥的一头不动 → 看它蓄力、冲撞、撞闸门、晕；再把主角放到它头顶 → 看它喷汽。
## 用法：Godot --headless --path . res://scenes/roller_check.tscn

var level: Node2D
var enc: Encounter
var roller: Node
var _t := 0.0
var _phase := "enter"
var _last_state := -1


func _ready() -> void:
	level = load("res://scenes/test_level.tscn").instantiate()
	add_child(level)
	Run.crystal_max = 100000.0
	Run.crystal_hp = 100000.0
	for c in level.get_children():
		if c is Encounter and c.waves.size() > 0 and "roller" in c.waves[-1]:
			enc = c
	print("[roller] 桥上的场子 left=%s right=%s 波数=%d" % [enc.left, enc.right, enc.waves.size()])


func _player() -> CharacterBody2D:
	return get_tree().get_nodes_in_group("player")[0]


func _physics_process(delta: float) -> void:
	_t += delta
	var p := _player()
	match _phase:
		"enter":
			p.global_position = Vector2(enc.left + 60.0, 335.0)
			p.velocity = Vector2.ZERO
			_phase = "smalls"
		"smalls":
			for a in enc._alive:
				if is_instance_valid(a) and not a.get("dead") and not a is SteamRoller:
					a.call("hurt", 99999.0, Vector2.RIGHT, true)
				if a is SteamRoller:
					roller = a
			if roller:
				print("[roller] t=%.2f 压路机登场 @%s 朝向=%d 情绪=%.0f 第 %d 波" % [_t, roller.global_position.round(), roller.dir, Run.emotion, enc._wave + 1])
				_phase = "watch"
				_t = 0.0
			# 主角一直站在左头
			p.global_position.x = enc.left + 30.0
		"watch", "blast":
			if not is_instance_valid(roller) or roller.dead:
				print("[roller] 死了"); get_tree().quit(); return
			if _phase == "watch":
				p.global_position.x = enc.left + 30.0
			if roller.state != _last_state:
				_last_state = roller.state
				print("[roller] t=%.2f 状态=%s @%s 主角@%s 血=%.0f" % [_t, SteamRoller.State.keys()[roller.state],
					roller.global_position.round(), p.global_position.round(), roller.hp])
			if _phase == "watch" and roller.state == SteamRoller.State.STUN:
				roller.hurt(100.0, Vector2.RIGHT, true)
				print("[roller] 晕的时候打一发 100，血剩 %.0f（应该少 150）" % roller.hp)
				_phase = "blast"
				_t = 0.0
		"blast":
			pass
	if _phase == "blast":
		if _t > 2.2 and _t < 5.0:
			# 一直按在它头顶上方 50 像素
			p.global_position = roller.global_position + Vector2(0, -50)
			p.velocity = Vector2.ZERO
		if _t > 6.0:
			print("[roller] 结束：主角 %s 情绪 %.0f 马灯 %.0f" % [p.global_position.round(), Run.emotion, Run.crystal_hp])
			get_tree().quit()
	if _t > 25.0:
		print("[roller] 超时"); get_tree().quit()
