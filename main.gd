extends Node2D

var tower_scene = preload("res://static_body_2d.tscn")
var placed_towers = {}

var path_zones = [
	Rect2i(0, 0, 72, 4),
	Rect2i(68, 4, 4, 8),
	Rect2i(0, 12, 72, 4),
	Rect2i(0, 16, 4, 8),
	Rect2i(0, 24, 72, 4),
	Rect2i(68, 28, 4, 13),
]

var is_dragging = false
var gold = 100
var lives = 10
var tower_types = {
	"basic": {"cost": 50, "name": "基础塔"},
	"ice": {"cost": 75, "name": "冰塔"},
	"fire": {"cost": 100, "name": "火焰塔"},
	"laser": {"cost": 125, "name": "激光塔"},
}
var selected_tower = "basic"
var wave_number = 0
var enemies_alive = 0
var wave_enemies_left = 0
var wave_timer = 0.0
var spawn_interval = 1.0
var total_waves = 8
var wave_active = false
var game_started = false
var game_over = false
var game_won = false
var next_wave_timer = 0.0
var waiting_for_next_wave = false
var boss_spawned_this_wave = false

func _ready():
	$Camera2D.position = Vector2(576, 350)
	$Camera2D.zoom = Vector2(1.2, 1.2)
	$Camera2D.make_current()

	await get_tree().process_frame
	var ui = $CanvasLayer/UI
	ui.position = Vector2(20, 20)
	ui.size = Vector2(600, 500)
	ui.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ui.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	ui.clip_text = false
	ui.autowrap_mode = TextServer.AUTOWRAP_WORD
	ui.add_theme_font_size_override("font_size", 22)
	update_ui()

func _process(delta):
	if game_over or not game_started:
		return
	if wave_active:
		wave_timer -= delta
		if wave_timer <= 0 and wave_enemies_left > 0:
			# 每3波最后一波生成Boss
			if wave_enemies_left == 1 and wave_number % 3 == 0 and not boss_spawned_this_wave:
				spawn_enemy(true)
				boss_spawned_this_wave = true
			else:
				spawn_enemy(false)
			wave_enemies_left -= 1
			wave_timer = spawn_interval
			if wave_enemies_left <= 0:
				wave_active = false

	if waiting_for_next_wave:
		next_wave_timer -= delta
		if next_wave_timer <= 0:
			waiting_for_next_wave = false
			start_next_wave()

	if not wave_active and enemies_alive <= 0 and not waiting_for_next_wave:
		if wave_number >= total_waves:
			win_game()
		else:
			waiting_for_next_wave = true
			next_wave_timer = 3.0
			update_ui()

# 用 _input 替代 _unhandled_input，确保所有点击都能收到
func _input(event):
	if event is InputEventMouseMotion and is_dragging:
		$Camera2D.position -= event.relative / $Camera2D.zoom.x
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			$Camera2D.zoom *= 1.1
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			$Camera2D.zoom *= 0.9
			return

		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = true
			return

		if event.button_index == MOUSE_BUTTON_LEFT:
			place_tower(get_global_mouse_position())
			return

	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_dragging = false
			return

	var key_event = event as InputEventKey
	if key_event and key_event.pressed:
		match key_event.keycode:
			KEY_SPACE:
				if not game_started and not game_over:
					game_started = true
					start_next_wave()
			KEY_R:
				get_tree().reload_current_scene()
			KEY_1:
				selected_tower = "basic"
				update_ui()
			KEY_2:
				selected_tower = "ice"
				update_ui()
			KEY_3:
				selected_tower = "fire"
				update_ui()
			KEY_4:
				selected_tower = "laser"
				update_ui()

func place_tower(world_pos: Vector2):
	var tile_pos = $TileMap.local_to_map($TileMap.to_local(world_pos))

	if tile_pos.x < 0 or tile_pos.x >= 72 or tile_pos.y < 0 or tile_pos.y >= 42:
		return

	if is_path_tile(tile_pos):
		return

	var key = str(tile_pos.x) + "," + str(tile_pos.y)

	# 如果这个位置已经有塔了，点一下就是升级
	if key in placed_towers:
		var existing_tower = placed_towers[key]
		if is_instance_valid(existing_tower):
			upgrade_tower(existing_tower)
		return

	# 没有塔就新建
	var cost = tower_types[selected_tower].cost
	if gold < cost:
		return

	var tower = tower_scene.instantiate()
	tower.tower_type = selected_tower
	tower.position = $TileMap.map_to_local(tile_pos)
	add_child(tower)
	placed_towers[key] = tower
	gold -= cost
	update_ui()

func upgrade_tower(tower):
	if tower.level >= 3:
		return
	var upgrade_cost = int(tower_types[tower.tower_type].cost * 0.6 * tower.level)
	if gold < upgrade_cost:
		return
	gold -= upgrade_cost
	tower.level_up()
	update_ui()


