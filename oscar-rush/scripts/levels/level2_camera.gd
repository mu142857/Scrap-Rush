class_name Level2Camera
extends GameCamera
## 第二关的镜头。平时和 GameCamera 一样（2 倍，跟人）。
## 走上胶片天桥以后由关卡接管（scrolling = true）：缩到 1 倍，一屏看到 480×270，整条胶片在画面正中；
## x 由关卡推着走（scroll_x，自动卷轴），y 对准胶片中间（scroll_y）。
## 下了天桥 scrolling = false，缩回 2 倍照常跟人。

const ZOOM_SPEED := 4.0
const WIDE := 1.0
const SCROLL_Y_SPEED := 4.0

var scrolling := false
## 坐气动管时镜头跟着胶囊走（人藏起来了）。设回 null 时落地高度重新记：
## 以前还按上一间房的地面追，出管口镜头先冲到主角脚下 35 像素、再拽回来，晃得厉害（作者 10-17 反馈）
var chase: Node2D = null:
	set(v):
		if chase != null and v == null:
			forget_ground()
		chase = v
var scroll_x := 0.0
var scroll_y := 0.0

var _zoom_target := ZOOM


func _ready() -> void:
	super._ready()
	manages_zoom = false
	_zoom_target = _base_zoom


## 天桥上缩到 1 倍；下了天桥回到平时的倍数
func set_wide(on: bool) -> void:
	if on:
		_zoom_target = WIDE
	else:
		_zoom_target = ZOOM if _players().size() <= 2 else ZOOM_CROWD


## 画面在关卡里的范围（按现在的缩放，不含震屏）
## 天桥的烧穿边、右边的空气墙、换卷战的场子宽度都按它算。
## 镜头的 zoom 会按屏幕倍率对齐（GameCamera.pixel_zoom），窗口很小（无窗口测试）时算出来的画面会窄得离谱，
## 那时退回设计尺寸（480×270 除以想要的倍数），免得场子只有几十像素宽。
## 主角瞬移以后：忘掉记着的上一帧位置（GameCamera 自己按物理帧插值，不清的话还会按瞬移前的位置算），再直接对准
func teleported() -> void:
	_prev.clear()
	_curr.clear()
	forget_ground()
	snap()


func view_rect() -> Rect2:
	var half := get_viewport_rect().size * 0.5 / zoom
	if half.x * 2.0 < 240.0:
		half = Vector2(480, 270) * 0.5 / maxf(_zoom_target, 0.5)
	return Rect2(global_position - half, half * 2.0)


func _process(delta: float) -> void:
	# 目标按屏幕倍率对齐（见 GameCamera.pixel_zoom），过渡途中是小数没关系
	var tgt := pixel_zoom(get_viewport(), _zoom_target)
	# 平时（不在天桥上、不坐管子）合作两人拉开时往外拉，见 GameCamera.coop_fit_zoom
	if not scrolling and chase == null:
		var fit := coop_fit_zoom()
		if fit < tgt:
			tgt = maxf(pixel_zoom(get_viewport(), fit, true), 1.0)
	var z := lerpf(zoom.x, tgt, 1.0 - exp(-ZOOM_SPEED * delta))
	if absf(z - tgt) < 0.002:
		z = tgt
	zoom = Vector2(z, z)
	if is_instance_valid(chase):
		var h := get_viewport_rect().size * 0.5 / zoom
		var p := global_position.lerp(chase.global_position + FOCUS_OFFSET * 0.5, 1.0 - exp(-12.0 * delta))
		global_position = _clamp_to_bounds(p, h)
		offset = Game.shake_offset(zoom.x)
		return
	if not scrolling:
		super._process(delta)
		return
	var half := get_viewport_rect().size * 0.5 / zoom
	var y := lerpf(global_position.y, scroll_y, 1.0 - exp(-SCROLL_Y_SPEED * delta))
	global_position = _clamp_to_bounds(Vector2(scroll_x, y), half)
	offset = Game.shake_offset(zoom.x)
