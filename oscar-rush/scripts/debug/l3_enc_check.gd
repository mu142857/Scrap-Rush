extends Node
## 第三关查遭遇战和怪的数量：开头打印一共摆了多少怪、几场遭遇战、有几只怪在动；
## 然后把 1P 放进第一场遭遇战的场子中间，过一会儿打印闸门有没有关、场上有几只怪。
## Godot --headless --path . scenes/level3.tscn --quit-after 900 -- --l3enc

var _f := 0


func _physics_process(_delta: float) -> void:
	_f += 1
	var encs := get_parent().get_children().filter(func(n): return n is Encounter)
	var enemies := get_tree().get_nodes_in_group("enemy")
	if _f == 5:
		var awake := enemies.filter(func(e): return e.can_process()).size()
		print("encounters %d, enemies %d, awake %d" % [encs.size(), enemies.size(), awake])
		for e in encs:
			print("  encounter %d..%d floor %d waves %s" % [e.left, e.right, e.floor_left, e.waves])
	if _f == 10 and not encs.is_empty():
		var e: Encounter = encs[0]
		for n in get_tree().get_nodes_in_group("player"):
			(n as Node2D).global_position = Vector2((e.left + e.right) * 0.5, e.floor_left - 2)
	if _f in [200, 500, 850] and not encs.is_empty():
		var e: Encounter = encs[0]
		var awake := enemies.filter(func(x): return x.can_process()).size()
		print("frame %d: started %s cleared %s, enemies %d awake %d" % [_f, e.started, e.cleared, enemies.size(), awake])
