class_name PartsCounter
extends Control
## 零件数（商店的货币）：一个小齿轮图标加"x 3"。商店里放在左上角水晶血量下面；
## 关卡里的 HUD 要显示零件时也可以直接 add_child(PartsCounter.new())。

const ICONS := preload("res://art/shop/icons.png")

var _label: Label
var _pop := 0.0
var _icon: TextureRect


func _ready() -> void:
	size = Vector2(60, 16)
	var atlas := AtlasTexture.new()
	atlas.atlas = ICONS
	atlas.region = Rect2(0, 0, 16, 16)
	_icon = TextureRect.new()
	_icon.texture = atlas
	_icon.position = Vector2(-3, -3)
	add_child(_icon)
	_label = Label.new()
	_label.label_settings = Hud.small_text(Hud.WARM)
	_label.position = Vector2(13, -1)
	add_child(_label)
	Run.parts_changed.connect(_on_parts)
	_label.text = "x %d" % Run.parts


func _on_parts(n: int) -> void:
	_label.text = "x %d" % n
	_pop = 1.0


func _process(delta: float) -> void:
	_pop = maxf(_pop - delta * 5.0, 0.0)
	_icon.position.y = -3 - roundf(sin(_pop * PI) * 2.0)