func spawn_enemy(is_boss = false):
	var enemy = CharacterBody2D.new()
	enemy.position = Vector2(32, 32)

	var sprite = Sprite2D.new()
	sprite.name = "Sprite2D"

	var enemy_health: int
	var enemy_speed: float
	var enemy_size: int
	var enemy_gold: int

	if is_boss:
		enemy_health = (50 + wave_number * 20) * 5
		enemy_speed = 100.0 + wave_number * 5.0
		enemy_size = 80
		enemy_gold = 100
		sprite.texture = load("res://assets/enemies/boss_wave3.png")
	else:
		enemy_health = 50 + wave_number * 20
		enemy_speed = 200.0 + wave_number * 10.0
		enemy_size = 48
		enemy_gold = 25
		var img_index = clampi(wave_number, 1, 8)
		sprite.texture = load("res://assets/enemies/wave%d.png" % img_index)

	var tex_size = sprite.texture.get_width()
	sprite.scale = Vector2(float(enemy_size) / tex_size, float(enemy_size) / tex_size)
	enemy.add_child(sprite)

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(enemy_size, enemy_size)
	col.shape = shape
	enemy.add_child(col)

	var script = GDScript.new()

	script.source_code = """extends CharacterBody2D

var waypoints = [
	Vector2(32, 32),
	Vector2(1120, 32),
	Vector2(1120, 225),
	Vector2(32, 225),
	Vector2(32, 415),
	Vector2(1120, 415),
	Vector2(1120, 640),
]
var current_point = 0
var speed = """ + str(enemy_speed) + """
var health = """ + str(enemy_health) + """
var max_health = """ + str(enemy_health) + """
var is_boss = """ + str(is_boss) + """
var gold_reward = """ + str(enemy_gold) + """
var enemy_size = """ + str(enemy_size) + """
var main_scene = null
var slow_factor = 1.0
var slow_timer = 0.0
var anim_time = 0.0

func _ready():
	position = waypoints[0]
	add_to_group('enemy')

func _process(delta):
	anim_time += delta * speed * 0.05
	queue_redraw()

	# 程序化动画
	if has_node("Sprite2D"):
		var bounce = sin(anim_time * 6.0) * 3.0
		var tilt = sin(anim_time * 4.0) * 0.08
		$Sprite2D.position.y = bounce
		$Sprite2D.rotation = tilt

	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_factor = 1.0
			if not modulate == Color(3, 3, 3):
				modulate = Color(1, 1, 1)
	if current_point >= waypoints.size() - 1:
		if main_scene:
			main_scene.enemy_reached_end()
		queue_free()
		return
	var target = waypoints[current_point + 1]
	var direction = (target - position).normalized()
	position += direction * speed * slow_factor * delta
	if position.distance_to(target) < 5.0:
		position = target
		current_point += 1

func take_damage(amount):
	health -= amount
	modulate = Color(3, 3, 3)
	if health <= 0:
		if main_scene:
			main_scene.enemy_killed(gold_reward)
		queue_free()
		return
	queue_redraw()
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(self):
		if slow_timer > 0:
			modulate = Color(0.5, 0.8, 1)
		else:
			modulate = Color(1, 1, 1)

func apply_slow(factor, duration):
	slow_factor = factor
	slow_timer = duration
	modulate = Color(0.5, 0.8, 1)

func _draw():
	var sprite_size = enemy_size
	var half_h = sprite_size / 2.0
	var bar_width = 70 if is_boss else 40
	var bar_height = 7 if is_boss else 5
	var bar_y = -half_h - 12
	var bar_offset = Vector2(-bar_width / 2.0, bar_y)
	draw_rect(Rect2(bar_offset, Vector2(bar_width, bar_height)), Color(0, 0, 0, 0.8))
	var ratio = float(health) / float(max_health)
	var color = Color(1.0 - ratio, ratio, 0)
	draw_rect(Rect2(bar_offset, Vector2(bar_width * ratio, bar_height)), color)
"""

	script.reload()
	enemy.set_script(script)

	add_child(enemy)
	enemy.main_scene = self
	enemies_alive += 1
	if is_boss:
		enemy.gold_reward = 100
	else:
		enemy.gold_reward = 25
	update_ui()

func enemy_killed(reward = 25):
	gold += reward
	enemies_alive -= 1
	update_ui()

func enemy_reached_end():
	lives -= 1
	enemies_alive -= 1
	update_ui()
	if lives <= 0:
		lose_game()

func start_next_wave():
	wave_number += 1
	wave_enemies_left = 3 + wave_number * 2
	wave_active = true
	wave_timer = 0.5
	boss_spawned_this_wave = false
	update_ui()

func update_ui():
	var ui = $CanvasLayer/UI
	if ui == null:
		return
	var status = ""
	var cost = tower_types[selected_tower].cost
	if game_over:
		if game_won:
			status = "  胜 利 ！\n\n通关波次：%d / %d\n剩余生命：%d\n\n按 R 重新开始" % [total_waves, total_waves, lives]
		else:
			status = "  失 败\n\n坚持到第：%d / %d 波\n剩余金币：%d\n\n按 R 重新开始" % [wave_number, total_waves, gold]
	elif waiting_for_next_wave:
		status = "第 %d 波已完成\n下一波即将来袭...\n\n金币: %d\n生命: %d\n\n点已有的塔可以升级" % [wave_number, gold, lives]
	elif not game_started:
		status = "  方块塔防\n\n按空格开始游戏\n\n当前: %s (%d金)\n1:基础塔 50金  2:冰塔 75金\n3:火焰塔 100金  4:激光塔 125金\n\n金币: %d | 生命: %d\n\n左键放塔/升级  右键拖动  滚轮缩放" % [tower_types[selected_tower].name, cost, gold, lives]
	else:
		status = "第 %d / %d 波\n金币: %d | 生命: %d | 敌人: %d\n当前: %s (%d金)  1:基础 2:冰 3:火 4:激光\n点已有塔升级" % [wave_number, total_waves, gold, lives, enemies_alive, tower_types[selected_tower].name, cost]
	ui.text = status

func win_game():
	game_over = true
	game_won = true
	update_ui()

func lose_game():
	game_over = true
	update_ui()

func is_path_tile(tile_pos: Vector2i) -> bool:
	for zone in path_zones:
		if tile_pos.x >= zone.position.x \
		and tile_pos.x < zone.position.x + zone.size.x \
		and tile_pos.y >= zone.position.y \
		and tile_pos.y < zone.position.y + zone.size.y:
			return true
	return false
