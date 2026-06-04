extends Node

# 每个房间是否已扫荡
var room_cleared: Dictionary = {}

# 房间ID -> 场景路径
var room_paths: Dictionary = {}

# 门的连接系统：connection_id -> [{room_id, position, rotation}]
# 同一个 connection_id 的门互相连通（最多2个，一一对应）
var door_connections: Dictionary = {}

func register_room(room_id: String, scene_path: String):
	room_paths[room_id] = scene_path
	print("注册房间: ", room_id, " -> ", scene_path)

func register_door(room_id: String, connection_id: String, position: Vector2, rotation: float = 0.0):
	if connection_id == "":
		return
	if not door_connections.has(connection_id):
		door_connections[connection_id] = []
	# 防止重复注册（同一房间的门更新位置和旋转）
	for entry in door_connections[connection_id]:
		if entry.room_id == room_id:
			entry.position = position
			entry.rotation = rotation
			return
	door_connections[connection_id].append({"room_id": room_id, "position": position, "rotation": rotation})
	print("注册门: ", connection_id, " 房间=", room_id, " pos=", position, " rot=", rotation)

# 获取与当前房间通过 connection_id 相连的目标门信息
func get_connected_door(connection_id: String, from_room: String):
	var doors = door_connections.get(connection_id, [])
	for door in doors:
		if door.room_id != from_room:
			return door
	return null
