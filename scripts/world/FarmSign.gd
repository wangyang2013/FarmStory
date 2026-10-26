class_name FarmSign
extends Node2D
## 农场入口木牌：显示新游戏时自定义的牧场名称。

const Art := preload("res://scripts/art/PixelArt.gd")
const UITheme := preload("res://scripts/ui/PixelTheme.gd")

var farm_name := ""


func setup(world_position: Vector2, name_text: String) -> void:
	position = world_position
	z_index = 0
	set_farm_name(name_text)
	queue_redraw()


## 文字由 GameUI 以屏幕空间绘制，避免相机 0.75 缩放把像素字压碎。
func set_farm_name(value: String) -> void:
	farm_name = value
	queue_redraw()


func _draw() -> void:
	Art.shadow(self, 0, -0.4, 16.0, 2.0)
	# 立柱
	Art.rect(self, -2.0, -30.0, 4.0, 30.0, Art.WOOD_DARK)
	Art.rect(self, -1.2, -30.0, 1.2, 30.0, Art.WOOD)
	# 底板 + 边框（略加宽，容纳 8 字牧场名）
	Art.rrect(self, -36.0, -46.0, 72.0, 18.0, 2.0, Color("#b08a62"))
	Art.rrect(self, -34.5, -44.5, 69.0, 15.0, 1.5, Color("#e3d0a4"))
	# 顶部小屋顶
	Art.poly(self, PackedVector2Array([
		Vector2(-38.0, -46.0), Vector2(38.0, -46.0),
		Vector2(32.0, -51.0), Vector2(-32.0, -51.0),
	]), Color("#8c5a3c"))
	Art.rect(self, -36.0, -47.0, 72.0, 1.2, Color("#c9a276"))
	# 钉子
	Art.rect(self, -32.0, -43.0, 1.0, 1.0, Color("#6f5438"))
	Art.rect(self, 31.0, -43.0, 1.0, 1.0, Color("#6f5438"))
