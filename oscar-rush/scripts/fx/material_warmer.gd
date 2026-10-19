class_name MaterialWarmer
extends Node2D
## 材质预热（10-18 网页性能复查）：网页版第一次画某种材质 / 着色器时，浏览器要现编译着色器，
## 那一帧顿 50ms 以上（第三关进遭遇战：小怪的 LOOK_SHADER 被灯照到 / 没照到各一个、火花粒子）。
## 开场动画播放时调 warm(关卡)：把关卡里用到的每种材质，各用一个几乎透明的小方块在画面里画几帧
## （灯旁边一份、没灯的地方一份），再放两团粒子（受光 / 不受光），然后自己删掉。

const LIFE := 0.4

var _t := 0.0


static func warm(level: Node) -> void:
	if level == null or not level.is_inside_tree():
		return
	var w := MaterialWarmer.new()
	level.add_child(w)


func _ready() -> void:
	# 开场动画会暂停整棵树，这里照样计时、到点删掉
	process_mode = Node.PROCESS_MODE_ALWAYS
	var level := get_parent()
	var tex := _white()
	var spots := _spots()
	var seen := {}
	var mats: Array = [null]
	for n in level.find_children("*", "CanvasItem", true, false):
		var m: Material = (n as CanvasItem).material
		if m == null:
			continue
		var key := ""
		if m is ShaderMaterial and (m as ShaderMaterial).shader:
			key = "s%d" % (m as ShaderMaterial).shader.get_instance_id()
		elif m is CanvasItemMaterial:
			key = "c%d:%d" % [(m as CanvasItemMaterial).blend_mode, (m as CanvasItemMaterial).light_mode]
		else:
			continue
		if not seen.has(key):
			seen[key] = true
			mats.append(m)
	for m in mats:
		for p in spots:
			var s := Sprite2D.new()
			s.texture = tex
			s.material = m
			s.position = p
			s.modulate.a = 0.02
			add_child(s)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	for mat in [null, unshaded]:
		for p in spots:
			var c := CPUParticles2D.new()
			c.amount = 2
			c.lifetime = 0.3
			c.material = mat
			c.position = p
			c.modulate.a = 0.02
			add_child(c)


func _process(delta: float) -> void:
	_t += delta
	if _t > LIFE:
		queue_free()


## 画面中间、主角身边（马灯照着）、画面上面两个角（多半没灯照着）
func _spots() -> Array:
	var out: Array = []
	var cam := get_viewport().get_camera_2d()
	var c := cam.get_screen_center_position() if cam else Vector2.ZERO
	out.append(c)
	for pl in get_tree().get_nodes_in_group("player"):
		out.append((pl as Node2D).global_position + Vector2(0, -10))
		break
	var half := get_viewport_rect().size * 0.5 / (cam.zoom if cam else Vector2.ONE)
	out.append(c + Vector2(-half.x + 4, -half.y + 4))
	out.append(c + Vector2(half.x - 4, -half.y + 4))
	return out


static func _white() -> Texture2D:
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)
