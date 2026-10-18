class_name HitFx
extends Node2D
## 三把武器共用的打击、击杀反馈（作者 10-18："更有打击感，更爽，这个游戏就是爽"）。
## 都从武器这边调（铆钉、光球、蒸汽圈打中以后调 after_hit），不改十几个怪各自的脚本：
## 打完看一眼怪死没死，死了就再加一层武器自己的击杀反馈。
## 击杀（作者 10-18："打死往外扩散的一圈粒子……感觉甚至更差"）：不要均匀往外扩的一圈，改成有方向、有分量的——
##   白色剪影闪 3 帧、几块碎铁顺着攻击方向迸出去落地弹一下、机器溅机油和火花 / 人形怪溅血（Splatter）、短顿帧、"咔嚓"。
## 这个节点自己只活 2~3 帧：画命中那一下的十字星。

## 两次击杀隔多久以内算连杀（毫秒）
const STREAK_GAP_MS := 1400
const STREAK_MAX := 8
## 第二关的人形怪（披袍的接线员、引座员、观众，几个人形精英、拾荒者）：溅血，不溅机油、不迸铁片。
## 按脚本文件名认，不用改它们的脚本；以后谁的怪是活物，在怪身上加 var flesh := true 也认
const FLESH_SCRIPTS: Array[String] = ["hooded_operator.gd", "usher.gd", "audience.gd", "chief_operator.gd",
		"film_editor.gd", "watchman.gd", "scavenger.gd", "telegrapher.gd"]

static var _streak := 0
static var _last_kill_ms := -100000

## 0（铆钉）~ 1（蓄满光球、蒸汽锤）
var power := 0.0
var _t := 0.0


## 打中以后调：命中星 + 溅一点（机油或血）+ 看看死没死。返回 true 表示这一下打死了
static func after_hit(body: Node, pos: Vector2, dir: Vector2, power := 0.0) -> bool:
	var parent := _parent_of(body)
	if parent == null:
		return false
	spawn(parent, pos, power)
	var flesh := is_flesh(body)
	# 打中小溅：铆钉每颗 1 滴，没蓄满的光球 2 滴，蓄满和蒸汽锤 4 滴
	Splatter.spray(body, pos, dir, 1 + int(round(power * 3.0)), flesh, 0.8 + 0.4 * power)
	if not _killed(body):
		return false
	# 同一只怪只爆一次（铆钉一帧里可能有两颗同时打中刚死的怪）
	if is_instance_valid(body):
		if body.has_meta("hitfx_killed"):
			return false
		body.set_meta("hitfx_killed", true)
	kill(parent, body, pos, dir, power)
	return true


static func is_flesh(body: Node) -> bool:
	if not is_instance_valid(body):
		return false
	if body.has_meta("hitfx_flesh"):
		return body.get_meta("hitfx_flesh")
	var f: bool = body.get("flesh") == true
	if not f and body.get_script():
		f = (body.get_script() as Script).resource_path.get_file() in FLESH_SCRIPTS
	body.set_meta("hitfx_flesh", f)
	return f


static func _parent_of(body: Node) -> Node:
	if not is_instance_valid(body) or not body.is_inside_tree():
		return null
	return body.get_parent()


static func _killed(body: Node) -> bool:
	if not is_instance_valid(body):
		return true
	# Boss 有自己的大死亡演出，这里不加
	if body.has_method("start_fight"):
		return false
	if body.get("dead") == true:
		return true
	var hp = body.get("hp")
	return hp != null and float(hp) <= 0.0


static func spawn(parent: Node, pos: Vector2, pw: float) -> HitFx:
	var fx := HitFx.new()
	fx.power = pw
	fx.global_position = pos.round()
	parent.add_child(fx)
	return fx


## 击杀：剪影白闪、碎片顺着攻击方向迸、溅油或溅血、短顿帧、震一下、"咔嚓"（连杀时一声比一声高）
static func kill(parent: Node, body: Node, pos: Vector2, dir: Vector2, pw: float) -> void:
	var now := Time.get_ticks_msec()
	_streak = mini(_streak + 1, STREAK_MAX) if now - _last_kill_ms < STREAK_GAP_MS else 0
	_last_kill_ms = now
	var alive := is_instance_valid(body)
	var big: bool = alive and body.get("big") == true
	var flesh := is_flesh(body)
	var d := dir.normalized() if dir.length() > 0.1 else Vector2(1.0 if randf() < 0.5 else -1.0, 0.0)
	# 精英有自己的死亡演出（先坏掉、再炸），这里只补一把溅
	var elite: bool = alive and body.has_method("in_intro")
	Splatter.spray(body if alive else parent, pos, d, (16 if big else 10) if flesh else (12 if big else 8), flesh, 1.2, 35.0)
	if elite:
		return
	_silhouette(parent, body)
	var foot := pos.y + 6.0
	if alive and body is Node2D:
		foot = (body as Node2D).global_position.y
	# 碎片少而有力：机器 4~7 块（大块 + 螺丝），人形 2 块布片；都顺着攻击方向飞
	var cols: Array = [Color8(150, 140, 125), Color8(255, 190, 120)]
	if alive and body.get("death_spark_colors") is Array:
		cols = body.get("death_spark_colors")
	var n := 2 if flesh else (7 if big else 4)
	for i in n:
		var c := Chunk.new()
		c.position = pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		c.velocity = Vector2(d.x * randf_range(90.0, 200.0) + randf_range(-25.0, 25.0),
				minf(d.y, 0.0) * 120.0 - randf_range(70.0, 150.0))
		c.ground_y = foot - 1.0
		if flesh:
			c.color = cols[0]
			c.shape = Chunk.CLOTH
		else:
			c.color = [Color8(120, 115, 110), cols[0], Color8(200, 160, 90), Color8(90, 86, 84)][i % 4]
			c.shape = Chunk.SCREW if i == n - 1 else (Chunk.BIG if i < 2 else Chunk.SMALL)
		parent.add_child(c)
	if not flesh:
		# 机器：一小股火花顺着打的方向喷出去（不是一圈）
		Game.sparks(parent, pos, Color(1.0, 0.8, 0.45), 6, 150.0, d)
	Game.sfx("kill_pop", -6.0 if big else -8.0, (0.85 if flesh else 1.0) + 0.07 * _streak, 0.04)
	Game.add_shake((4.0 if big else 2.6) + 0.15 * _streak)
	# 武器自己已经在顿帧（蓄满光球打中顿 0.07 秒）就不再叫：hitstop 后叫的会把先叫的截短
	if Engine.time_scale > 0.0:
		Game.hitstop(0.05 if big else 0.035)


