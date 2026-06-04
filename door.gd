extends Area2D

## 门的连接ID：两个房间中相同 connection_id 的门互相连通
@export var connection_id: String = ""
## 目标房间ID
@export var target_room_id: String = ""

func _ready():
	if connection_id == "" or target_room_id == "":
		print("[Door] 警告：门未配置 connection_id 或 target_room_id, 位置=", global_position)
	else:
		print("[Door] 门已就绪: conn=", connection_id, " target=", target_room_id, " pos=", global_position)
	# 确保物理检测正确
	collision_mask = 1  # 检测 layer 1（玩家所在层）
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if not body.is_in_group("player"):
		return

	print("[Door] 玩家进入门区域! connection_id=", connection_id, " target=", target_room_id)

	if connection_id == "" or target_room_id == "":
		print("[Door] 错误：门未配置 connection_id 或 target_room_id")
		return

	var current_room_id = get_parent().get("room_id")
	if current_room_id == null or current_room_id == "":
		print("[Door] 错误：无法获取当前房间ID, parent=", get_parent().name)
		return

	print("[Door] 当前房间=", current_room_id)

	# 从 RoomData 查找目标门的位置
	var target_door = RoomData.get_connected_door(connection_id, current_room_id)
	if not target_door:
		print("[Door] 错误：未找到匹配的门 connection_id=", connection_id, " from=", current_room_id)
		print("[Door] 已注册的门连接: ", RoomData.door_connections)
		return

	var target_path = RoomData.room_paths.get(target_room_id, "")
	if target_path == "":
		print("[Door] 错误：目标房间未注册 ", target_room_id)
		print("[Door] 已注册的房间: ", RoomData.room_paths)
		return
	print("[Door] 传送! → ", target_room_id, " (", target_path, ") spawn=", target_door.position)

	# 传送位置：目标门的位置，计算偏移方向
	var offset = _calculate_spawn_offset(target_door)

	var main = get_node_or_null("/root/Main")
	if main:
		main.request_switch_room(target_path, target_door.position + offset)

## 根据目标门的旋转方向计算偏移，确保玩家传送到门内侧（房间内部）
## 门的默认箭头指向 Vector2.UP（即 (0, -1)），偏移应向箭头反方向（房间内）
func _calculate_spawn_offset(target_door) -> Vector2:
	var door_rotation = target_door.get("rotation", 0.0)
	# 箭头方向：默认指向上方 (0, -1)，经旋转后
	# 偏移方向：箭头反方向（进入房间），距离 48 像素
	var spawn_dir = Vector2.DOWN.rotated(door_rotation)
	return spawn_dir * 48
