extends Area2D

@export var explosion_radius: int = 1
@export var fix_ratio_min:float = 0.2
var direction: Vector2
var speed: float = 800
var m_grid_visuals
var exploded: bool = false
var boom_sounds: Array[AudioStream] = [
	preload("res://resource/sound/Boom_1.wav"),
	preload("res://resource/sound/Boom_2.wav"),
	preload("res://resource/sound/Boom_3.wav")
]

func _ready():
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	$ExplodeTimer.start()
	m_grid_visuals = get_parent().get_m_grid_visuals()
	$AnimatedSprite2D.animation = "default"
	# 注意：删除了重复的 $ExplodeTimer.start()


func _on_body_entered(body):
	# 碰到任何物理体（墙等）立即爆炸，但不要碰到玩家就炸（留给 area_entered 处理敌人）
	print(body)
	if not body.is_in_group("player"):
		_on_explode()

func _process(delta):
	var fix_ratio = (fix_ratio_min + (1-fix_ratio_min)* ($ExplodeTimer.time_left / $ExplodeTimer.wait_time) ** 2)
	if not exploded:
		rotate(25 * delta * fix_ratio)
	position += direction * speed * fix_ratio * delta

func _on_explode():
	$AudioStreamPlayer2D.stream = boom_sounds[randi() % boom_sounds.size()]
	if exploded:
		return
	exploded = true
	if not m_grid_visuals:
		$AnimatedSprite2D.play("explore")
		return
	var center = m_grid_visuals.world_to_grid(global_position)
	var total_m_change = 0.0
	fix_ratio_min=0
	speed=0
	
	if center != Vector2i(-1, -1):
		for dx in range(-explosion_radius, explosion_radius + 1):
			for dy in range(-explosion_radius, explosion_radius + 1):
				var nx = center.x + dx
				var ny = center.y + dy
				if nx >= 0 and nx < m_grid_visuals.grid_width and ny >= 0 and ny < m_grid_visuals.grid_height:
					var old = m_grid_visuals.get_m(nx, ny)
					var decrease = randf_range(0.3, 0.6)
					var new_val = max(old - decrease, 0.0)
					m_grid_visuals.set_m(nx, ny, new_val)
					total_m_change += (old - new_val)
		m_grid_visuals.flow_step()
	
	var damage = int(total_m_change * 50)
	print("手榴弹爆炸，M 总变化: ", total_m_change, " 伤害: ", damage)
	
	# 对爆炸范围内的敌人造成伤害（Hitbox 在 enemy 组，父节点是敌人）
	var overlapping = get_overlapping_areas()
	for area in overlapping:
		if area.is_in_group("enemy"):
			var target = area.get_parent() if area.get_parent() and area.get_parent().has_method("take_damage") else area
			if target.has_method("take_damage"):
				target.take_damage(damage)
		elif area.has_method("take_damage"):
			area.take_damage(damage)
	# 镜头震动
	var player = get_node_or_null("/root/Main/Player")
	if player and player.has_method("shake_screen"):
		player.shake_screen(50,0.3)
	$AudioStreamPlayer2D.play()
	scale*=2
	$AnimatedSprite2D.play("explore")


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy"):
		_on_explode()


func _on_animated_sprite_2d_animation_finished() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.8)
	tween.tween_callback(queue_free)  # 动画结束后销毁


func _on_animated_sprite_2d_animation_changed() -> void:
	$AnimatedSprite2D.rotate(randf_range(0,2*PI))
