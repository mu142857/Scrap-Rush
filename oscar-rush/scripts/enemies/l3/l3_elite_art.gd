## 第三关精英的大号、小号贴图（草图/第三关/怪物/elites_size.py 生成，放映机会话 10-18）。
## l3_elite.gd 用 load() 读 ART：哪只在里面就用哪只的新图，不在的照旧用 level3_mobs.gd 里的原图。
## body_rect 以脚底中间为原点，是挨打框；leds 是每帧红灯在原图里的像素（含义和 level3_mobs.gd 一样）。

const ART := {
	"water_tower": {"size": "big", "texture": "res://art/enemies/l3/size/water_tower.png", "hframes": 6, "frame_size": Vector2i(81, 107), "body_rect": Rect2(-33, -100, 66, 100), "leds": {0: Vector2i(30, 44), 1: Vector2i(30, 43), 2: Vector2i(29, 49), 3: Vector2i(23, 44), 4: Vector2i(30, 38), 5: Vector2i(30, 44)}},
	"ferris_wheel": {"size": "big", "texture": "res://art/enemies/l3/size/ferris_wheel.png", "hframes": 6, "frame_size": Vector2i(100, 107), "body_rect": Rect2(-37, -97, 76, 97), "leds": {0: Vector2i(48, 44), 1: Vector2i(48, 43), 2: Vector2i(47, 49), 3: Vector2i(41, 44), 4: Vector2i(48, 38), 5: Vector2i(48, 44)}},
	"hb_octopus": {"size": "big", "texture": "res://art/enemies/l3/size/hb_octopus.png", "hframes": 6, "frame_size": Vector2i(136, 107), "body_rect": Rect2(-61, -100, 118, 100), "leds": {0: Vector2i(67, 37), 1: Vector2i(67, 36), 2: Vector2i(66, 43), 3: Vector2i(59, 37), 4: Vector2i(67, 31), 5: Vector2i(67, 37)}},
	"fr_stump": {"size": "big", "texture": "res://art/enemies/l3/size/fr_stump.png", "hframes": 6, "frame_size": Vector2i(127, 106), "body_rect": Rect2(-53, -99, 110, 96), "leds": {0: Vector2i(42, 50), 1: Vector2i(42, 49), 2: Vector2i(40, 54), 3: Vector2i(36, 50), 4: Vector2i(42, 45), 5: Vector2i(42, 50)}},
	"space_rocket": {"size": "small", "texture": "res://art/enemies/l3/size/space_rocket.png", "hframes": 6, "frame_size": Vector2i(30, 34), "body_rect": Rect2(-7, -26, 14, 26), "leds": {0: Vector2i(14, 15), 1: Vector2i(14, 14), 2: Vector2i(13, 15), 3: Vector2i(12, 15), 4: Vector2i(14, 13), 5: Vector2i(14, 15)}},
	"weather_storm": {"size": "small", "texture": "res://art/enemies/l3/size/weather_storm.png", "hframes": 6, "frame_size": Vector2i(54, 42), "body_rect": Rect2(-18, -35, 37, 29), "leds": {0: Vector2i(16, 17), 1: Vector2i(16, 16), 2: Vector2i(15, 18), 3: Vector2i(14, 17), 4: Vector2i(16, 15), 5: Vector2i(16, 17)}},
	"aq_angler": {"size": "small", "texture": "res://art/enemies/l3/size/aq_angler.png", "hframes": 6, "frame_size": Vector2i(41, 28), "body_rect": Rect2(-13, -21, 27, 21), "leds": {0: Vector2i(18, 12), 1: Vector2i(18, 11), 2: Vector2i(17, 12), 3: Vector2i(17, 12), 4: Vector2i(18, 10), 5: Vector2i(18, 12)}},
	"dustsheet": {"size": "small", "texture": "res://art/enemies/l3/size/dustsheet.png", "hframes": 6, "frame_size": Vector2i(34, 32), "body_rect": Rect2(-10, -25, 19, 25), "leds": {0: Vector2i(15, 15), 1: Vector2i(15, 14), 2: Vector2i(14, 15), 3: Vector2i(14, 15), 4: Vector2i(15, 13), 5: Vector2i(15, 15)}},
}
