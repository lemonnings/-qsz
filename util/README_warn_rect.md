# WarnRectUtil - 矩形AOE预警工具

## 功能描述

`WarnRectUtil` 是一个用于创建boss技能矩形范围AOE攻击预警的工具类。它基于圆形预警工具的逻辑，专门用于创建线性、激光束、光束等矩形区域的预警效果。

## 主要特性

### 视觉效果
- **渐变生成**: 预警时间前1/4，红色矩形从中心向外扩散至目标大小
- **稳定显示**: 中间时间保持稳定的红色透明矩形（透明度0.35）
- **加速闪烁**: 最后1/4时间开始闪烁，频率逐渐加快
- **渐变消失**: 最后0.1秒红色矩形渐变消失

### 形状特点
- **线性区域**: 从起始点到目标点形成矩形区域
- **可调宽度**: 通过宽度参数控制矩形的厚度
- **任意角度**: 支持任意方向的矩形AOE
- **精确碰撞**: 准确的矩形范围伤害检测

### 伤害系统
- 预警结束后自动检测玩家是否在矩形范围内
- 对范围内的玩家造成指定伤害
- 支持伤害回调和信号

## 使用方法

### 基本用法

```gdscript
# 创建预警矩形
var warning_rect = WarnRectUtil.new()
add_child(warning_rect)

# 连接信号
warning_rect.warning_finished.connect(_on_warning_finished)
warning_rect.damage_dealt.connect(_on_damage_dealt)

# 获取动画播放器
var laser_anim = get_node("LaserAnimationPlayer")

# 开始预警
warning_rect.start_warning(
    Vector2(200, 300),  # 起始位置
    Vector2(600, 300),  # 目标点
    80.0,               # 宽度
    2.5,                # 预警时间(秒)
    90.0,               # 伤害值
    laser_anim          # 动画播放器
)
```

### 对角线激光

```gdscript
# 创建对角线激光攻击
var diagonal_anim = get_node("DiagonalLaserAnimationPlayer")
warning_rect.start_warning(
    Vector2(100, 100),  # 起始位置
    Vector2(700, 500),  # 目标点（对角线）
    60.0,               # 激光宽度
    3.0,                # 预警时间
    120.0,              # 伤害值
    diagonal_anim       # 动画播放器
)
```

### 指向玩家的光束

```gdscript
# 从boss位置指向玩家的光束攻击
var player = get_tree().get_first_node_in_group("player")
var boss_pos = global_position
var player_pos = player.global_position
var beam_anim = get_node("BeamAnimationPlayer")

warning_rect.start_warning(
    boss_pos,           # 起始位置（boss）
    player_pos,         # 目标点（玩家）
    100.0,              # 光束宽度
    2.0,                # 预警时间
    150.0,              # 伤害值
    beam_anim           # 动画播放器
)
```

### 多重激光阵列

```gdscript
# 创建十字形激光阵列
var laser_patterns = [
    {"start": Vector2(100, 300), "end": Vector2(700, 300)},  # 水平
    {"start": Vector2(400, 100), "end": Vector2(400, 500)},  # 垂直
    {"start": Vector2(200, 200), "end": Vector2(600, 400)},  # 对角线1
    {"start": Vector2(600, 200), "end": Vector2(200, 400)}   # 对角线2
]

for i in range(laser_patterns.size()):
    var pattern = laser_patterns[i]
    var warning = WarnRectUtil.new()
    add_child(warning)
    
    # 延迟启动，创造连续效果
    await get_tree().create_timer(i * 0.3).timeout
    
    var cross_laser_anim = get_node("CrossLaserAnimationPlayer")
    warning.start_warning(
        pattern["start"],
        pattern["end"],
        50.0,               # 激光宽度
        1.8,                # 预警时间
        80.0,               # 伤害值
        cross_laser_anim
    )
```

## API 参考

### 方法

#### `start_warning(pos, target_point, width, warning_time, damage, animation_player)`
开始矩形AOE预警

**参数:**
- `pos: Vector2` - 起始位置
- `target_point: Vector2` - 目标点位置
- `width: float` - 矩形宽度
- `warning_time: float` - 预警持续时间(秒)
- `damage: float` - 造成的伤害值
- `animation_player: AnimationPlayer` - 预警结束后播放的动画播放器

#### `cleanup()`
清理资源，释放内存

### 信号

#### `warning_finished`
预警结束时发出

#### `damage_dealt(damage_amount)`
对玩家造成伤害时发出
- `damage_amount: float` - 实际造成的伤害值

### 属性

- `target_point: Vector2` - 当前目标点
- `width: float` - 当前矩形宽度
- `warning_time: float` - 当前预警时间
- `damage: float` - 当前伤害值
- `animation_player: AnimationPlayer` - 当前动画播放器
- `rect_length: float` - 矩形长度（自动计算）
- `rect_angle: float` - 矩形角度（自动计算）

## 实现细节

### 时间轴

1. **0% - 25%**: 从中心扩散到目标大小
2. **25% - 75%**: 稳定显示红色矩形
3. **75% - 90%**: 开始闪烁，频率逐渐加快
4. **90% - 100%**: 渐变消失

### 坐标计算

- **矩形中心**: 起始点和目标点的中点
- **矩形长度**: 起始点到目标点的距离
- **矩形角度**: 从起始点指向目标点的角度
- **碰撞检测**: 将玩家坐标转换到矩形本地坐标系进行检测

### 伤害检测

矩形碰撞检测通过以下步骤实现：
1. 计算玩家相对于矩形中心的位置
2. 将坐标旋转到矩形的本地坐标系
3. 检查旋转后的坐标是否在矩形范围内

### 依赖文件

- `rect_drawer.gd` - 负责绘制矩形形状
- 需要场景中存在名为"player"的组

## 适用场景

### 激光类技能
- 直线激光束
- 扫射激光
- 十字激光
- 对角线激光

### 冲锋类技能
- Boss冲锋攻击
- 直线冲撞
- 路径预警

### 范围技能
- 矩形火墙
- 线性爆炸
- 剑气斩击

## 注意事项

1. 确保玩家节点在"player"组中
2. 玩家节点需要有`take_damage(damage)`方法
3. 使用完毕后调用`cleanup()`释放资源
4. 需要提前准备好AnimationPlayer节点用于播放预警结束后的动画
5. 起始点和目标点不能相同，否则无法计算矩形方向

## 与圆形工具的区别

| 特性 | 圆形工具 | 矩形工具 |
|------|----------|----------|
| 形状 | 圆形/椭圆形 | 矩形 |
| 参数 | 半径 + 长宽比 | 起始点 + 目标点 + 宽度 |
| 适用场景 | 爆炸、范围魔法 | 激光、冲锋、线性攻击 |
| 碰撞检测 | 距离计算 | 坐标变换 |

## 示例场景

参考 `warn_rect_example.gd` 文件查看完整的使用示例，包括各种激光模式和攻击模式。