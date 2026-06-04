extends Node2D

# 网格参数
@export var grid_width: int = 30
@export var grid_height: int = 20
@export var cell_size: Vector2 = Vector2(25, 25)
@export var start_position: Vector2 = Vector2(25, 25)

# 扫描波参数
@export var initial_wave_speed: float = 120
@export var display_duration: float = 3
@export var max_distance: int = 23
var scan_origin_grid: Vector2i = Vector2i(-1, -1)
var default_alpha: float = 0.2   # 常态透明度（之前你可能是 0.97，这里改低一点更好看）
# M数据
var m_data: Array[Array] = []
var color_rects: Array[Array] = []
var decrease_disabled:bool=false
# 扫描状态
var is_scanning: bool = false
var scan_start_time: float = 0.0
var player_grid: Vector2i = Vector2i(-1, -1)

# ===== 新增：流动参数 =====
@export var flow_rate: float = 0.08         # 流动速率 (0~1)
@export var flow_threshold: float = 0.01   # 浓度差阈值
@export var auto_flow_interval: float = 0.1 # 自动流动间隔（秒），0表示关闭自动流动
signal scan_end
func _ready():
	_create_grid()
	_init_m_data()
	init_test_pattern()   # 使用测试图案（左边高右边低）
	_update_all_colors()
	# ===== 新增：自动流动定时器 =====
	if auto_flow_interval > 0:
		var flow_timer = Timer.new()
		flow_timer.wait_time = auto_flow_interval
		flow_timer.autostart = true
		flow_timer.timeout.connect(_on_flow_timer_timeout)
		add_child(flow_timer)

func _create_grid():
	for y in range(grid_height):
		var row: Array = []
		for x in range(grid_width):
			var rect = ColorRect.new()
			rect.size = cell_size
			rect.position = start_position + Vector2(x * cell_size.x, y * cell_size.y)
			rect.color = Color.WHITE
			add_child(rect)
			row.append(rect)
		color_rects.append(row)

func _init_m_data():
	m_data.clear()
	for y in range(grid_height):
		var row: Array[float] = []
		for x in range(grid_width):
			row.append(0.5)
		m_data.append(row)

# 测试图案：从左到右梯度（左1.0，右0.0）
func init_test_pattern():
	for y in range(grid_height):
		for x in range(grid_width):
			m_data[y][x] = randf()
	_update_all_colors()

func _update_all_colors():
	for y in range(grid_height):
		for x in range(grid_width):
			_update_single_color(x, y)

func _update_single_color(x: int, y: int):
	var value = m_data[y][x]
	var color = Color(1.0, 1-value, 1.0, 1.0)
	
	# 计算透明度（你原有的扫描波逻辑，没有改动）
	var alpha = 0.0
	if is_scanning and scan_origin_grid != Vector2i(-1, -1):
		
		var dist = sqrt((x - scan_origin_grid.x) ** 2 + (y - scan_origin_grid.y) ** 2)
		if dist > max_distance:
			alpha = default_alpha
		else:
			var wave_speed = (0.2 + (1 - dist / max_distance) * 0.8) * initial_wave_speed
			var current_time = Time.get_ticks_msec() / 1000.0
			var elapsed = current_time - scan_start_time
			var arrive_time = dist / wave_speed
			var depart_time = arrive_time + display_duration
			if elapsed >= arrive_time and elapsed <= depart_time:
				var t = (elapsed - arrive_time) / display_duration
				alpha = (1-default_alpha)*(1.0 - t**2)+default_alpha
			else:
				alpha = default_alpha
	else:
		alpha = default_alpha
	
	# 你原有的调试代码（随机颜色当alpha>0.95）
	if alpha > 0.97:
		alpha = 0.2
		color.r = randf()
		color.b = randf()
		color.g = randf()
	
	color.a = alpha*0.8
	color_rects[y][x].color = color

func _process(delta: float):
	if is_scanning:
		var current_time = Time.get_ticks_msec() / 1000.0
		var elapsed = current_time - scan_start_time
		var max_dist = max(grid_width, grid_height)
		var max_arrive = max_dist / initial_wave_speed
		if elapsed > max_arrive + display_duration:
			is_scanning = false
			scan_end.emit()
			_update_all_colors()
		else:
			_update_all_colors()

# ===== 新增：流动步进函数（守恒版本）=====
func flow_step():
	var old = []
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			row.append(m_data[y][x])
		old.append(row)
	
	# 遍历每对相邻格子（右和下），双向转移差值的一半
	if decrease_disabled:
		for y in range(grid_height):
			for x in range(grid_width):
				var current = old[y][x]
				if(current<0.5):
					var transfer=(0.5-current)*flow_rate/2.0
					m_data[y][x]+=transfer
	else:
		for y in range(grid_height):
			for x in range(grid_width):
			# 向右
				if x + 1 < grid_width:
					var a = old[y][x]
					var b = old[y][x+1]
					var diff = a - b
					if abs(diff) > flow_threshold:
						var transfer = diff * flow_rate / 2.0
						m_data[y][x] -= transfer
						m_data[y][x+1] += transfer
			# 向下
				if y + 1 < grid_height:
					var a = old[y][x]
					var b = old[y+1][x]
					var diff = a - b
					if abs(diff) > flow_threshold:
						var transfer = diff * flow_rate / 2.0
						m_data[y][x] -= transfer
						m_data[y+1][x] += transfer
	
	# 钳位并刷新颜色
	for y in range(grid_height):
		for x in range(grid_width):
			if decrease_disabled:
				m_data[y][x] = clamp(m_data[y][x], 0.0, 0.5)
			else:
				m_data[y][x] = clamp(m_data[y][x], 0.0, 1.0)
	_update_all_colors()

# ===== 新增：定时器回调 =====
func _on_flow_timer_timeout():
	flow_step()

# ===== 以下是你原有的函数（未改动）=====
func set_player_grid(grid_pos: Vector2i):
	player_grid = grid_pos

func start_scan()->bool:
	if is_scanning:
		return false
	is_scanning = true
	scan_start_time = Time.get_ticks_msec() / 1000.0
	scan_origin_grid = player_grid
	_update_all_colors()
	return true

func set_m(x: int, y: int, new_value: float):
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return
	m_data[y][x] = clamp(new_value, 0.0, 1.0)
	_update_single_color(x, y)

func get_m(x: int, y: int) -> float:
	return m_data[y][x]

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_pos = to_local(world_pos)
	var x = floor((local_pos.x - start_position.x) / cell_size.x)
	var y = floor((local_pos.y - start_position.y) / cell_size.y)
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return Vector2i(-1, -1)
	return Vector2i(x, y)

func reset_all_m(value: float=0.5):
	for y in range(grid_height):
		for x in range(grid_width):
			m_data[y][x] =value
	_update_all_colors()

func flash_concentration(duration: float = 2.4):
	# 将所有格子的 alpha 立刻设为 1（完全显示浓度颜色）
	for y in range(grid_height):
		for x in range(grid_width):
			var rect = color_rects[y][x]
			rect.color.a = 1.0
	
	# 创建一个 Tween，将所有格子 alpha 渐变回默认值
	var tween = create_tween()
	tween.set_parallel(true)   # 所有动画同时进行
	for y in range(grid_height):
		for x in range(grid_width):
			var rect = color_rects[y][x]
			tween.tween_property(rect, "color:a", default_alpha, duration)
