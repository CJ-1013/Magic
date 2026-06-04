extends CharacterBody2D

@export var speed: int = 150
@export var shoot_interval: float = 0.15
@export var max_grenades: int = 3
@export var grenade_regen_time: float = 5.0
@export var camera_offset_strength: float = 0.1
@export var camera_max_offset: float = 150.0
@export var state_buffer_duration: float = 0.7
@export var player_hp: int = 100

@onready var crosshair = $Crosshair
@onready var camera = get_node("/root/Main/Camera")
@onready var crosshair_texture = $Crosshair/CrosshairTexture
@onready var main_node = get_node("/root/Main")
@export var crosshair_red: Texture2D = preload("res://resource/UI/crosshair_0.png")
@export var crosshair_yellow: Texture2D = preload("res://resource/UI/crosshair_1.png")
@export var crosshair_green: Texture2D = preload("res://resource/UI/crosshair_2.png")

# ---- 准心状态 ----
enum CrosshairState { LOW, MEDIUM, HIGH }
var current_state: CrosshairState = CrosshairState.MEDIUM
var target_state: CrosshairState = CrosshairState.MEDIUM
var state_buffer_active: bool = false
var state_buffer_timer: float = 0.0

# ---- 手雷 ----
var grenade_count: int = max_grenades
var grenade_regen_timer: float = 0.0

# ---- 射击 ----
var shoot_timer: float = 0.0

# ---- 冲刺 ----
var not_in_Rush_CD: bool = true
var is_Rushing: bool = false
var m_grid_visuals

# ---- 震屏 ----
var shake_amplitude: float = 0.0
var shake_duration: float = 0.0
var shake_elapsed: float = 0.0
var shake_offset: Vector2 = Vector2.ZERO

# ---- 预加载 ----
var Bullet = preload("res://bullet.tscn")
var Grenade = preload("res://grenade.tscn")
var scaning_sound = preload("res://resource/Sound/Scaning.wav")

func shake_screen(amplitude: float = 10.0, duration: float = 0.3):
	shake_amplitude = amplitude
	shake_duration = duration
	shake_elapsed = 0.0

func take_damage_player(amount):
	player_hp -= amount
	print("Player hp: ", player_hp)
	if player_hp <= 0:
		_on_player_death()

func _on_player_death():
	# 死亡处理由 Main 节点接管，这里只做视觉反馈
	print("玩家死亡！")
	set_physics_process(false)
	set_process(false)
	hide()

func refresh_m_grid_visuals():
	m_grid_visuals = main_node.get_m_grid_visuals()

func _ready():
	$Hurtbox.body_entered.connect(_on_hurt_box_body_entered)
	$Hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	_switch_crosshair_state(CrosshairState.MEDIUM)

func _physics_process(delta: float) -> void:
	# 延迟初始化 m_grid_visuals
	if not m_grid_visuals:
		m_grid_visuals = main_node.get_m_grid_visuals()
		if not m_grid_visuals:
			return

	look_at(get_global_mouse_position())
	var input_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)

	# ---------- M 浓度效果 ----------
	var player_cell = m_grid_visuals.world_to_grid(global_position)
	var current_m = 0.5
	if player_cell != Vector2i(-1, -1):
		current_m = m_grid_visuals.get_m(player_cell.x, player_cell.y)

	# 高浓度减速
	var speed_mult = 1.0
	if current_m > 0.8:
		speed_mult = 0.6

	# 低浓度持续伤害
	if current_m < 0.25 and not is_Rushing:
		take_damage_player(5 * delta)

	# ---------- 冲刺 ----------
	var target_velocity = input_dir * speed * speed_mult

	if not_in_Rush_CD and not is_Rushing and Input.is_action_just_pressed("rush"):
		var center = player_cell
		var total_m = 0.0
		var cells_to_drain = []
		if center != Vector2i(-1, -1):
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var nx = center.x + dx
					var ny = center.y + dy
					if nx >= 0 and nx < m_grid_visuals.grid_width and ny >= 0 and ny < m_grid_visuals.grid_height:
						var val = m_grid_visuals.get_m(nx, ny)
						total_m += val
						cells_to_drain.append(Vector2i(nx, ny))

		if total_m >= 0.6:
			for cell in cells_to_drain:
				var old = m_grid_visuals.get_m(cell.x, cell.y)
				var new_val = max(old - 0.1, 0.0)
				m_grid_visuals.set_m(cell.x, cell.y, new_val)
			is_Rushing = true
			$Rush.start()
			print("冲刺发动，消耗 M")
		else:
			print("M 不足，无法冲刺")

	if is_Rushing:
		target_velocity = input_dir * speed * 2.5

	velocity = target_velocity
	move_and_slide()

	# ---------- 扫描 ----------
	if Input.is_action_just_pressed("detect_M"):
		if m_grid_visuals and m_grid_visuals.start_scan():
			$noisemaker.stream = scaning_sound
			$noisemaker.play()

	# ---------- 动画 ----------
	if velocity.length() > 0:
		$AnimatedSprite2D.animation = "rush" if is_Rushing else "walk"
	else:
		$AnimatedSprite2D.animation = "breathe"
	$AnimatedSprite2D.play()

	# ---------- 玩家网格位置更新 ----------
	if player_cell != Vector2i(-1, -1):
		m_grid_visuals.set_player_grid(player_cell)

	# ---------- 准心 ----------
	crosshair.global_position = get_global_mouse_position()
	crosshair.rotation = -rotation

	# ---------- 准心状态缓冲（复用已有的 player_cell，不再重复计算）----------
	if player_cell != Vector2i(-1, -1):
		var m_value = current_m   # 复用上面计算好的值
		var new_state: CrosshairState
		if m_value < 0.3:
			new_state = CrosshairState.LOW
		elif m_value < 0.7:
			new_state = CrosshairState.MEDIUM
		else:
			new_state = CrosshairState.HIGH

		if new_state != current_state:
			target_state = new_state
			if not state_buffer_active:
				state_buffer_active = true
				state_buffer_timer = 0.0
		elif state_buffer_active and target_state == current_state:
			state_buffer_active = false

