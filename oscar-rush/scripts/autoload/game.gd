extends Node
## 打击反馈和杂项工具：震屏、顿帧、闪屏、音效、光照贴图、火花。
## 照 Phage 的 systems/game.gd 改的，镜头本身拆到了 GameCamera。

const TITLE_SCENE := "res://scenes/title.tscn"

var shake := 0.0

var _flash_rect: ColorRect
var _flash_tween: Tween
var _hitstop_token := 0
var _sounds := {}
var _light_tex: Texture2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	layer.add_child(_flash_rect)
	add_child(load("res://scripts/debug/dev_mode.gd").new())        # F8 开发者模式


## F11 或 Alt+Enter 切换全屏（默认全屏）
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	# Esc：关卡里回开始界面（开始界面自己处理 Esc）
	if k.physical_keycode == KEY_ESCAPE:
		var cur := get_tree().current_scene
		if cur and cur.scene_file_path != TITLE_SCENE:
			Engine.time_scale = 1.0
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE_SCENE)
			get_viewport().set_input_as_handled()
		return
	if k.physical_keycode == KEY_F11 or (k.physical_keycode == KEY_ENTER and k.alt_pressed):
		var full := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# delta 已经乘过 time_scale，顿帧时震屏停在原地
	shake = move_toward(shake, 0.0, delta * 30.0)


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


## 时间完全停 duration 秒，再在 recover 秒内缓回正常速度
func hitstop(duration: float, recover := 0.0) -> void:
	_hitstop_token += 1
	var token := _hitstop_token
	Engine.time_scale = 0.0
	await get_tree().create_timer(duration, true, false, true).timeout
	if token != _hitstop_token:
		return
	if recover <= 0.0:
		Engine.time_scale = 1.0
		return
	var start := Time.get_ticks_msec()
	while true:
		await get_tree().process_frame
		if token != _hitstop_token:
			return
		var k := clampf((Time.get_ticks_msec() - start) / 1000.0 / recover, 0.0, 1.0)
		Engine.time_scale = 1.0 - pow(1.0 - k, 3.0)
		if k >= 1.0:
			break


func flash(color: Color, alpha: float, duration: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_rect.color = Color(color.r, color.g, color.b, alpha)
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, duration)


## 播放一次音效。pitch 和 volume_db 可调；随机音高让重复的声音不腻
func sfx(name: String, volume_db := 0.0, pitch := 1.0, pitch_jitter := 0.0) -> AudioStreamPlayer:
	if not _sounds.has(name):
		_sounds[name] = load("res://sfx/%s.wav" % name)
	var p := AudioStreamPlayer.new()
	p.stream = _sounds[name]
	p.volume_db = volume_db
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func load_sound(name: String) -> AudioStream:
	if not _sounds.has(name):
		_sounds[name] = load("res://sfx/%s.wav" % name)
	return _sounds[name]


## 所有 PointLight2D 共用的圆形衰减贴图（64×64，texture_scale 决定半径）
func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 64
		tex.height = 64
		_light_tex = tex
	return _light_tex


## 脚边扬起的小团尘土，贴地散开、慢慢变淡。
## side = 0 往左右两边各一团（起跳、落地）；-1 / 1 只往一边（跑步脚后跟、急转身）
func dust(parent: Node, pos: Vector2, amount := 4, only_side := 0.0) -> void:
	var sides: Array = [-1.0, 1.0] if only_side == 0.0 else [only_side]
	for side_x in sides:
		var side: float = side_x
		var p := CPUParticles2D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = amount
		p.lifetime = 0.35
		p.explosiveness = 0.9
		p.direction = Vector2(side, -0.35)
		p.spread = 18.0
		p.initial_velocity_min = 20.0
		p.initial_velocity_max = 55.0
		p.damping_min = 120.0
		p.damping_max = 160.0
		p.gravity = Vector2(0, -20)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 2.0
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.72, 0.68, 0.64, 0.85))
		ramp.set_color(1, Color(0.4, 0.38, 0.38, 0.0))
		p.color_ramp = ramp
		p.global_position = pos + Vector2(side * 2.0, -1.0)
		parent.add_child(p)
		p.emitting = true
		p.finished.connect(p.queue_free)


## 一次性的像素火花。parent 一般传当前关卡
func sparks(parent: Node, pos: Vector2, color: Color, amount := 8, speed := 70.0, dir := Vector2.ZERO) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.spread = 180.0 if dir == Vector2.ZERO else 50.0
	p.direction = Vector2.UP if dir == Vector2.ZERO else dir
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r * 0.4, color.g * 0.3, color.b * 0.3, 0.0))
	p.color_ramp = ramp
	p.global_position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
