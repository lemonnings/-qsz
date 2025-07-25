# WarnCircleUtil - 圆形AOE预警工具

## 功能描述

`WarnCircleUtil` 是一个用于创建boss技能圆形/椭圆形范围AOE攻击预警的工具类。它提供了完整的预警视觉效果和伤害检测功能。

## 主要特性

### 视觉效果
- **渐变生成**: 预警时间前1/4，红圈从中心向外扩散至目标大小
- **稳定显示**: 中间时间保持稳定的红色透明圈（透明度0.35）
- **加速闪烁**: 最后1/4时间开始闪烁，频率逐渐加快
- **渐变消失**: 最后0.1秒红圈渐变消失

### 形状支持
- **圆形**: 长宽比设为1.0
- **椭圆形**: 通过调整长宽比创建椭圆形AOE

### 释放模式
- **直接伤害模式**: 预警结束后立即检测并造成伤害
- **持续区域模式**: 预警结束后生成可交互的持续区域效果

### 伤害系统
- 预警结束后自动检测玩家是否在范围内
- 对范围内的玩家造成指定伤害
- 支持伤害回调和信号
- 持续区域支持进入/离开检测

## 使用方法

### 基本用法

```gdscript
# 创建预警圆形
var warning_circle = WarnCircleUtil.new()
add_child(warning_circle)

# 连接信号
warning_circle.warning_finished.connect(_on_warning_finished)
warning_circle.damage_dealt.connect(_on_damage_dealt)

# 开始预警
# 获取动画播放器
var explosion_anim = get_node("ExplosionAnimationPlayer")

warning_circle.start_warning(
    Vector2(400, 300),  # 生成位置
    1.0,                # 长宽比 (1.0 = 圆形)
    150.0,              # 半径
    3.0,                # 预警时间(秒)
    75.0,               # 伤害值
    explosion_anim      # 动画播放器
)
```

## 使用示例

### 模式1：直接伤害判定（原有模式）

```gdscript
# 在boss脚本中
var WarnCircleUtil = preload("res://util/warn_circle_util.gd")

func boss_skill_explosion():
    # 创建预警实例
    var warning_circle = WarnCircleUtil.new()
    add_child(warning_circle)
    
    # 连接信号
    warning_circle.warning_finished.connect(_on_warning_finished)
    warning_circle.damage_dealt.connect(_on_damage_dealt)
    
    # 开始预警 - 直接伤害模式
    var explosion_anim = get_node("ExplosionAnimationPlayer")
    warning_circle.start_warning(
        Vector2(400, 300),  # 中心位置
        1.0,                # 圆形（长宽比1:1）
        150.0,              # 半径150像素
        3.0,                # 预警时间3秒
        100.0,              # 伤害100点
        explosion_anim,     # 爆炸动画
        WarnCircleUtil.ReleaseMode.INSTANT_DAMAGE  # 直接伤害模式
    )

func _on_warning_finished():
    print("AOE预警结束")

func _on_damage_dealt(damage_amount: float):
    print("对玩家造成伤害: ", damage_amount)
```

### 模式2：持续区域效果

