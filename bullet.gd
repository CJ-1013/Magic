extends Area2D

@export var speed: int = 2500
@export var damage: int = 10
@export var camp: int = 0          # 0=玩家, 1=敌人
@export var life_time: float = 1.0

var direction: Vector2

func _ready():
	add_to_group("projectile")
	if camp == 0:
		add_to_group("player_bullet")
	elif camp == 1:
		add_to_group("enemy_bullet")
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _process(delta):
	position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# 碰到墙壁或障碍物时销毁
	if body is TileMapLayer or body is StaticBody2D:
		queue_free()

func _on_area_entered(area):
	if camp == 0:   # 玩家子弹
		var target = area
		if area.is_in_group("enemy"):
			# Hitbox 的父节点是敌人
			if area.get_parent() and area.get_parent().has_method("take_damage"):
				target = area.get_parent()
			if target.has_method("take_damage"):
				target.take_damage(damage)
				queue_free()
	elif camp == 1: # 敌人子弹
		# 检测是否击中玩家的 Hurtbox
		if area.get_parent() and area.get_parent().is_in_group("player"):
			var player = area.get_parent()
			if player.has_method("take_damage_player"):
				player.take_damage_player(damage)
				queue_free()
