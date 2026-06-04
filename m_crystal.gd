extends Node2D

@export var produce_interval: float = 1.0
@export var produce_radius: int = 1
@export var produce_amount: float = 0.15

var total_m_threshold: float = 0   # 房间M总量超过此值则暂停产出
var m_grid_visuals
var timer: Timer
var disabled: bool = false

func _ready():
	# 从父房间直接获取 M_Grid_Visuals（推荐）
	var parent = get_parent()
	if parent and parent.has_node("M_Grid_Visuals"):
		m_grid_visuals = parent.get_node("M_Grid_Visuals")
	else:
		# 备用方案：通过 Main 获取
		var main_node = get_node_or_null("/root/Main")
		if main_node and main_node.has_method("get_m_grid_visuals"):
			m_grid_visuals = main_node.get_m_grid_visuals()

	# 计算阈值
	if m_grid_visuals:
		total_m_threshold = m_grid_visuals.grid_width * m_grid_visuals.grid_height * 0.7
	else:
		total_m_threshold = 200

	timer = $ProduceTimer
	timer.wait_time = produce_interval
	timer.timeout.connect(_on_produce)
	$AnimatedSprite2D.play("flowing")

func _on_produce():
	if not m_grid_visuals:
		return
	if disabled:
		return

	# 计算当前房间M总量
	var total_m = 0.0
	for y in range(m_grid_visuals.grid_height):
		for x in range(m_grid_visuals.grid_width):
			total_m += m_grid_visuals.get_m(x, y)

	if total_m >= total_m_threshold:
		return

	var center = m_grid_visuals.world_to_grid(global_position)
	if center == Vector2i(-1, -1):
		return

	for dx in range(-produce_radius, produce_radius + 1):
		for dy in range(-produce_radius, produce_radius + 1):
			var nx = center.x + dx
			var ny = center.y + dy
			if nx >= 0 and nx < m_grid_visuals.grid_width and ny >= 0 and ny < m_grid_visuals.grid_height:
				var old = m_grid_visuals.get_m(nx, ny)
				var new_val = min(old + produce_amount, 1.0)
				m_grid_visuals.set_m(nx, ny, new_val)

	m_grid_visuals.flow_step()
