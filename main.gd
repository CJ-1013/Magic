extends Node

## Magic - 主控制器
## 管理：标题界面 → 游戏 → 游戏结束 的完整流程

signal game_over

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera

# UI 层
@onready var ui_title: CanvasLayer = $TitleScreen
@onready var ui_gameover: CanvasLayer = $GameOverScreen
@onready var ui_hud: CanvasLayer = $UILayer
@onready var ui_hp_bar: ProgressBar = $UILayer/HPBar
@onready var ui_grenade_bar: TextureProgressBar = $UILayer/GrenadePanel/GrenadeUI
@onready var ui_grenade_count: Label = $UILayer/GrenadePanel/GrenadeCount

var simple_enemy_scene = preload("res://simple_enemy.tscn")
var sharp_enemy_scene = preload("res://sharp_enemy.tscn")
var boss_enemy_scene = preload("res://boss_enemy.tscn")
var current_room: Node2D = null
var game_state: String = "title"  # title, playing, paused, gameover, victory

# 暂停 / 胜利菜单
var pause_panel: CanvasLayer = null
var victory_panel: CanvasLayer = null
var mouse_locked: bool = false

func _ready() -> void:
	# 预注册所有房间
	var room_ids = ["room_1", "room_2", "room_3", "room_4", "room_5", "room_boss"]
	for id in room_ids:
		_preload_room(id)

	# 初始化 UI
	ui_hp_bar.max_value = player.player_hp
	ui_grenade_bar.max_value = 100

	# 创建暂停菜单
	_create_pause_menu()
	# 创建胜利画面
	_create_victory_screen()

	# 显示标题界面
	_show_title()

# === 标题界面 ===
func _show_title():
	game_state = "title"
	ui_title.visible = true
	ui_gameover.visible = false
	ui_hud.visible = false
	player.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_start_button_pressed():
	_start_new_game()

func _on_title_quit_button_pressed():
	get_tree().quit()

# === 开始新游戏 ===
func _start_new_game():
	game_state = "playing"
	ui_title.visible = false
	ui_gameover.visible = false
	ui_hud.visible = true
	player.show()
	_apply_mouse_mode()
	new_game()

func new_game():
	# 重置房间清除状态（Autoload 不会随场景重载而重置）
	RoomData.room_cleared.clear()
	# 注意：不要清除 door_connections！门的注册在 _ready() 预加载时完成，
	# 清除后只有当前房间的门会被重新注册，导致门传送失败。
	switch_room(RoomData.room_paths.get("room_1", "res://rooms/room_1.tscn"), $StartPosition.position)

# === 房间切换 ===
func request_switch_room(room_path: String, spawn_pos: Vector2):
	call_deferred("switch_room", room_path, spawn_pos)

func switch_room(room_path: String, player_spawn_pos: Vector2):
	if current_room:
		current_room.queue_free()
		_clear_projectiles()

	var room_resource = load(room_path)
	if not room_resource:
		push_error("无法加载房间：", room_path)
		return

	current_room = room_resource.instantiate()
	# 确保房间有正确的 room_id（从路径推导）
	var derived_id = room_path.get_file().get_basename()
	if current_room.get("room_id") == null or current_room.get("room_id") == "":
		current_room.set("room_id", derived_id)
	add_child(current_room)

	if player:
		player.position = player_spawn_pos
		if player.has_method("refresh_m_grid_visuals"):
			player.refresh_m_grid_visuals()

# === 输入处理（在 _input 中检测暂停键，因为暂停时 _process 不运行）===
func _input(event):
	if event.is_action_pressed("pause"):
		if game_state == "playing":
			_pause_game()
		elif game_state == "paused":
			_resume_game()
		# title / gameover 状态不响应暂停

# === 每帧更新 ===
func _process(_delta):
	if game_state != "playing":
		return

	if not player:
		return

	if player.player_hp <= 0:
		_trigger_game_over()
		return

	# 血条
	ui_hp_bar.value = player.player_hp

	# 手雷进度条
	if player.grenade_count < player.max_grenades:
		ui_grenade_bar.value = 100 * player.grenade_regen_timer / player.grenade_regen_time
	else:
		ui_grenade_bar.value = 100

	# 手雷数量
	ui_grenade_count.text = str(player.grenade_count)