## 怪死的那一下留一个纯白剪影（照它最后那一帧画），亮 3 帧。顿帧时跟着停住，正好"定格"
static func _silhouette(parent: Node, body: Node) -> void:
	if not is_instance_valid(body):
		return
	var spr = body.get("_sprite")
	if not (spr is Sprite2D) or (spr as Sprite2D).texture == null:
		return
	var src := spr as Sprite2D
	var s := Sprite2D.new()
	s.texture = src.texture
	s.hframes = src.hframes
	s.vframes = src.vframes
	s.frame = src.frame
	s.flip_h = src.flip_h
	s.centered = src.centered
	s.offset = src.offset
	s.global_position = src.global_position
	s.z_index = 19
	if src.material is ShaderMaterial:
		var m := (src.material as ShaderMaterial).duplicate() as ShaderMaterial
		m.set_shader_parameter("flash", 1.0)
		s.material = m
	else:
		s.modulate = Color(6, 6, 6)
	parent.add_child(s)
	# 计时跟着游戏时间走：顿帧时不走，顿完再亮 3 帧左右
	parent.get_tree().create_timer(0.05, true, false, false).timeout.connect(s.queue_free)


func _ready() -> void:
	z_index = 20
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded


func _process(delta: float) -> void:
	_t += delta
	# 命中星只亮 2~3 帧（顿帧时 delta 是 0，会停在那一帧上）
	if _t > 0.045:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	# 命中星：白芯 + 四个方向的短刺，越痛刺越长
	var arm := 2 + int(round(power * 3.0))
	draw_rect(Rect2(-1, -1, 2, 2), Color.WHITE)
	var warm := Color(1.0, 0.9, 0.7)
	for i in range(1, arm + 1):
		var c := Color.WHITE if i <= 1 else warm
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_rect(Rect2((d as Vector2) * (i + 0.5) - Vector2(0.5, 0.5), Vector2.ONE), c)


## 击杀时迸出来的一块碎片：往上抛、落地弹一下、躺一会儿，最后一闪一闪地没掉（像素风，不做半透明淡出）
class Chunk extends Node2D:
	const GRAVITY := 560.0
	const LIFE := 1.1
	const SMALL := 0
	const BIG := 1
	const SCREW := 2
	const CLOTH := 3
	var velocity := Vector2.ZERO
	var ground_y := 0.0
	var color := Color.GRAY
	var shape := SMALL
	## 兼容蒸汽锤的碎石（只设 big）
	var big := false:
		set(v):
			big = v
			if v:
				shape = BIG
	var _t := 0.0
	var _bounces := 0
	var _spin := 0

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		_t += delta
		if _bounces < 2:
			velocity.y += GRAVITY * delta
			position += velocity * delta
			if delta > 0.0:
				_spin += 1
			if position.y >= ground_y and velocity.y > 0.0:
				position.y = ground_y
				_bounces += 1
				velocity = Vector2(velocity.x * 0.4, -absf(velocity.y) * 0.3)
				if _bounces >= 2:
					velocity = Vector2.ZERO
		if _t > LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		if _t > LIFE - 0.3 and int(_t * 20.0) % 2 == 0:
			return
		var o := position.round() - position
		var flying := _bounces < 2 and (_spin / 3) % 2 == 1
		match shape:
			BIG:
				draw_rect(Rect2(o, Vector2(2, 3) if flying else Vector2(3, 2)), color)
				draw_rect(Rect2(o, Vector2.ONE), color.lightened(0.25))
			SCREW:
				draw_rect(Rect2(o, Vector2(1, 3) if flying else Vector2(3, 1)), Color8(170, 165, 155))
				draw_rect(Rect2(o, Vector2.ONE), Color8(210, 205, 195))
			CLOTH:
				draw_rect(Rect2(o, Vector2(2, 1) if flying else Vector2(3, 1)), color)
			_:
				draw_rect(Rect2(o, Vector2(1, 2) if flying else Vector2(2, 1)), color)
