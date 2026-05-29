extends StaticBody2D

var tower_type = "basic"
var level = 1
var enemies_in_range = []
var damage = 25
var attack_radius = 250.0
var is_attacking = false
var attack_interval = 1.0
var slow_factor = 0.5
var slow_duration = 2.0

# 基础属性表（level 1）
var base_damage = 25
var base_radius = 250.0
var base_interval = 1.0

func _ready():
	configure_by_type()
	$Timer.timeout.connect(_shoot)
	$Timer.wait_time = attack_interval
	$Timer.start()
	queue_redraw()

func configure_by_type():
	match tower_type:
		"basic":
			base_damage = 25
			base_radius = 250.0
			base_interval = 1.0
		"ice":
			base_damage = 10
			base_radius = 200.0
			base_interval = 0.8
		"fire":
			base_damage = 40
			base_radius = 150.0
			base_interval = 2.0
		"laser":
			base_damage = 15
			base_radius = 350.0
			base_interval = 0.3
	apply_level_stats()
	update_sprite()

func apply_level_stats():
	var multiplier = 1.0 + (level - 1) * 0.4
	damage = int(base_damage * multiplier)
	attack_radius = base_radius + (level - 1) * 30
	attack_interval = base_interval * pow(0.85, level - 1)

	var circle = CircleShape2D.new()
	circle.radius = attack_radius
	$Area2D/CollisionShape2D.shape = circle

	$Timer.wait_time = attack_interval

func update_sprite():
	var tex = GradientTexture2D.new()
	tex.width = 48
	tex.height = 48
	var grad = Gradient.new()
	var size_val = 1.0 - (level - 1) * 0.15
	match tower_type:
		"basic":
			grad.colors = PackedColorArray([
				Color(0.27 * (2.0 - size_val), 0.53 * (2.0 - size_val), 0.8 * (2.0 - size_val))
			])
		"ice":
			grad.colors = PackedColorArray([
				Color(0.4 * (2.0 - size_val), 0.85 * (2.0 - size_val), 1.0)
			])
		"fire":
			grad.colors = PackedColorArray([
				Color(0.9, 0.4 * (2.0 - size_val), 0.1 * (2.0 - size_val))
			])
		"laser":
			grad.colors = PackedColorArray([
				Color(0.6 * (2.0 - size_val), 0.2 * (2.0 - size_val), 0.9)
			])
	tex.gradient = grad
	$Sprite2D.texture = tex
	$Sprite2D.scale = Vector2(1.0 + (level - 1) * 0.15, 1.0 + (level - 1) * 0.15)

func level_up():
	level += 1
	apply_level_stats()
	update_sprite()
	queue_redraw()

func _process(delta):
	var was_attacking = is_attacking
	enemies_in_range = enemies_in_range.filter(
		func(e): return is_instance_valid(e)
	)
	is_attacking = enemies_in_range.size() > 0
	if is_attacking != was_attacking:
		queue_redraw()

func _on_area_2d_body_entered(body):
	if body.is_in_group("enemy"):
		enemies_in_range.append(body)
		queue_redraw()

func _on_area_2d_body_exited(body):
	enemies_in_range.erase(body)
	queue_redraw()

func _shoot():
	enemies_in_range = enemies_in_range.filter(
		func(e): return is_instance_valid(e)
	)
	if enemies_in_range.is_empty():
		return

	match tower_type:
		"fire":
			for enemy in enemies_in_range:
				if is_instance_valid(enemy):
					enemy.take_damage(damage)
		"ice":
			var target = enemies_in_range[0]
			target.take_damage(damage)
			if target.has_method("apply_slow"):
				target.apply_slow(slow_factor, slow_duration)
		_:
			var target = enemies_in_range[0]
			target.take_damage(damage)

	queue_redraw()

	var base_scale = 1.0 + (level - 1) * 0.15
	$Sprite2D.scale = Vector2(base_scale, base_scale) * 1.3
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(base_scale, base_scale), 0.15).set_ease(Tween.EASE_OUT)


func _draw():
	# 等级标记（小方块）
	var marker_offset = Vector2(-20, -42)
	for i in range(level):
		var c = Color(1, 1, 0, 0.9)
		draw_rect(Rect2(marker_offset + Vector2(i * 8, 0), Vector2(5, 5)), c)

	# 攻击范围
	var color_idle: Color
	var color_attack: Color
	match tower_type:
		"basic":
			color_idle = Color(0.3, 0.7, 1, 0.05)
			color_attack = Color(0.3, 0.7, 1, 0.12)
		"ice":
			color_idle = Color(0.4, 0.85, 1, 0.08)
			color_attack = Color(0.5, 0.9, 1, 0.18)
		"fire":
			color_idle = Color(1, 0.5, 0.1, 0.06)
			color_attack = Color(1, 0.3, 0.0, 0.18)
		"laser":
			color_idle = Color(0.6, 0.2, 0.9, 0.05)
			color_attack = Color(0.8, 0.3, 1, 0.15)

	if is_attacking:
		draw_circle(Vector2.ZERO, attack_radius, color_attack)
		var edge = color_attack
		edge.a = 0.5
		draw_arc(Vector2.ZERO, attack_radius, 0, TAU, 64, edge, 2.0)
	else:
		draw_circle(Vector2.ZERO, attack_radius, color_idle)
		var edge = color_idle
		edge.a = 0.3
		draw_arc(Vector2.ZERO, attack_radius, 0, TAU, 64, edge, 1.0)
