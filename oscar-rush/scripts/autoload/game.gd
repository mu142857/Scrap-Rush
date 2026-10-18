extends Node
## 打击反馈和杂项工具：震屏、顿帧、闪屏、音效、光照贴图、火花。
## 照 Phage 的 systems/game.gd 改的，镜头本身拆到了 GameCamera。

const TITLE_SCENE := "res://scenes/title.tscn"

var shake := 0.0
## 震屏叠加上限（add_shake 取最大值不累加，这里再封顶）
const MAX_SHAKE := 6.0
## 震屏方向每秒换几次。每个渲染帧都换（120/144 帧）会变成高频乱抖，看着发晕
const SHAKE_HZ := 30.0
var _shake_dir := Vector2.ZERO
var _shake_t := 0.0
## 开发用无敌（F1，见 scripts/debug/dev_mode.gd）：主角不受伤，马灯不掉血
var invincible := false
var pause_menu: PauseMenu

var _flash_rect: ColorRect
var _flash_tween: Tween
var _hitstop_token := 0
var _sounds := {}
## 这一局的统计，结局后的结算画面（results_screen.gd）用。标题按 START / CO-OP 时 reset_stats()
## time：在关卡和商店里、没暂停时累计的秒数；deaths：马灯碎了几次；spent：在商店花掉的零件
var run_stats := {"time": 0.0, "deaths": 0, "spent": 0}
var _stats_scene: Node = null
var _stats_parts := 0
const NO_CLOCK_SCENES := ["res://scenes/title.tscn", "res://scenes/weapon_select.tscn", "res://scenes/results.tscn"]

## 每个音效正在响的播放器（限同时响几个，见 sfx）
var _playing := {}
var _last_start := {}

## 音效文件的响度修正（dB）。按每个文件最响的 100 毫秒量出来：压到 -10 dB 以内，
## 刺耳的（汽笛、电流、警报、电视雪花）再多压 2 dB。只降不升，各处调用时写的音量照旧叠在上面。
## 2026-10-17 夜间打磨（游戏细节讨论会话）。换了音效文件要重新量一遍。
const SFX_TRIM := {
	"alarm": -8.4, "voice": -5.1, "charge": -3.0, "tvoff": -4.8, "busy": -2.0, "tvon": -2.0,
	"ding": -1.4, "buzz": -3.1, "boom": -0.5, "whistle": -2.7, "static": -3.3,
	# 怪物喷气（10-18 改成沙沙的高频短喷气）：高频听着比同样分贝的低频响，再压一点
	"jet": -5.0, "jet_long": -6.0,
}
## 个别音效同时最多响几个（比 SFX_MAX_VOICES 更少）。怪物喷气一群怪一起喷时只留两个，不叠成一片
const SFX_VOICES := {"jet": 2, "jet_long": 1}
## 个别音效的音高限制在这个范围里：怪物喷气各处调用写了 0.45~1.8 倍，太低又变回闷闷的中低频、拖得很长
const SFX_PITCH := {"jet": Vector2(0.85, 1.3)}
## 个别音效"隔多久内又响算叠在一起"（毫秒，默认 SFX_STACK_MS）
const SFX_STACK := {"jet": 150}
## 同一个音效同时最多响几个（一群怪同时挨打时不叠成一团），多了就停掉最早的
const SFX_MAX_VOICES := 4
## 同一个音效隔这么短又响，后一个压低一点，免得两个一样的声音叠在一起发冲
const SFX_STACK_MS := 40
const SFX_STACK_DB := -5.0
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
	Run.crystal_broken.connect(_on_lantern_broken)
	Run.parts_changed.connect(_on_parts_changed)
	_preload_sfx.call_deferred()
	pause_menu = PauseMenu.new()                                     # Esc / 手柄 Start 暂停
	add_child(pause_menu)
	add_child(Ambience.new())                                        # 各区域的环境声


## F11 或 Alt+Enter 切换全屏（默认全屏），切完记进设置。
## Esc 由暂停菜单（scripts/ui/pause_menu.gd）管：关卡里打开暂停，开始界面自己处理 Esc。
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_F11 or (k.physical_keycode == KEY_ENTER and k.alt_pressed):
		var full := DisplayServer.window_get_mode() >= DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		Settings.sync_fullscreen()
		get_viewport().set_input_as_handled()


