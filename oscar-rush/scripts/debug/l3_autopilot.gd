extends Node
## 第三关自动驾驶（游戏剧情主题讨论会话）：沿 Level3Data.ROUTES 里的一条路线从起点走到家门口。
## 主角无敌；走到关门的遭遇战里就把场上的怪全打掉（精英出场动画期间打不动，就隔一会儿再打）；
## 到洞口按住跳往上爬。每到一个路点打印一行，卡住（10 秒没前进）就打印位置并退出。
## Godot --headless --fixed-fps 60 --path . scenes/level3.tscn -- --l3auto=0   （0/1/2 是第几条路线）
## 走出第三关就退出，不会跑进商店和 Boss3。

const D := preload("res://scripts/levels/level3_data.gd")
const STUCK_TIME := 10.0

var route_i := 0
var _p: Player
var _wp := 0
var _t := 0.0
var _best := INF
var _since_best := 0.0
var _kill_t := 0.0
var _encounters := 0
var _start_ms := 0
var _blocked := 0.0
var _topped := false
## --l3watch=<秒>：遭遇战开打后先站着看这么久再清场（看小怪怎么围上来），配合 --l3shots=<目录> 每秒截一张
var watch := 0.0
var shots_dir := ""
var _enc_t := 0.0
var _shot_n := 0


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()


func _physics_process(delta: float) -> void:
	if _p == null:
		for n in get_tree().get_nodes_in_group("player"):
			_p = n as Player
		return
	_t += delta
	_p.set("_invuln", 0.5)
	var route: Array = D.ROUTES[route_i]
	if _wp >= route.size():
		return
	var w: Array = route[_wp]
	var pos := _p.global_position
	var right := _p.input_prefix + "_right"
	var left := _p.input_prefix + "_left"
	var jump := _p.input_prefix + "_jump"

	# 遭遇战：闸门关着就把场上的怪打掉，不走
	var enc := _active_encounter()
	if enc:
		_release_all()
		_enc_t += delta
		if _enc_t < watch:
			if shots_dir != "" and int(_enc_t) >= _shot_n:
				_shot_n += 1
				_shot("enc%d_%02d" % [_encounters, _shot_n])
			_since_best = 0.0
			return
		_kill_t -= delta
		if _kill_t <= 0.0:
			_kill_t = 0.5
			for e in get_tree().get_nodes_in_group("enemy"):
				var n := e as Node2D
				if n and n.global_position.x > enc.left - 10 and n.global_position.x < enc.right + 10 and not n.get("dead"):
					n.call("hurt", 99999.0, Vector2.LEFT, true)
		_since_best = 0.0
		return

	_enc_t = 0.0
	_shot_n = 0
	var dist := 0.0
	match w[2]:
		"walk", "exit":
			var dx: float = w[0] - pos.x
			dist = absf(dx)
			Input.action_release(jump)
			if dist < 3.0 and w[2] == "walk":
				_release_all()
				_next("walk", pos)
				return
			Input.action_press(right if dx > 0 else left)
			Input.action_release(left if dx > 0 else right)
			# 在地上走不动（墙、台阶、比脚下高的平台）超过 0.3 秒就跳一下，像真人一样
			if _p.is_on_floor() and absf(_p.velocity.x) < 5.0:
				_blocked += delta
			else:
				_blocked = 0.0
			if _blocked > 0.3:
				Input.action_press(jump)
				_blocked = -0.25
		"climb":
			_release_all()
			# 爬过洞口就松手，落在格栅上（一直按着会在洞口上面悬着，像真人一样到了就松手）
			if pos.y < float(w[1]) - 4.0:
				_topped = true
			if not _topped:
				Input.action_press(jump)
			dist = absf(pos.y - float(w[1]))
			if pos.y <= float(w[1]) + 1.0 and _p.is_on_floor():
				Input.action_release(jump)
				_next("climb", pos)
				return
	if dist < _best - 0.5:
		_best = dist
		_since_best = 0.0
	else:
		_since_best += delta
	if _since_best > STUCK_TIME:
		print("l3auto: STUCK route %d at waypoint %d %s, player at %s" % [route_i, _wp, w, pos.round()])
		get_tree().quit()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))


func _next(what: String, pos: Vector2) -> void:
	print("l3auto: route %d waypoint %d (%s) ok at %s, t=%.0fs" % [route_i, _wp, what, pos.round(), _t])
	_wp += 1
	_topped = false
	_best = INF
	_since_best = 0.0


func _active_encounter() -> Encounter:
	for n in get_parent().get_children():
		var e := n as Encounter
		if e and e.started and not e.cleared:
			if not e.get_meta("counted", false):
				e.set_meta("counted", true)
				_encounters += 1
			return e
	return null


func _release_all() -> void:
	for a in ["_right", "_left", "_jump"]:
		Input.action_release(_p.input_prefix + a)


## 关卡切场景（走到家门口）时打印结果，然后直接退出：别让它一路跑进商店和 Boss3
## （2026-10-17 夜：跑进 Boss3 撞上一个每帧刷错误的 bug，日志涨到好几 GB）
func _exit_tree() -> void:
	if _p:
		print("l3auto: route %d finished=%s waypoint %d/%d, encounters %d, game time %.0fs" % [route_i, _wp >= D.ROUTES[route_i].size() - 1, _wp, D.ROUTES[route_i].size(), _encounters, _t])
	get_tree().quit()
