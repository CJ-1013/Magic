extends "res://simple_enemy.gd"

## Boss 敌人 — 环形射击、冲锋、召唤，AI 有专用 CHARGE 状态

@export var special_cooldown: float = 4.0
@export var radial_bullet_count: int = 12
@export var charge_speed_mult: float = 3.0
@export var charge_duration: float = 0.6
@export var summon_count: int = 3
@export var summon_hp_threshold: float = 0.5

var special_timer: float = 0.0
var is_charging: bool = false
var charge_dir: Vector2 = Vector2.ZERO
var has_summoned: bool = false
var SimpleEnemyScene = preload("res://simple_enemy.tscn")

signal boss_defeated

func _ready():
	is_boss = true
	super._ready()
	special_timer = special_cooldown * 0.5

func _physics_process(delta):
	# 修复：必须在这里获取 player，否则基类逻辑中 player 为 null
	player = get_node_or_null("/root/Main/Player")
	if not player or is_dead:
		# 即使没有 player 也不 return，让父类处理
		return  # 但此时确实没有可做的事

	# 冲锋状态：直线冲刺无视 AI
	if is_charging:
		current_m = 0.5
		if m_grid_visuals:
			var gp = m_grid_visuals.world_to_grid(global_position)
			if gp != Vector2i(-1, -1):
				current_m = m_grid_visuals.get_m(gp.x, gp.y)
		velocity = charge_dir * speed * charge_speed_mult * speed_mult_override
		move_and_slide()
		$AnimatedSprite2D.speed_scale = 2.0
		$AnimatedSprite2D.animation = "walk"
		$AnimatedSprite2D.play()
		look_at(player.global_position)
		return

	# 使用父类的 AI 移动
	super._physics_process(delta)

	# 特殊技能
	special_timer += delta
	if special_timer >= special_cooldown:
		special_timer = 0.0
		_use_special_skill()

	# 召唤
	if not has_summoned and hp <= summon_hp_threshold * 800:
		has_summoned = true
		_summon_minions()

## 覆盖：Boss 的 AI 更新，偶尔主动冲锋
func _update_ai_state(dist: float):
	super._update_ai_state(dist)
	# Boss 有 15% 概率进入冲锋模式（当玩家距离适中时）
	if ai_state != AIState.RETREAT and ai_state_duration < 0.5:
		if randf() < 0.02:  # 每帧 2% 概率 ≈ 约每 2-3 秒一次检查
			if dist < 500 and dist > 120:
				ai_state = AIState.CHASE  # 追向玩家，配合特殊技能触发冲锋

## 特殊技能
func _use_special_skill():
	var r = randf()
	if r < 0.5:
		_radial_shot()
	elif r < 0.85:
		_start_charge()
	else:
		_radial_shot()
		await get_tree().create_timer(0.3).timeout
		if not is_dead:
			_start_charge()

func _radial_shot():
	print("Boss 环形射击!")
	for i in range(radial_bullet_count):
		var angle = TAU * i / radial_bullet_count
		var dir = Vector2.RIGHT.rotated(angle)
		var b = Bullet.instantiate()
		b.direction = dir
		b.rotation = angle
		b.camp = 1
		b.damage = bullet_damage
		b.global_position = global_position
		get_parent().add_child(b)

func _start_charge():
	if is_charging:
		return
	print("Boss 冲锋!")
	is_charging = true
	if player:
		charge_dir = (player.global_position - global_position).normalized()
	else:
		charge_dir = Vector2.RIGHT
	$AnimatedSprite2D.modulate = Color(1.0, 0.8, 0.3, 1.0)
	await get_tree().create_timer(charge_duration).timeout
	is_charging = false
	$AnimatedSprite2D.modulate = Color.WHITE

func _summon_minions():
	print("Boss 召唤小兵!")
	for i in range(summon_count):
		var spawn_pos = global_position + Vector2(
			randf_range(-100, 100),
			randf_range(-100, 100)
		)
		var minion = SimpleEnemyScene.instantiate()
		minion.position = spawn_pos
		minion.speed = 250
		minion.hp = 15
		minion.shoot_cooldown = 2.5
		minion.bullet_damage = 5
		get_parent().add_child(minion)

func take_damage(amount):
	if is_dead:
		return
	hp -= int(ceil(amount))
	print("Boss hp: ", hp)
	if hp <= 0 and not is_dead:
		is_dead = true
		died.emit()
		boss_defeated.emit()
		print("Boss 被击败！")
		queue_free()