## 选关：选武器以后进哪一关。开始菜单的"选择关卡"设，选武器界面出发时取走（取完恢复成第一关）
var start_scene := ""


func take_start_scene(default_scene: String) -> String:
	var s := start_scene if start_scene != "" else default_scene
	start_scene = ""
	return s


func reset_stats() -> void:
	run_stats = {"time": 0.0, "deaths": 0, "spent": 0}
	_stats_parts = Run.parts


func _on_parts_changed(parts: int) -> void:
	var cur := get_tree().current_scene
	if cur and cur.scene_file_path == "res://scenes/shop.tscn" and parts < _stats_parts:
		run_stats["spent"] += _stats_parts - parts
	_stats_parts = parts


func _tick_stats(delta: float) -> void:
	var cur := get_tree().current_scene
	if cur != _stats_scene:
		# 换了场景：零件数可能被"重来"退回去了（那里不发 parts_changed），按现在的重新记
		_stats_scene = cur
		_stats_parts = Run.parts
		# 走进第二关、第三关就记下来，开始菜单的"选择关卡"按这个解锁
		if cur:
			Progress.reach_scene(cur.scene_file_path)
	if cur and not get_tree().paused and not cur.scene_file_path in NO_CLOCK_SCENES and cur.scene_file_path != "":
		run_stats["time"] += delta


func _process(delta: float) -> void:
	_tick_stats(delta)
	# delta 已经乘过 time_scale，顿帧时震屏停在原地
	shake = move_toward(shake, 0.0, delta * 30.0)
	_shake_t -= delta
	if _shake_t <= 0.0:
		_shake_t = 1.0 / SHAKE_HZ
		_shake_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1))


## 乘上设置里的震屏强度（关 / 轻 / 强），再封顶 MAX_SHAKE
func add_shake(amount: float) -> void:
	shake = minf(maxf(shake, amount * Settings.shake_scale()), MAX_SHAKE)


## 镜头的震屏偏移（游戏像素）。按屏幕像素算，放大以后除回去，取到半像素。所有镜头都用这个
func shake_offset(zoom: float) -> Vector2:
	return (_shake_dir * shake / zoom * 2.0).round() / 2.0


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
	p.volume_db = volume_db + SFX_TRIM.get(name, 0.0)
	var now := Time.get_ticks_msec()
	if now - int(_last_start.get(name, -1000)) < SFX_STACK.get(name, SFX_STACK_MS):
		p.volume_db += SFX_STACK_DB
	_last_start[name] = now
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	if SFX_PITCH.has(name):
		var r: Vector2 = SFX_PITCH[name]
		p.pitch_scale = clampf(p.pitch_scale, r.x, r.y)
	# 菜单音效走 UI 总线（暂停时不被低通闷掉，见 Settings.set_muffled）
	if name.begins_with("ui_"):
		p.bus = &"UI"
	var list: Array = _playing.get(name, [])
	list = list.filter(func(q): return is_instance_valid(q))
	while list.size() >= SFX_VOICES.get(name, SFX_MAX_VOICES):
		(list.pop_front() as AudioStreamPlayer).queue_free()
	list.append(p)
	_playing[name] = list
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## 开场就在后台把 sfx/ 里的音效都载进来（一共约 1.3 MB），每帧载 3 个不卡画面。
## 以前是第一次播某个声音时才 load，第一次开枪、第一次挨打会顿一下，网页版更明显
func _preload_sfx() -> void:
	var names: Array[String] = []
	for f in DirAccess.get_files_at("res://sfx"):
		# 导出以后目录里是 xxx.wav.import / xxx.wav.remap，编辑器里还有 xxx.wav 本身
		var n := f.get_file().trim_suffix(".import").trim_suffix(".remap")
		if n.ends_with(".wav"):
			n = n.trim_suffix(".wav")
			if not n in names:
				names.append(n)
	var i := 0
	for n in names:
		if not _sounds.has(n):
			_sounds[n] = load("res://sfx/%s.wav" % n)
		i += 1
		if i % 3 == 0:
			await get_tree().process_frame


## 马灯碎了（这一关失败）：碎玻璃 + 关电视 + 一声闷响。各关自己只做闪屏和大字
func _on_lantern_broken() -> void:
	run_stats["deaths"] += 1
	sfx("crack", -2.0, 0.55)
	sfx("tvoff", -6.0, 0.8)
	sfx("boom", -8.0, 0.6)


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
