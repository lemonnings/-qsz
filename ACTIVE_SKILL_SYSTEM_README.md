# 主动技能系统使用说明

## 概述

主动技能系统为游戏提供了可配置的主动技能功能，玩家可以通过快捷键使用各种技能。系统包含技能管理、快捷键配置和技能效果执行等功能。

## 系统组件

### 1. ActiveSkillManager (主动技能管理器)
- **文件位置**: `config/active_skill_manager.gd`
- **功能**: 管理所有主动技能的使用、冷却和效果
- **自动加载**: 通过 `Global.ActiveSkillManager` 访问

### 2. SkillHotkeyConfig (技能快捷键配置)
- **文件位置**: `config/skill_hotkey_config.gd`
- **功能**: 提供拖拽式技能快捷键配置界面
- **使用方式**: 创建实例并调用 `show_config()` 方法

### 3. ActiveSkillTest (测试脚本)
- **文件位置**: `config/active_skill_test.gd`
- **功能**: 测试和演示主动技能系统的使用
- **测试按键**: F1-F5 提供各种测试功能

## 快捷键配置

### 默认快捷键
- **Shift**: 闪避技能（默认绑定）
- **Space**: 空槽位
- **Q**: 空槽位
- **E**: 空槽位

### 使用限制
- 主动技能只能在非城镇环境下使用
- 城镇检测基于场景文件路径是否包含 "town" 或 "城镇"

## 已实现技能

### 闪避技能 (Dash)
- **技能ID**: "dash"
- **效果**: 向当前移动方向快速冲刺
- **参数**:
  - 冲刺距离: 50px
  - 速度倍率: 10倍当前移动速度
  - 冷却时间: 10秒
  - 无敌时间: 0.3秒
- **方向逻辑**:
  - 有移动输入时：使用移动方向
  - 无移动输入时：使用角色面向方向
  - 默认方向：向右

## 使用方法

### 1. 基本使用

```gdscript
# 获取技能管理器
var skill_manager = Global.ActiveSkillManager

# 使用技能
skill_manager.use_skill("dash")

# 检查技能状态
var skill = skill_manager.get_skill_by_id("dash")
if skill.state == ActiveSkillManager.SkillState.READY:
    print("技能可用")
```

### 2. 配置快捷键

```gdscript
# 设置技能到快捷键槽位
skill_manager.set_skill_slot("shift", "dash")

# 清空槽位
skill_manager.set_skill_slot("q", "")

# 获取槽位绑定的技能
var skill_id = skill_manager.get_skill_slot("shift")
```

### 3. 显示配置界面

```gdscript
# 创建配置窗口
var config_ui = preload("res://Script/config/skill_hotkey_config.gd").new()
add_child(config_ui)
config_ui.show_config()

# 连接信号
config_ui.config_confirmed.connect(_on_config_confirmed)
config_ui.config_cancelled.connect(_on_config_cancelled)
```

### 4. 监听技能事件

```gdscript
# 连接技能事件
skill_manager.skill_used.connect(_on_skill_used)
skill_manager.skill_cooldown_started.connect(_on_cooldown_started)
skill_manager.skill_cooldown_finished.connect(_on_cooldown_finished)

func _on_skill_used(skill_id: String):
    print("使用了技能: ", skill_id)

func _on_cooldown_started(skill_id: String, cooldown_time: float):
    print("技能进入冷却: ", skill_id, ", 时间: ", cooldown_time)

func _on_cooldown_finished(skill_id: String):
    print("技能冷却完成: ", skill_id)
```

## 扩展新技能

### 1. 创建技能类

```gdscript
# 继承ActiveSkill类
class NewSkill extends ActiveSkillManager.ActiveSkill:
    var custom_parameter: float = 1.0
    
    func _init():
        super("new_skill", "新技能", "技能描述", 5.0)  # ID, 名称, 描述, 冷却时间
        is_unlocked = true
```

### 2. 在管理器中注册

```gdscript
# 在ActiveSkillManager的init_default_skills()方法中添加
func init_default_skills():
    # 现有技能...
    
    # 添加新技能
    var new_skill = NewSkill.new()
    mastered_skills[new_skill.id] = new_skill
```