```gdscript
func boss_skill_fire_trap():
    # 创建预警实例
    var warning_circle = WarnCircleUtil.new()
    add_child(warning_circle)
    
    # 连接信号
    warning_circle.warning_finished.connect(_on_fire_trap_warning_finished)
    warning_circle.area_entered.connect(_on_player_entered_fire)
    warning_circle.area_exited.connect(_on_player_exited_fire)
    warning_circle.area_effect_triggered.connect(_on_area_effect_triggered)
    
    # 加载火焰区域精灵场景
    var fire_sprite_scene = preload("res://effects/fire_area_sprite.tscn")
    
    # 开始预警 - 持续区域模式
    var fire_anim = get_node("FireAnimationPlayer")
    warning_circle.start_warning(
        Vector2(400, 300),  # 中心位置
        1.0,                # 圆形
        120.0,              # 半径120像素
        2.5,                # 预警时间2.5秒
        0.0,                # 不造成直接伤害
        fire_anim,          # 火焰动画
        WarnCircleUtil.ReleaseMode.PERSISTENT_AREA,  # 持续区域模式
        fire_sprite_scene,  # 区域精灵场景
        8.0,                # 持续8秒
        "fire_damage"       # 火焰伤害效果类型
    )

func _on_fire_trap_warning_finished():
    print("火焰陷阱预警结束，火焰区域已生成")

func _on_player_entered_fire(player: Node2D):
    print("玩家进入火焰区域！")

func _on_player_exited_fire(player: Node2D):
    print("玩家离开火焰区域")

func _on_area_effect_triggered(player: Node2D, effect_type: String):
    match effect_type:
        "fire_damage":
            if player.has_method("take_damage"):
                player.take_damage(15.0)  # 火焰伤害
            if player.has_method("apply_burn_effect"):
                player.apply_burn_effect(2.0)  # 燃烧效果
        "healing_effect":
            if player.has_method("heal"):
                player.heal(20.0)  # 治疗效果
        "slow_effect":
            if player.has_method("apply_slow"):
                player.apply_slow(0.5, 3.0)  # 减速效果
```

### 椭圆形AOE

```gdscript
# 创建椭圆形预警 (宽度是高度的2倍)
var fire_wave_anim = get_node("FireWaveAnimationPlayer")
warning_circle.start_warning(
    Vector2(500, 400),
    2.0,                # 长宽比 2:1
    200.0,
    2.5,
    100.0,
    fire_wave_anim      # 动画播放器
)
```

### 多重AOE

```gdscript
# 同时释放多个小范围AOE
var positions = [Vector2(300, 200), Vector2(500, 200), Vector2(400, 350)]

for pos in positions:
    var warning = WarnCircleUtil.new()
    add_child(warning)
    var small_explosion_anim = get_node("SmallExplosionAnimationPlayer")
    warning.start_warning(pos, 1.0, 80.0, 1.5, 50.0, small_explosion_anim)
```

## API 参考

### 方法

#### `start_warning(pos, aspect_ratio, radius, warning_time, damage, animation_player, release_mode, area_sprite_scene, area_duration, effect_type)`
开始AOE预警

**参数:**
- `pos: Vector2` - 生成位置
- `aspect_ratio: float` - 长宽比 (1.0=圆形, >1.0=椭圆形)
- `radius: float` - 半径大小
- `warning_time: float` - 预警持续时间(秒)
- `damage: float` - 造成的伤害值（直接伤害模式使用）
- `animation_player: AnimationPlayer` - 预警结束后播放的动画播放器（可选）
- `release_mode: ReleaseMode` - 释放模式（INSTANT_DAMAGE 或 PERSISTENT_AREA）
- `area_sprite_scene: PackedScene` - 持续区域显示的精灵场景（仅持续区域模式）
- `area_duration: float` - 持续区域持续时间，-1表示永久（仅持续区域模式）
- `effect_type: String` - 区域效果类型，如"fire_damage"、"healing_effect"、"slow_effect"等（仅持续区域模式）

#### `cleanup()`
清理资源，释放内存

### 信号

#### `warning_finished`
预警结束时发出

#### `damage_dealt(damage_amount)`
对玩家造成伤害时发出（仅直接伤害模式）
- `damage_amount: float` - 实际造成的伤害值

#### `area_entered(player_node)`
玩家进入持续区域时发出（仅持续区域模式）
- `player_node: Node2D` - 进入区域的玩家节点

#### `area_exited(player_node)`
玩家离开持续区域时发出（仅持续区域模式）
- `player_node: Node2D` - 离开区域的玩家节点