# === 暂停系统 ===
func _create_pause_menu():
	pause_panel = CanvasLayer.new()
	pause_panel.name = "PauseScreen"
	pause_panel.layer = 10
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时 UI 仍然工作
	add_child(pause_panel)

	# 半透明背景（全屏）
	var bg = ColorRect.new()
	bg.name = "PauseBG"
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.05, 0.05, 0.1, 0.85)
	# 让背景也能接收点击，防止穿透到游戏
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.add_child(bg)

	# VBox 容器 — 锚点居中
	var vbox = VBoxContainer.new()
	vbox.name = "MenuVBox"
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -160
	vbox.offset_top = -180
	vbox.offset_right = 160
	vbox.offset_bottom = 180
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_panel.add_child(vbox)

	# 标题
	var title = Label.new()
	title.name = "PauseTitle"
	title.text = "— 暂停 —"
	title.self_modulate = Color(0.5, 0.8, 1, 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings = LabelSettings.new()
	title_settings.font_size = 64
	title_settings.outline_size = 8
	title_settings.outline_color = Color(0, 0, 0, 1)
	title.label_settings = title_settings
	vbox.add_child(title)

	# 间距
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	# 鼠标锁定切换按钮
	var mouse_btn = Button.new()
	mouse_btn.name = "MouseToggleBtn"
	mouse_btn.text = "锁定鼠标: 关"
	mouse_btn.custom_minimum_size = Vector2(280, 50)
	mouse_btn.pressed.connect(_on_toggle_mouse_lock)
	vbox.add_child(mouse_btn)

	# 继续按钮
	var resume_btn = Button.new()
	resume_btn.name = "ResumeBtn"
	resume_btn.text = "继续游戏"
	resume_btn.custom_minimum_size = Vector2(280, 50)
	resume_btn.pressed.connect(_resume_game)
	vbox.add_child(resume_btn)

	# 返回标题按钮
	var title_btn = Button.new()
	title_btn.name = "TitleBtn"
	title_btn.text = "返回标题"
	title_btn.custom_minimum_size = Vector2(280, 50)
	title_btn.pressed.connect(_return_to_title)
	vbox.add_child(title_btn)

	# 退出按钮
	var quit_btn = Button.new()
	quit_btn.name = "QuitBtn"
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(280, 50)
	quit_btn.pressed.connect(get_tree().quit)
	vbox.add_child(quit_btn)

func _pause_game():
	if game_state != "playing":
		return
	game_state = "paused"
	pause_panel.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_mouse_button_text()

func _resume_game():
	if game_state != "paused":
		return
	game_state = "playing"
	pause_panel.visible = false
	get_tree().paused = false
	_apply_mouse_mode()

func _return_to_title():
	# 先取消暂停再返回标题
	get_tree().paused = false
	pause_panel.visible = false
	# 清理当前房间
	if current_room:
		current_room.queue_free()
		current_room = null
	_clear_projectiles()
	_show_title()

func _on_toggle_mouse_lock():
	mouse_locked = not mouse_locked
	_apply_mouse_mode()
	_update_mouse_button_text()

func _apply_mouse_mode():
	if mouse_locked:
		Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _update_mouse_button_text():
	var btn = pause_panel.get_node_or_null("MenuVBox/MouseToggleBtn")
	if btn:
		btn.text = "锁定鼠标: 开" if mouse_locked else "锁定鼠标: 关"

# === 胜利画面 ===
func _create_victory_screen():
	victory_panel = CanvasLayer.new()
	victory_panel.name = "VictoryScreen"
	victory_panel.layer = 10
	victory_panel.visible = false
	victory_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(victory_panel)

	var bg = ColorRect.new()
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.color = Color(0.02, 0.08, 0.05, 0.9)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	victory_panel.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.5
	vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left = -200
	vbox.offset_top = -140
	vbox.offset_right = 200
	vbox.offset_bottom = 140
	vbox.add_theme_constant_override("separation", 16)
	vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	victory_panel.add_child(vbox)

	var title = Label.new()
	title.text = "— 胜 利 —"
	title.self_modulate = Color(0.4, 1.0, 0.5, 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_settings = LabelSettings.new()
	title_settings.font_size = 72
	title_settings.outline_size = 10
	title_settings.outline_color = Color(0, 0.3, 0.1, 1)
	title.label_settings = title_settings
	vbox.add_child(title)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	var sub = Label.new()
	sub.text = "你击败了 Boss，M 浓度恢复了平衡"
	sub.self_modulate = Color(0.7, 0.9, 0.8, 1)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_settings = LabelSettings.new()
	sub_settings.font_size = 24
	sub_settings.outline_size = 4
	sub_settings.outline_color = Color(0, 0, 0, 1)
	sub.label_settings = sub_settings
	vbox.add_child(sub)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	var restart_btn = Button.new()
	restart_btn.text = "再来一局"
	restart_btn.custom_minimum_size = Vector2(280, 50)
	restart_btn.pressed.connect(get_tree().reload_current_scene)
	vbox.add_child(restart_btn)

	var quit_btn = Button.new()
	quit_btn.text = "退出游戏"
	quit_btn.custom_minimum_size = Vector2(280, 50)
	quit_btn.pressed.connect(get_tree().quit)
	vbox.add_child(quit_btn)

func _trigger_victory():
	game_state = "victory"
	ui_hud.visible = false
	victory_panel.visible = true
	player.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# === 游戏结束 ===
func _trigger_game_over():
	game_state = "gameover"
	game_over.emit()
	ui_hud.visible = false
	ui_gameover.visible = true
	player.hide()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_restart_button_pressed():
	get_tree().reload_current_scene()

func _on_gameover_quit_button_pressed():
	get_tree().quit()

# === 预加载房间 ===
func _preload_room(room_id: String):
	var room_path = RoomData.room_paths.get(room_id, "res://rooms/" + room_id + ".tscn")
	if not ResourceLoader.exists(room_path):
		print("警告：房间文件不存在 - " + room_path)
		return
	var room_resource = load(room_path)
	if not room_resource:
		print("警告：无法加载房间 - " + room_path)
		return
	var room_instance = room_resource.instantiate()
	add_child(room_instance)
	room_instance.queue_free()

# === 工具方法 ===
const ENEMY_SIMPLE = 0
const ENEMY_SHARP = 1
const ENEMY_BOSS = 2

func spawn_enemy_at(pos: Vector2, type: int = ENEMY_SIMPLE):
	var scene = simple_enemy_scene
	match type:
		ENEMY_SHARP:
			scene = sharp_enemy_scene
		ENEMY_BOSS:
			scene = boss_enemy_scene
	var e = scene.instantiate()
	e.position = pos
	# Boss 死亡 → 胜利
	if type == ENEMY_BOSS and e.has_signal("boss_defeated"):
		e.boss_defeated.connect(_trigger_victory)
	add_child(e)
	return e

func spawn_boss_at(pos: Vector2):
	return spawn_enemy_at(pos, ENEMY_BOSS)

func _clear_projectiles():
	for node in get_tree().get_nodes_in_group("projectile"):
		node.queue_free()

func get_m_grid_visuals():
	if current_room:
		return current_room.get_node_or_null("M_Grid_Visuals")
	return null
