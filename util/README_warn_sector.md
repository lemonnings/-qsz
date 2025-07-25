# WarnSectorUtil - 扇形AOE预警工具

## 概述

`WarnSectorUtil` 是一个用于创建Boss技能扇形范围预警效果的工具类。它基于圆形预警工具的设计，但专门用于处理扇形AOE攻击，如龙息、锥形法术、扫击攻击等。

## 功能特性

- **灵活的扇形定义**：通过起始位置、目标点和扇形角度定义扇形范围
- **精确的碰撞检测**：准确判断玩家是否在扇形AOE范围内
- **丰富的视觉效果**：包含扩散、稳定、闪烁和渐变消失四个阶段
- **信号系统**：提供预警结束和伤害造成的信号回调
- **动画集成**：支持在预警结束后播放自定义动画
- **易于使用**：简单的API接口，易于集成到现有Boss系统中

## 文件结构

```
util/
├── warn_sector_util.gd      # 主要功能类
├── sector_drawer.gd          # 扇形绘制辅助类
├── warn_sector_example.gd    # 使用示例
└── README_warn_sector.md     # 本文档
```

## 基本使用方法

### 1. 创建扇形预警

```gdscript
# 在boss脚本中
var WarnSectorUtil = preload("res://util/warn_sector_util.gd")

func boss_dragon_breath_attack():
    # 创建预警实例
    var warning_sector = WarnSectorUtil.new()
    add_child(warning_sector)
    
    # 连接信号
    warning_sector.warning_finished.connect(_on_warning_finished)
    warning_sector.damage_dealt.connect(_on_damage_dealt)
    
    # 开始预警
    var boss_pos = global_position
    var player_pos = get_tree().get_first_node_in_group("player").global_position
    var breath_anim = get_node("BreathAnimationPlayer")
    
    warning_sector.start_warning(
        boss_pos,        # 起始位置（扇形顶点）
        player_pos,      # 目标点（决定扇形方向和半径）
        90.0,            # 扇形角度（度）
        3.0,             # 预警时间（秒）
        120.0,           # 伤害值
        breath_anim      # 动画播放器（可选）
    )
```

### 2. 处理信号回调

```gdscript
func _on_warning_finished():
    print("扇形AOE预警结束")
    # 添加音效、震屏等效果

func _on_damage_dealt(damage_amount: float):
    print("对玩家造成伤害: ", damage_amount)
    # 显示伤害数字、播放受击音效等
```

## API参考

### WarnSectorUtil 类

#### 信号

- `warning_finished` - 预警结束时发出
- `damage_dealt(damage: float)` - 对玩家造成伤害时发出

#### 主要方法

##### start_warning(pos, target_point, sector_angle, warning_time, damage, animation_player)

开始扇形AOE预警。

**参数：**
- `pos: Vector2` - 扇形的起始位置（顶点位置）
- `target_point: Vector2` - 目标点，决定扇形的中心方向和半径
- `sector_angle: float` - 扇形角度（度）
- `warning_time: float` - 预警持续时间（秒）
- `damage: float` - 伤害值
- `animation_player: AnimationPlayer` - 动画播放器（可选）

#### 内部方法

- `is_player_in_range() -> bool` - 检查玩家是否在扇形范围内
- `deal_damage_to_player()` - 对玩家造成伤害
- `update_warning_visual()` - 更新预警视觉效果
- `cleanup()` - 清理资源

### SectorDrawer 类

#### 主要方法

##### setup(radius, angle, direction)

设置扇形绘制参数。

**参数：**
- `radius: float` - 扇形半径
- `angle: float` - 扇形角度（弧度）
- `direction: float` - 扇形中心方向（弧度）

## 应用场景

### 1. 龙息攻击

```gdscript
# 大角度、中等距离的火焰喷射
warning_sector.start_warning(
    boss_position,
    player_position,
    120.0,    # 大角度扇形
    3.0,      # 较长预警时间
    150.0,    # 高伤害
    flame_breath_anim
)
```

### 2. 精确锥形攻击

```gdscript
# 小角度、长距离的精确打击
warning_sector.start_warning(
    caster_position,
    target_position,
    30.0,     # 窄角度
    2.0,      # 中等预警时间
    200.0,    # 高伤害
    precision_strike_anim
)
```

### 3. 大范围扫击

```gdscript
# 超大角度的范围攻击
warning_sector.start_warning(
    boss_position,
    sweep_direction,
    150.0,    # 超大角度
    4.0,      # 长预警时间
    100.0,    # 中等伤害
    sweep_attack_anim
)
```

### 4. 多方向爆发

```gdscript
# 创建多个扇形形成全方位攻击
var directions = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
for direction in directions:
    var warning = WarnSectorUtil.new()
    add_child(warning)
    var target = boss_pos + direction * 200
    warning.start_warning(boss_pos, target, 80.0, 2.5, 90.0)
```

## 预警动画阶段

扇形预警包含四个视觉阶段：

1. **扩散阶段（0-25%）**：扇形从中心点向外扩散，透明度0.35
2. **稳定阶段（25-75%）**：保持最大尺寸和稳定透明度
3. **闪烁阶段（75-90%）**：红色加速闪烁，提醒即将触发
4. **消失阶段（90-100%）**：渐变消失，然后触发伤害判定

## 碰撞检测原理

扇形碰撞检测包含两个条件：

1. **距离检测**：玩家到扇形顶点的距离 ≤ 扇形半径
2. **角度检测**：玩家相对于扇形顶点的角度在扇形角度范围内

```gdscript
# 伪代码示例
var player_distance = player_pos.distance_to(sector_center)
var player_angle = (player_pos - sector_center).angle()
var in_range = player_distance <= sector_radius and 
               angle_in_sector_range(player_angle, sector_start_angle, sector_end_angle)
```

## 性能优化建议

1. **合理设置分段数**：`SectorDrawer`的`segments`参数影响绘制质量和性能
2. **及时清理资源**：预警结束后自动调用`cleanup()`方法
3. **避免过多同时预警**：大量同时存在的扇形预警可能影响性能
4. **优化角度计算**：使用缓存避免重复的三角函数计算

## 注意事项

1. **玩家节点要求**：确保玩家节点在"player"组中，且有`take_damage`方法
2. **角度单位**：API中角度参数使用度（degree），内部计算使用弧度（radian）
3. **坐标系统**：使用Godot的标准2D坐标系统
4. **动画播放器**：动画播放器参数是可选的，可以传入`null`
5. **信号连接**：记得连接信号以处理预警结束和伤害事件

## 扩展建议

1. **多段扇形**：可以扩展支持多段不连续的扇形
2. **动态角度**：支持预警过程中动态改变扇形角度
3. **渐变效果**：添加从中心到边缘的颜色渐变效果
4. **粒子效果**：集成粒子系统增强视觉效果
5. **音效集成**：添加预警音效和触发音效

## 与其他AOE工具的配合

`WarnSectorUtil`可以与`WarnCircleUtil`和`WarnRectUtil`配合使用，创建复杂的组合攻击模式：

```gdscript
# 组合攻击示例：中心爆炸 + 四方向扇形
func combo_attack():
    # 中心圆形爆炸
    var center_warning = WarnCircleUtil.new()
    center_warning.start_warning(boss_pos, 100.0, 2.0, 80.0)
    
    # 四个方向的扇形攻击
    for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
        var sector_warning = WarnSectorUtil.new()
        var target = boss_pos + direction * 200
        sector_warning.start_warning(boss_pos, target, 60.0, 180.0, 3.0, 60.0)
```

通过合理使用这些AOE预警工具，可以创造出丰富多样的Boss战斗体验。