#### `area_effect_triggered(player_node, effect_type)`
玩家接触持续区域时触发特定效果（仅持续区域模式）
- `player_node: Node2D` - 触发效果的玩家节点
- `effect_type: String` - 触发的效果类型

### 属性

- `aspect_ratio: float` - 当前长宽比
- `radius: float` - 当前半径
- `warning_time: float` - 当前预警时间
- `damage: float` - 当前伤害值
- `animation_player: AnimationPlayer` - 当前动画播放器

## 实现细节

### 时间轴

1. **0% - 25%**: 从中心扩散到目标大小
2. **25% - 75%**: 稳定显示红色圈
3. **75% - 90%**: 开始闪烁，频率逐渐加快
4. **90% - 100%**: 渐变消失

### 伤害检测

- **圆形**: 直接计算玩家与中心点的距离
- **椭圆形**: 将坐标转换到标准圆形坐标系进行计算

### 依赖文件

- `circle_drawer.gd` - 负责绘制圆形/椭圆形形状
- 需要场景中存在名为"player"的组

## 注意事项

1. 确保玩家节点在"player"组中
2. 玩家节点需要有`take_damage(damage)`方法
3. 使用完毕后调用`cleanup()`释放资源
4. 需要提前准备好AnimationPlayer节点用于播放预警结束后的动画

## 应用场景

### 直接伤害模式适用场景
- **爆炸攻击**：预警后立即造成大量伤害
- **陨石攻击**：从天而降的单次打击
- **雷击**：瞬间电击伤害
- **冲击波**：范围性冲击伤害
- **法术爆发**：魔法师的范围法术攻击

### 持续区域模式适用场景
- **火焰陷阱**：持续造成火焰伤害（effect_type: "fire_damage"）
- **毒雾区域**：持续中毒效果（effect_type: "poison_damage"）
- **减速区域**：降低玩家移动速度（effect_type: "slow_effect"）
- **治疗区域**：为玩家提供持续治疗（effect_type: "healing_effect"）
- **增益区域**：提供攻击力或防御力加成（effect_type: "buff_effect"）
- **传送门**：特殊区域触发传送效果（effect_type: "teleport"）
- **陷阱机关**：触发各种机关效果（effect_type: "trap_trigger"）
- **收集区域**：自动收集道具或资源（effect_type: "auto_collect"）
- **加速区域**：提升玩家移动速度（effect_type: "speed_boost"）
- **护盾区域**：为玩家提供临时护盾（effect_type: "shield_effect"）

## 扩展注意事项

### 持续区域模式特别注意
1. **精灵场景要求**：持续区域模式需要提供有效的PackedScene，建议包含AnimatedSprite2D节点
2. **信号连接**：根据使用的模式连接相应的信号，避免连接不必要的信号
3. **效果类型定义**：effect_type参数用于标识具体的区域效果，建议使用统一的命名规范（如"fire_damage"、"healing_effect"等）
4. **效果处理逻辑**：需要在area_effect_triggered信号的回调函数中实现具体的效果逻辑
5. **性能考虑**：永久持续区域会一直存在，注意及时清理不需要的区域
6. **碰撞检测**：持续区域使用Area2D进行碰撞检测，确保玩家节点有正确的碰撞体
7. **区域叠加**：多个持续区域可能会叠加效果，需要在游戏逻辑中处理
8. **内存管理**：使用cleanup()方法或destroy_persistent_area()方法及时清理资源

### 通用注意事项
1. 确保玩家节点在"player"组中
2. 玩家节点需要有`take_damage(damage)`方法（直接伤害模式）
3. 使用完毕后调用`cleanup()`释放资源
4. 需要提前准备好AnimationPlayer节点用于播放预警结束后的动画
5. 持续区域的精灵场景应该包含合适的动画效果
6. 考虑区域效果的平衡性，避免过于强力的持续效果

## 示例场景

参考 `warn_circle_example.gd` 和 `warn_circle_example_updated.gd` 文件查看完整的使用示例。