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
var scroll_x := 0.0
var scroll_y := 0.0

var _zoom_target := ZOOM


func _ready() -> void:
	super._ready()
	_zoom_target = zoom.x


## 天桥上缩到 1 倍；下了天桥回到平时的倍数
func set_wide(on: bool) -> void:
	if on:
		_zoom_target = WIDE
	else:
		_zoom_target = ZOOM if _players().size() <= 2 else ZOOM_CROWD


## 画面在关卡里的范围（按现在的缩放，不含震屏）
func view_rect() -> Rect2:
	var half := get_viewport_rect().size * 0.5 / zoom
	return Rect2(global_position - half, half * 2.0)


func _process(delta: float) -> void:
	var z := lerpf(zoom.x, _zoom_target, 1.0 - exp(-ZOOM_SPEED * delta))
	if absf(z - _zoom_target) < 0.002:
		z = _zoom_target
	zoom = Vector2(z, z)
	if not scrolling:
		super._process(delta)
		return
	var half := get_viewport_rect().size * 0.5 / zoom
	var y := lerpf(global_position.y, scroll_y, 1.0 - exp(-SCROLL_Y_SPEED * delta))
	global_position = _clamp_to_bounds(Vector2(scroll_x, y), half)
	offset = (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * Game.shake / zoom.x * 2.0).round() / 2.0
