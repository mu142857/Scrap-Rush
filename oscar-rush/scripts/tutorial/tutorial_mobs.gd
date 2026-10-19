## 教学关专属的怪，由 草图/教学关/tutorial_mobs.py --export 生成，别手改。
## 格式和 level3_mobs.gd 一样（L3Mob.apply_cfg 能直接用）；TARGETS 是铁皮打靶机（帧：0 立着、1 翻一半、2 倒平）。

const MOBS := {
	"boxer": {"scene": "tutorial", "kind": "dash", "texture": "res://art/enemies/tutorial/boxer.png", "hframes": 4, "frame_size": Vector2i(26, 19), "body_rect": Rect2(-4, -15, 10, 15), "leds": {0: Vector2i(11, 6), 1: Vector2i(11, 5), 2: Vector2i(10, 5), 3: Vector2i(9, 6)}, "muzzle": Vector2i(-1, -1), "bullet": "rivet"},
	"tinmoth": {"scene": "tutorial", "kind": "fly", "texture": "res://art/enemies/tutorial/tinmoth.png", "hframes": 3, "frame_size": Vector2i(24, 14), "body_rect": Rect2(-7, -10, 13, 9), "leds": {0: Vector2i(10, 8), 1: Vector2i(10, 8), 2: Vector2i(10, 8)}, "muzzle": Vector2i(-1, -1), "bullet": "rivet"},
	"coach": {"scene": "tutorial", "kind": "elite", "texture": "res://art/enemies/tutorial/coach.png", "hframes": 6, "frame_size": Vector2i(50, 40), "body_rect": Rect2(-15, -33, 31, 33), "leds": {0: Vector2i(22, 13), 1: Vector2i(22, 12), 2: Vector2i(21, 14), 3: Vector2i(19, 13), 4: Vector2i(22, 10), 5: Vector2i(22, 11)}, "muzzle": Vector2i(-1, -1), "bullet": "rivet", "elite_name": "SPARRING BOT", "title": "PRACTICE ROUND", "hp": 450, "moves": ["charge", "slam"]},
}

const TARGETS := {
	"target": {"texture": "res://art/enemies/tutorial/target.png", "hframes": 3, "frame_size": Vector2i(40, 22), "body_rect": Rect2(-6, -22, 12, 22), "leds": {0: Vector2i(20, 5), 1: Vector2i(-1, -1), 2: Vector2i(-1, -1)}},
	"target_shield": {"texture": "res://art/enemies/tutorial/target_shield.png", "hframes": 3, "frame_size": Vector2i(40, 22), "body_rect": Rect2(-12, -22, 18, 22), "leds": {0: Vector2i(20, 5), 1: Vector2i(-1, -1), 2: Vector2i(-1, -1)}},
	"target_rail": {"texture": "res://art/enemies/tutorial/target_rail.png", "hframes": 3, "frame_size": Vector2i(40, 22), "body_rect": Rect2(-6, -22, 12, 22), "leds": {0: Vector2i(20, 5), 1: Vector2i(-1, -1), 2: Vector2i(-1, -1)}},
}
