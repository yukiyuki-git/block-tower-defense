extends CharacterBody2D

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
var speed = 300.0
var health = 100

func _ready():
	position = waypoints[0]
	add_to_group("enemy")

func _process(delta):
	if current_point >= waypoints.size() - 1:
		return

	var target = waypoints[current_point + 1]
	var direction = (target - position).normalized()
	position += direction * speed * delta

	if position.distance_to(target) < 5.0:
		position = target
		current_point += 1

func take_damage(amount):
	health -= amount
	print("怪物剩余血量: ", health)
	modulate = Color(0, 1, 1)
	await get_tree().create_timer(0.2).timeout
	modulate = Color(1, 1, 1)
	if health <= 0:
		queue_free()