func _process(delta):
	# 鼠标偏移计算（相机跟随）
	var mouse_world_pos = get_global_mouse_position()
	var offset_global = mouse_world_pos - global_position
	var final_offset_global = Vector2.ZERO

	if abs(offset_global.x) > 800:
		final_offset_global.x = offset_global.x * camera_offset_strength
	if abs(offset_global.y) > 400:
		final_offset_global.y = offset_global.y * camera_offset_strength

	final_offset_global = final_offset_global.limit_length(camera_max_offset)

	# 震屏偏移
	var shake_offset_global = Vector2.ZERO
	if shake_elapsed < shake_duration:
		shake_elapsed += delta
		var decay = 1.0 - (shake_elapsed / shake_duration)
		shake_offset_global = Vector2(
			randf_range(-1, 1) * shake_amplitude * decay,
			randf_range(-1, 1) * shake_amplitude * decay
		)

	# 更新相机位置
	if camera:
		camera.global_position = global_position + final_offset_global + shake_offset_global

	# 射击
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			shoot_timer = shoot_interval
			_shoot()

	# 手榴弹自然回复
	if grenade_count < max_grenades:
		grenade_regen_timer += delta
		if grenade_regen_timer >= grenade_regen_time:
			grenade_count += 1
			grenade_regen_timer -= grenade_regen_time
			print("手榴弹回复：", grenade_count)
			if grenade_count >= max_grenades:
				grenade_regen_timer = 0.0

	# 准心状态缓冲计时器
	if state_buffer_active:
		state_buffer_timer += delta
		if state_buffer_timer >= state_buffer_duration:
			_switch_crosshair_state(target_state)
			state_buffer_active = false

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		throw_grenade()

func _shoot():
	if not m_grid_visuals:
		return

	var center = m_grid_visuals.world_to_grid(global_position)
	var total_consumed = 0.0
	if center != Vector2i(-1, -1):
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var nx = center.x + dx
				var ny = center.y + dy
				if nx >= 0 and nx < m_grid_visuals.grid_width and ny >= 0 and ny < m_grid_visuals.grid_height:
					var old = m_grid_visuals.get_m(nx, ny)
					var new_val = max(old - 0.2, 0.25)
					m_grid_visuals.set_m(nx, ny, new_val)
					total_consumed += (old - new_val)
		m_grid_visuals.flow_step()

	var b = Bullet.instantiate()
	var shoot_offset: float = randf_range(-7.5, 7.5) * PI / 180
	b.direction = Vector2.RIGHT.rotated(rotation + shoot_offset)
	b.rotation = rotation + shoot_offset
	b.global_position = position
	b.damage = 10 + int(total_consumed * 15)
	b.camp = 0
	get_parent().add_child(b)

func _on_rush_timeout() -> void:
	not_in_Rush_CD = false
	is_Rushing = false
	$RushCD.start()

func _on_rush_cd_timeout() -> void:
	not_in_Rush_CD = true
	var sprite = $AnimatedSprite2D
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.2)

# 伤害区域信号处理
func _on_hurt_box_body_entered(body: Node2D) -> void:
	if is_Rushing:
		return
	if body.is_in_group("enemy"):
		take_damage_player(10)
		var knockback_dir = (global_position - body.global_position).normalized()
		velocity += knockback_dir * 400

func _on_hurtbox_area_entered(area: Area2D):
	if is_Rushing:
		return
	if area.is_in_group("enemy_bullet"):
		take_damage_player(area.get("damage") if area.has_method("get") else 5)
		area.queue_free()

func throw_grenade():
	if grenade_count <= 0:
		print("手榴弹不足")
		return
	grenade_count -= 1
	print("投掷手榴弹，剩余：", grenade_count)
	var g = Grenade.instantiate()
	g.direction = (get_global_mouse_position() - global_position).normalized()
	g.global_position = global_position
	get_parent().add_child(g)

func _switch_crosshair_state(new_state: CrosshairState):
	current_state = new_state
	match new_state:
		CrosshairState.LOW:
			crosshair_texture.texture = crosshair_red
		CrosshairState.MEDIUM:
			crosshair_texture.texture = crosshair_yellow
		CrosshairState.HIGH:
			crosshair_texture.texture = crosshair_green

# 用于重生时重置位置
func start(pos: Vector2):
	position = pos
	show()
	refresh_m_grid_visuals()
