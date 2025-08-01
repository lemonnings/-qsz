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

# 在一个以魔法为主的世界里，人们依靠水晶（灵石）里存储的以太来释放法术，法术在日常生活中逐渐被滥用，在一次大规模战争中，因过度开采“以太矿”引发了能量崩溃，浓缩以太异化为魔物，大地生机断绝。
# 这个世界的一名黑魔法师为了拯救故土，研发跨位面以太汲取术，在一次实验中，因为过量吸收以太，导致其世界与本位面通过“裂隙”产生交融，黑魔法师也在实验事故中被传至龙门山，他因恐慌展开了一道幻境屏障，却未察觉时空裂隙正导致魔物的涌入，而大量未经提纯的以太也一并涌入龙门山，诱使龙门山的魔物也开始滋生。
# 察觉到龙门山被幻境封锁，山脚下的村民向管辖这片区域的八玄阁求助，八玄阁派出的中级弟子在进入幻境后便杳无音讯，这让八玄阁的上层开始重视这件事，并准备先派一名八部中的领袖来解决此事。
# 经过一番探测后，八玄阁发现这个幻境的构造超出了他们所有人的知识范畴（因为都不是一个世界的），因此决定除了派遣本阁弟子之外，也广招天下侠士前来共同探索这个幻境。
# 主角团是来协助解决这件事的侠士，精通传送技术的巽在村落外围铺设了返回锚点，然后把主角传送到了幻境的外围。
# 在幻境外围和幻境内部连续击败几个镇守一个区域的boss后，幻境的效力下降，开启了通往幻境深处的道路，在幻境深处可以抓住幻境的始作俑者黑魔法师诺姆。
# 在战斗中击败了诺姆后，诺姆无奈的表示自己的幻境在展开之后就发现无法关闭了，这个世界的以太太过丰富，导致幻境的后备能源几乎是无尽的，而且幻境的核心处由于凝结了过多的以太，有一个连他都无法控制的boss诞生了。
# 一部分简单设定
# 地图分为4个区域，外围，内部，深处，核心；每次进入地图的某个区域，会有一个以太活跃度的设定，通过在区域里战斗的时间+杀怪提升活跃度，活跃度达到满值后随机出现一个这个区域的boss（比如外围会随机从千年树精，晶矿化巨虎，腐蚀粘液怪中出现一个）
# 其中每个区域都有一个探索度，以太活跃度的提升也可以同步提升探索进度，当探索度高于70%后，下次关卡中以太活跃度满值后出现的boss就是镇守这个区域的最终boss，击败后可以开启下个区域
# 通过收集关卡内掉落，还可以合成进入隐藏地图的钥匙，用来开启特殊关卡
# 杀怪后获得的真气、灵石：在外围击杀了一众小怪之后，主角发现这些小怪身上因为有大量的“以太”（可以解释成这个世界中的真气一类的），在击杀了之后一部分以太外溢，可以吸收了之后增加实力，另一部分过于精纯的以太化作了灵石（游戏内货币）。因为魔法世界的人都把以太当做外置能量，用来释放魔法，而修仙的是吸纳这些能量储存在自己身体里。
# hp归0之后：巽预设了返回的地点，由兑绘制的返回符，是在遇到生命危险时可以紧急传回的符咒，击杀了boss之后，也可以用来返回村落处
# 队友：初始是奕秋，击败诺姆之后诺姆也是可用角色，后面可以通过支线来添加其他角色，暂时做两个
# 奕秋，初始武器：剑气，专属技能：闪避、兽化，可掌握技能：加速，乱击，可掌握武器：扫帚，赤曜，环火
# 诺姆，初始武器：冰针，专属技能：魔纹、激情咏唱，可掌握技能：魔罩，究极，掌握武器：世界树之枝，魔焰，星弹
# NPC：
# 乾：召唤水晶维护（切换角色的地方）自信满满，有点傲娇的天才少年。自认为是"天命之子"，说话时常带着"本座认为..."的口吻。虽然有点自大，但确实有真才实学，能准确判断每个人最适合的角色定位。喜欢用星象和命运来解释事物，有点中二但很可爱。
# 坤：炼丹（eg：小怪材料，boss材料加上坎卖的材料，可以组合炼丹）圆脸，赭石色粗布道袍，有一些烧焦的破烂痕迹，袖口沾着药草碎屑。温柔体贴，像大哥哥一样照顾每个人。有点笨拙但非常认真，经常因为炼丹太专注而忘记吃饭。对各种材料的特性了如指掌，但不善言辞，说话时常常结巴
# 离：铁匠（局外养成之一，强化法宝）铁匠围裙，但花纹繁复一些，衣角焦黑，随身携带沾着火星的锤子。说话声音洪亮，喜欢大笑。对锻造工艺极其热爱，一谈到法宝就眼睛发亮。有点火爆脾气，但来得快去得也快。非常重视承诺，答应的事一定会做到。虽然看起来粗犷，但对细节非常讲究。
# 巽：关卡传送阵，长发束起，穿着花青色轻便服饰，周围飘着羽毛。机智灵活，像风一样难以捉摸。说话带点神秘感，喜欢用谜语和暗示。作为传送阵的管理者，知道很多秘密通道和捷径。有点爱玩，喜欢捉弄别人，但心地不坏。经常突然出现又突然消失，让人捉摸不透。
# 坎，云游商人（每次完成关卡后刷新，如果通关刷新出好东西概率更高）年龄最小，湖蓝色短衫，手持一把画着水波纹的折扇。是精明的商人，说话滴水不漏。擅长察言观色，能准确判断对方想要什么。有点狡猾，但不会做太过分的事。
# 震：进阶（局外养成之二，被动/主动技能树->可以强化升级选项）短发凌乱，藤黄色劲装，腰间别着闪电形状的小铃铛。活力四射的热血少年，总是充满干劲。说话大声，行动迅速，常常不等别人说完就行动。虽然冲动但很讲义气，喜欢挑战高难度的技能升级。有点孩子气，但关键时刻很可靠。经常因为太急躁而犯小错误，然后红着脸道歉。
# 艮：修炼（局外养成之三，直接提升基础属性）敦实体格，雄黄色朴素衣裳。沉稳内敛的修行者，话不多但每句都很有分量。修炼时能保持数小时不动，专注力极强。有点固执，认定的事情很难改变。虽然看起来严肃，但对真心求教的人会耐心指导。
# 兑：合成（eg：通过材料合成新法宝，开启隐藏关卡）石绿色轻便衣裳，衣角缝着贝壳风铃，手里捏着符咒。说话风趣幽默，很会调节气氛。对合成有独特天赋，经常能想到别人想不到的组合。有点话痨。
	
	#1层，主动技能闪避，解锁世界树之枝，召唤蓝紫，幸运提升，剑气/树枝强化初始等级提升1~3
	#2层，闪避无敌时间增加，闪避cd降低，主动技能加速，解锁扫帚，召唤金红，经验获得提升，魔焰初始1~3
	#3层，加速效果提升，持续时间增加，cd降低，主动技能魔化，解锁ry，召唤金红进阶，幸运系，幸运提升，ry初始1~3
	#4层，魔化效果提升，持续时间增加，cd降低，主动技能乱击，解锁环火，主武器+1，经验获得提升，环火初始1~3
	#5层，乱击范围提升，子弹数量提升，cd降低，幸运，经验获得提升，幸运系金红

	#1层，主动技能魔罩，解锁炽炎，催化系蓝紫
	#催化，提升怪的数量，换取其他加成，白绿怪+5%，蓝紫+10%，金红+15%，经验加成+15%/22%/37%/44%/59%/66%，最终伤害提升4%/5.5%/9.5%/11%/15%/16.5%
	# 提升怪的属性，换取经验加成或者减伤率2%~8.3%
	#2层，命运系，初始20面骰，1大失败20大成功，2~10失败，11~19成功
	#紫，成功判定点+1
	#金，大成功判定点+1
	#红，