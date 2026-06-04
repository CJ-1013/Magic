# Magic — M 浓度博弈射击游戏

基于 Godot 4.6 引擎开发的 2D 俯视角射击游戏。

## 核心机制

网格化的 **M 浓度**（Magic Concentration）数值场贯穿整个地图。你的射击会消耗环境的 M 浓度来换取更高的伤害，而 M 浓度的分布又反过来影响你的机动性和生存——在伤害、速度和安全之间持续做出选择，是游戏的核心博弈。

## 操作

| 按键 | 功能 |
|------|------|
| WASD | 移动 |
| 鼠标 | 瞄准 |
| 左键 | 射击（消耗 M） |
| 右键 | 投掷手雷 |
| 空格 | 冲刺（消耗 M） |
| C | M 浓度扫描 |
| ESC | 暂停菜单 |

## 项目结构

```
magic/
├── main.gd / main.tscn       # 主控制器与 UI
├── player.gd / player.tscn   # 玩家
├── simple_enemy.gd / .tscn   # 普通敌人（AI 状态机基类）
├── sharp_enemy.gd / .tscn    # 精英敌人（爆发射击+激怒）
├── boss_enemy.gd / .tscn     # Boss（环形射击+冲锋+召唤）
├── bullet.gd / .tscn         # 子弹
├── grenade.gd / .tscn        # 手雷
├── m_grid_visuals.gd         # M 浓度网格系统
├── door.gd / .tscn           # 门传送系统
├── room_data.gd              # 全局数据层（Autoload）
├── m_crystal.gd / .tscn      # M 晶体产出器
├── rooms/                    # 6 个房间场景 + room.gd
├── Player_anim/              # 玩家动画
├── SimpleEnemy_anim/         # 普通敌人动画
├── SharpEnemy_anim/          # 精英敌人动画
├── Boss_anim/                # Boss 动画
├── M_Crystal_anim/           # M 晶体动画
├── GrenadeExplore_anim/      # 手雷爆炸动画
├── M/                        # M 相关资源
└── resource/                 # UI、音效等资源
```

## 运行

1. 安装 [Godot 4.6](https://godotengine.org/)
2. 用 Godot 打开 `project.godot`
3. 按 F5 运行

## 许可证

MIT License