### 3. 实现技能效果

```gdscript
# 在ActiveSkillManager的execute_skill()方法中添加
func execute_skill(skill: ActiveSkill) -> bool:
    match skill.id:
        "dash":
            return execute_dash_skill(skill as DashSkill)
        "new_skill":
            return execute_new_skill(skill as NewSkill)
        _:
            print("未知技能: ", skill.id)
            return false

func execute_new_skill(skill: NewSkill) -> bool:
    # 实现新技能的效果
    print("执行新技能效果")
    return true
```

## 测试功能

### 测试脚本使用

1. 将 `ActiveSkillTest` 脚本添加到场景中
2. 使用以下按键进行测试：
   - **F1**: 打印技能状态
   - **F2**: 测试闪避技能
   - **F3**: 测试技能槽位配置
   - **F4**: 显示技能配置窗口
   - **F5**: 显示帮助信息

### 自动测试

```gdscript
# 运行自动测试
var test_script = ActiveSkillTest.new()
add_child(test_script)
test_script.run_auto_test()
```

## 注意事项

1. **输入系统兼容性**: 系统自动适配移动设备的虚拟摇杆和桌面设备的键盘输入
2. **场景切换**: 系统会在场景切换时自动重置状态
3. **性能考虑**: 技能冷却和输入检测在每帧更新，注意性能影响
4. **错误处理**: 系统包含基本的错误检查，但建议在使用前验证技能和玩家状态

## 未来扩展

- [ ] 法宝系统集成
- [ ] 技能升级系统
- [ ] 技能组合效果
- [ ] 配置文件保存/加载
- [ ] 技能动画系统
- [ ] 技能音效管理

## 集成指南

### 与现有玩家控制器集成

1. **查看集成示例**
   - 参考 `config/player_skill_integration.gd` 文件
   - 该文件包含完整的集成步骤和示例代码

2. **基本集成步骤**
   ```gdscript
   # 在player_action.gd中添加变量
   var skill_manager: ActiveSkillManager
   
   # 在_ready()函数中初始化
   func _ready():
       # ... 现有代码 ...
       skill_manager = Global.ActiveSkillManager
       if skill_manager:
           skill_manager.skill_used.connect(_on_skill_used)
   
   # 添加技能事件处理
   func _on_skill_used(skill_id: String):
       print("使用技能: ", skill_id)
   ```

3. **获取玩家面向方向**
   ```gdscript
   func get_facing_direction() -> Vector2:
       if sprite_direction_right:
           return Vector2.RIGHT
       else:
           return Vector2.LEFT
   ```

## 故障排除

### 常见问题

1. **技能无法使用**
   - 检查是否在城镇环境中
   - 确认技能是否在冷却中
   - 验证快捷键配置是否正确
   - 确认 `Global.ActiveSkillManager` 已正确初始化

2. **闪避技能方向错误**
   - 检查玩家输入系统是否正常
   - 确认移动输入和面向方向的逻辑
   - 验证 `get_facing_direction()` 方法是否正确实现

3. **技能配置UI无法显示**
   - 确认UI节点创建是否成功
   - 检查场景树结构
   - 验证 `SkillHotkeyConfig` 类是否正确加载

4. **系统初始化失败**
   - 检查 `global.gd` 中的 `ActiveSkillManager` 初始化
   - 确认所有脚本文件路径正确
   - 查看控制台是否有错误信息

### 调试建议

- 使用 `config/active_skill_test.gd` 测试脚本验证系统功能
- 检查控制台输出的调试信息
- 确认所有必要的信号连接正确
- 使用 F1-F5 键进行各项功能测试

### 调试方法

```gdscript
# 启用调试输出
func debug_skill_system():
    var skill_manager = Global.ActiveSkillManager
    print("技能管理器状态: ", skill_manager != null)
    print("已掌握技能数量: ", skill_manager.get_mastered_skills().size())
    print("当前场景: ", get_tree().current_scene.scene_file_path)
    print("是否在城镇: ", skill_manager.is_in_town())
```