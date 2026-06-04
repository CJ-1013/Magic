extends Node2D

@export var room_id: String = ""
@export var cleared: bool = false
var enemy_count: int = 0
var tilemap: TileMapLayer
var cell_size: Vector2
var wall_source_ids: Array = []

func is_wall(world_pos: Vector2) -> bool:
	if not tilemap:
		return false
	var cell = tilemap.local_to_map(world_pos)
	var source_id = tilemap.get_cell_source_id(cell)
	return source_id in wall_source_ids

## 由 Main 在实例化后调用，确保 room_id 始终正确
func set_room_id(id: String):
	room_id = id

func _ready():
	# 优先使用导出的 room_id，其次从场景文件名推导
	if room_id == "":
		var path = scene_file_path
		if path != "":
			room_id = path.get_file().get_basename()
		else:
			push_warning("room.gd: 无法确定 room_id，请在场景中设置或调用 set_room_id()")

	print("[Room] 初始化房间: ", room_id, " scene_file_path=", scene_file_path)

	cleared = RoomData.room_cleared.get(room_id, false)
	tilemap = $Map
	if not tilemap:
		return

	# 注册房间路径
	RoomData.register_room(room_id, scene_file_path)

	# 自动注册所有子门（通过检查 connection_id 属性）
	_register_doors()

	if not cleared:
		_disable_doors()
		call_deferred("_spawn_enemies_after_delay")
	else:
		print("[Room] ", room_id, " 已清除，直接启用门")
		_balance_m_quickly()
		_enable_doors()

func _register_doors():
	for child in get_children():
		if child is Area2D and child.get("connection_id") != null:
			var cid = child.get("connection_id")
			if cid != "":
				RoomData.register_door(room_id, cid, child.global_position, child.rotation)

func _get_doors() -> Array[Node]:
	var doors: Array[Node] = []
	for child in get_children():
		if child is Area2D and child.get("connection_id") != null:
			doors.append(child)
	return doors

func _disable_doors():
	for child in _get_doors():
		child.monitoring = false

func _enable_doors():
	for child in _get_doors():
		child.monitoring = true

func _spawn_enemies_after_delay():
	await get_tree().create_timer(0.5).timeout
	var spawns = $EnemySpawns
	var spawned = 0
	if spawns:
		for point in spawns.get_children():
			if point is Marker2D:
				var main = get_parent()
				var e
				var pname = point.name.to_lower()
				if "boss" in pname:
					e = main.spawn_enemy_at(point.global_position, main.ENEMY_BOSS)
				elif "sharp" in pname or "elite" in pname:
					e = main.spawn_enemy_at(point.global_position, main.ENEMY_SHARP)
				else:
					e = main.spawn_enemy_at(point.global_position, main.ENEMY_SIMPLE)
				e.died.connect(_on_enemy_died)
				enemy_count += 1
				spawned += 1

	print("[Room] ", room_id, " 生成了 ", spawned, " 个敌人, enemy_count=", enemy_count)

	# 如果没有敌人，立即标记为已清除
	if spawned == 0 and enemy_count == 0:
		print("[Room] ", room_id, " 没有敌人，自动清除")
		call_deferred("_set_cleared")

func _on_enemy_died():
	enemy_count -= 1
	if enemy_count <= 0:
		_set_cleared()

func _set_cleared():
	for child in get_children():
		if child.is_in_group("Crystal"):
			child.disabled = true

	cleared = true
	RoomData.room_cleared[room_id] = true
	_enable_doors()
	_balance_m_quickly()

	var grid = $M_Grid_Visuals
	if grid and grid.has_method("flash_concentration"):
		grid.flash_concentration(2.4)

func _balance_m_quickly():
	var grid = $M_Grid_Visuals
	if not grid:
		return

	grid.reset_all_m(0.5)

	# 仅在首次均衡时保存原始流速并加速
	if not grid.get("_room_balanced"):
		grid.set_meta("_original_flow_rate", grid.flow_rate)
		grid.flow_rate *= 3.0
		grid.decrease_disabled = true
		grid.set_meta("_room_balanced", true)
