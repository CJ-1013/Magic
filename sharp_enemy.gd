extends "res://simple_enemy.gd"

## 精英敌人 — 爆发射击 + 激怒机制
## AI 在激怒时更激进（更倾向 CHASE 状态）

@export var burst_count: int = 3
@export var burst_interval: float = 0.08
@export var enrage_hp_ratio: float = 0.3

var is_enraged: bool = false
var is_bursting: bool = false

func _ready():
	is_elite = true
	super._ready()

func _physics_process(delta):
	# 激怒时更激进
	if is_enraged:
		preferred_distance = 120.0  # 更贴近玩家
		retreat_hp_ratio = 0.0      # 不后退
	super._physics_process(delta)

	# 动画速度跟随激怒
	if is_enraged:
		$AnimatedSprite2D.speed_scale = 1.5
	else:
		$AnimatedSprite2D.speed_scale = 1.0

## 覆盖：激怒时加速
func _get_speed_mult(m_val: float) -> float:
	var base = super._get_speed_mult(m_val)
	if is_enraged:
		base *= 1.5
	return base

## 覆盖：爆发射击
func _try_shoot():
	if is_bursting:
		return
	_start_burst()

func _start_burst():
	is_bursting = true
	for i in range(burst_count):
		if is_dead or not player:
			break
		shoot_at_player(player.global_position)
		await get_tree().create_timer(burst_interval).timeout
	is_bursting = false

func take_damage(amount):
	if is_dead:
		return
	hp -= int(ceil(amount))
	if not is_enraged and hp <= enrage_hp_ratio * 80:
		is_enraged = true
		shoot_cooldown *= 0.5
		burst_count=7
		speed_mult_override = 1.5
		$AnimatedSprite2D.modulate = Color(0.001, 0.022, 0.049, 1.0)
		print("精英敌人进入激怒状态！")
	if hp <= 0:
		is_dead = true
		died.emit()
		queue_free()
