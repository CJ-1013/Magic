extends Node2D

@export var tilemap: TileMapLayer
@export var cell_size: Vector2 = Vector2(50, 50)
# 墙壁图块的 source_id，你在 TileSet 面板里查看后填在这里
@export var m_source_ids: Array[int] = [1, 2]   # 假设1是普通墙壁，根据实际修改

# 流动参数
@export var flow_rate: float = 0.2
@export var flow_threshold: float = 0.01
@export var auto_flow_interval: float = 0.1

# 扫描波参数
@export var initial_wave_speed: float = 15.0
@export var display_duration: float = 0.4
@export var max_distance: int = 10

var scan_origin_grid: Vector2i = Vector2i(-1, -1)
var is_scanning: bool = false
var scan_start_time: float = 0.0
var player_grid: Vector2i = Vector2i(-1, -1)

var color_rects: Dictionary = {}   # cell -> ColorRect

func _ready():
	# 自动流动定时器
	if auto_flow_interval > 0:
		var flow_timer = Timer.new()
		flow_timer.wait_time = auto_flow_interval
		flow_timer.autostart = true
		flow_timer.timeout.connect(_on_flow_timer_timeout)
		add_child(flow_timer)
	
	_generate_color_rects()
	_update_all_colors()


func _generate_color_rects():
	# 清除旧的
	for rect in color_rects.values():
		rect.queue_free()
	color_rects.clear()
	
	# 只为有效图块（非墙壁）创建 ColorRect
	for cell in tilemap.get_used_cells():
		var source_id = tilemap.get_cell_source_id(cell)
		if not (source_id in m_source_ids):
			continue
		var rect = ColorRect.new()
		rect.size = cell_size
		rect.position = tilemap.map_to_local(cell) - cell_size / 2.0
		rect.color = Color.WHITE
		add_child(rect)
		color_rects[cell] = rect


func _is_valid_cell(cell: Vector2i) -> bool:
	return color_rects.has(cell)   # 只有我们创建了 ColorRect 的格子才参与 M 系统


func world_to_grid(world_pos: Vector2) -> Vector2i:
	if not tilemap:
		return Vector2i(-1, -1)
	var local_pos = to_local(world_pos) if is_inside_tree() else world_pos
	var map_coord = tilemap.local_to_map(local_pos)
	return map_coord

func get_m(x: int, y: int) -> float:
	var cell = Vector2i(x, y)
	var data = tilemap.get_cell_tile_data(cell)
	if data and _is_valid_cell(cell):
		return data.get_custom_data("m_concentration")
	return 0.5


func flow_step():
	var valid_cells = color_rects.keys()
	if valid_cells.is_empty():
		return
	
	# 1. 复制旧值（只读）
	var old_data = {}
	for cell in valid_cells:
		old_data[cell] = get_m(cell.x, cell.y)
	
	# 2. 累积变化量
	var delta = {}
	for cell in valid_cells:
		if not delta.has(cell):
			delta[cell] = 0.0
		
		var a = old_data[cell]
		# 右侧邻居
		var right = cell + Vector2i(1, 0)
		if old_data.has(right):
			var b = old_data[right]
			var diff = a - b
			if abs(diff) > flow_threshold:
				var transfer = diff * flow_rate / 2.0
				delta[cell] -= transfer
				if not delta.has(right):
					delta[right] = 0.0
				delta[right] += transfer
		# 下侧邻居
		var down = cell + Vector2i(0, 1)
		if old_data.has(down):
			var b = old_data[down]
			var diff = a - b
			if abs(diff) > flow_threshold:
				var transfer = diff * flow_rate / 2.0
				delta[cell] -= transfer
				if not delta.has(down):
					delta[down] = 0.0
				delta[down] += transfer
	
	# 3. 应用变化量并钳位
	for cell in valid_cells:
		var new_val = clamp(old_data[cell] + delta.get(cell, 0.0), 0.0, 1.0)
		_set_m_internal(cell, new_val)
	
	_update_all_colors()

# 内部修改（不调用全局刷新）
func _set_m_internal(cell: Vector2i, new_value: float):
	if not _is_valid_cell(cell):
		return
	var tile_id = tilemap.get_cell_source_id(cell)
	var atlas = tilemap.get_cell_atlas_coords(cell)
	var alt = tilemap.get_cell_alternative_tile(cell)
	tilemap.set_cell(cell, tile_id, atlas, alt)
	var data = tilemap.get_cell_tile_data(cell)
	if data:
		data.set_custom_data("m_concentration", clamp(new_value, 0.0, 1.0))
	_update_single_color(cell)

# 外部接口（保留原有名字，这里可以直接调用 _set_m_internal）
func set_m(x: int, y: int, new_value: float):
	_set_m_internal(Vector2i(x, y), new_value)


func _on_flow_timer_timeout():
	flow_step()


# ===== 扫描波相关 =====
func start_scan():
	if is_scanning:
		return
	is_scanning = true
	scan_start_time = Time.get_ticks_msec() / 1000.0
	scan_origin_grid = player_grid
	_update_all_colors()

func _process(delta):
	if is_scanning:
		var current_time = Time.get_ticks_msec() / 1000.0
		var elapsed = current_time - scan_start_time
		var max_arrive = max_distance / initial_wave_speed
		if elapsed > max_arrive + display_duration:
			is_scanning = false
		_update_all_colors()

func set_player_grid(grid_pos: Vector2i):
	player_grid = grid_pos


# ===== 可视化 =====
func _update_all_colors():
	for cell in color_rects.keys():
		_update_single_color(cell)

func _update_single_color(cell: Vector2i):
	if not color_rects.has(cell):
		return
	var m = get_m(cell.x, cell.y)
	var color = Color(1.0-m, 0, 1.0, 1.0)   # M高红低绿
	
	# 扫描波 alpha
	var alpha = 0.97
	if is_scanning and scan_origin_grid != Vector2i(-1, -1):
		var dist = cell.distance_to(scan_origin_grid)
		if dist <= max_distance:
			var wave_speed = (0.2 + (1 - dist / max_distance) * 0.8) * initial_wave_speed
			var current_time = Time.get_ticks_msec() / 1000.0
			var elapsed = current_time - scan_start_time
			var arrive_time = dist / wave_speed
			var depart_time = arrive_time + display_duration
			if elapsed >= arrive_time and elapsed <= depart_time:
				var t = (elapsed - arrive_time) / display_duration
				alpha = 1.0 - t**2
	if alpha > 0.97:
		alpha = 0.2
		color = Color(randf(), randf(), randf(), 1.0)
	
	color.a = alpha
	color_rects[cell].color = color
