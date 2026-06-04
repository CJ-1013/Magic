extends CharacterBody2D

## 敌人基类 — 包含 AI 状态机
## 子类可覆盖 _try_shoot() 和 _get_speed_mult() 自定义行为

@export var speed: int = 400
@export var hp: int = 30
@export var shoot_cooldown: float = 1.5
@export var shoot_range: float = 400.0
@export var bullet_damage: int = 8
@export var is_boss: bool = false
@export var is_elite: bool = false
@export var low_m_dps: float = 8.0

# AI 参数
@export var preferred_distance: float = 250.0   # 偏好距离（太近会后退）
@export var strafe_amplitude: float = 120.0      # 横向移动幅度
@export var retreat_hp_ratio: float = 0.25       # 低于此比例尝试后退

enum AIState { CHASE, CIRCLING, RETREAT, CHARGE }
var ai_state: AIState = AIState.CHASE
var ai_timer: float = 0.0
var ai_dir: int = 1           # 绕圈方向 (1 或 -1)
var ai_state_duration: float = 0.0
var ai_strafe_target: Vector2 = Vector2.ZERO

var m_grid_visuals: Node2D
var Bullet = preload("res://bullet.tscn")
var time_since_last_shot: float = 0.0
var player: Node2D = null
var is_dead: bool = false
var current_m: float = 0.5
var speed_mult_override: float = 1.0

signal died

func _ready():
	$Hitbox.area_entered.connect(_on_hitbox_area_entered)
	m_grid_visuals = get_parent().get_m_grid_visuals()
	ai_dir = 1 if randf() < 0.5 else -1

	if is_boss:
		hp = 1600
		shoot_cooldown = 0.8
		speed = 200
		preferred_distance = 300.0
	elif is_elite:
		hp = 160
		shoot_cooldown = 1.0
		speed = 180
		preferred_distance = 220.0

func _physics_process(delta):
	# 每帧定位玩家
	player = get_node_or_null("/root/Main/Player")
	if not player or is_dead:
		return

	# M 浓度
	current_m = 0.5
	if m_grid_visuals:
		var grid_pos = m_grid_visuals.world_to_grid(global_position)
		if grid_pos != Vector2i(-1, -1):
			current_m = m_grid_visuals.get_m(grid_pos.x, grid_pos.y)

	var speed_mult = _get_speed_mult(current_m)
	if current_m < 0.3:
		take_damage(low_m_dps * delta)

	var dist = global_position.distance_to(player.global_position)
	var dir_to_player = (player.global_position - global_position).normalized()

	# === AI 状态机 ===
	ai_state_duration += delta
	_update_ai_state(dist)

	var move_velocity = Vector2.ZERO
	match ai_state:
		AIState.CHASE:
			move_velocity = dir_to_player * speed * speed_mult * speed_mult_override
		AIState.CIRCLING:
			var tangent = dir_to_player.rotated(PI / 2) * ai_dir
			move_velocity = tangent * speed * 0.7 * speed_mult * speed_mult_override
			# 保持距离
			if dist > preferred_distance + 60:
				move_velocity += dir_to_player * speed * 0.3 * speed_mult_override
			elif dist < preferred_distance - 60:
				move_velocity -= dir_to_player * speed * 0.3 * speed_mult_override
		AIState.RETREAT:
			move_velocity = -dir_to_player * speed * 0.8 * speed_mult * speed_mult_override

	velocity = move_velocity
	move_and_slide()

	# 射击
	if dist <= shoot_range:
		time_since_last_shot += delta
		if time_since_last_shot >= shoot_cooldown:
			_try_shoot()
			time_since_last_shot = 0.0

	# 动画
	if velocity.length() > 10:
		$AnimatedSprite2D.animation = "walk"
	else:
		$AnimatedSprite2D.animation = "breathe"
	$AnimatedSprite2D.play()
	look_at(player.global_position)

## AI 状态切换
func _update_ai_state(dist: float):
	# 低血量尝试后退
	var hp_ratio = hp / (800.0 if is_boss else (80.0 if is_elite else 40.0))
	if hp_ratio < retreat_hp_ratio and ai_state != AIState.RETREAT:
		ai_state = AIState.RETREAT
		ai_state_duration = 0.0
		return

	if ai_state == AIState.RETREAT:
		if ai_state_duration > 1.5 or hp_ratio > retreat_hp_ratio + 0.15:
			ai_state = AIState.CIRCLING
			ai_state_duration = 0.0
			ai_dir = 1 if randf() < 0.5 else -1
		return

	# 每 2~4 秒切换一次状态
	if ai_state_duration > randf_range(2.0, 4.0):
		var r = randf()
		if dist > preferred_distance + 100:
			ai_state = AIState.CHASE
		elif dist < preferred_distance - 100:
			ai_state = AIState.CIRCLING if randf() < 0.7 else AIState.CHASE
			if ai_state == AIState.CIRCLING:
				ai_dir = 1 if randf() < 0.5 else -1
		else:
			ai_state = AIState.CIRCLING if randf() < 0.6 else AIState.CHASE
			if ai_state == AIState.CIRCLING:
				ai_dir = 1 if randf() < 0.5 else -1
		ai_state_duration = 0.0

## 速度倍率（子类可覆盖）
func _get_speed_mult(m_val: float) -> float:
	if m_val > 0.7:
		return 0.4
	return 1.0

## 射击行为（子类可覆盖）
func _try_shoot():
	shoot_at_player(player.global_position)

func shoot_at_player(target_pos: Vector2):
	var b = Bullet.instantiate()
	var dir = (target_pos - global_position).normalized()
	b.direction = dir
	b.rotation = dir.angle()
	b.camp = 1
	b.damage = bullet_damage
	b.global_position = global_position
	get_parent().add_child(b)

func _on_hitbox_area_entered(area):
	if area.is_in_group("player_bullet"):
		take_damage(area.get("damage"))
		area.queue_free()

func take_damage(amount):
	if is_dead:
		return
	hp -= int(ceil(amount))
	if hp <= 0:
		is_dead = true
		died.emit()
		queue_free()
