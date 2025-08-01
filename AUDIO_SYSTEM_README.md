# 音频系统使用说明

## 概述

本项目现在包含了一个完整的音频管理系统，支持分别控制总体音量、BGM音量和音效音量。

## 系统组件

### 1. AudioManager (音频管理器)
- **文件位置**: `system/audio_manager.gd`
- **功能**: 管理所有音频设置，包括音量控制、静音功能、设置保存/加载
- **音频总线**: 自动创建和管理 Master、BGM、SFX 三个音频总线

### 2. AudioSettingsUI (音频设置界面)
- **文件位置**: `system/audio_settings_ui.gd`
- **功能**: 提供用户友好的音频设置界面
- **特性**: 滑块控制、静音按钮、实时预览、重置功能

### 3. 音频总线配置
- **Master**: 总体音量控制
- **BGM**: 背景音乐专用总线
- **SFX**: 音效专用总线

## 使用方法

### 在代码中使用

```gdscript
# 获取音频管理器
var audio_manager = Global.AudioManager

# 设置音量 (0.0 到 1.0)
audio_manager.set_master_volume(0.8)
audio_manager.set_bgm_volume(0.6)
audio_manager.set_sfx_volume(0.9)

# 获取当前音量
var master_vol = audio_manager.get_master_volume()
var bgm_vol = audio_manager.get_bgm_volume()
var sfx_vol = audio_manager.get_sfx_volume()

# 静音控制
audio_manager.toggle_master_mute()
audio_manager.toggle_bgm_mute()
audio_manager.toggle_sfx_mute()

# 重置为默认设置
audio_manager.reset_to_defaults()
```

### 显示音频设置UI

```gdscript
# 在任何场景中显示音频设置
var audio_ui = AudioSettingsUI.show_audio_settings(self)
```

### 为AudioStreamPlayer设置音频总线

```gdscript
# BGM播放器
$BGMPlayer.bus = "BGM"

# 音效播放器
$SFXPlayer.bus = "SFX"
```

## 已集成的文件

以下文件已经集成了音频系统：

1. **global.gd** - 初始化AudioManager
2. **system/bgm.gd** - BGM播放器使用BGM总线
3. **config/player_action.gd** - 玩家音效使用SFX总线
4. **cultivation.gd** - 修炼界面音效使用SFX总线
5. **menu.gd** - 主菜单音效使用SFX总线，包含音频设置按钮
6. **town/main_town.gd** - 城镇音效使用SFX总线

## 设置保存

音频设置会自动保存到 `user://audio_config.cfg` 文件中，包括：
- 总体音量
- BGM音量
- 音效音量

## 添加新音效的步骤

1. 创建AudioStreamPlayer节点
2. 在_ready()函数中设置音频总线：
   ```gdscript
   func _ready():
       $YourSoundPlayer.bus = "SFX"  # 或 "BGM"
   ```
3. 正常使用play()方法播放音效

## 在场景编辑器中使用

1. 在主菜单场景中添加一个按钮
2. 将按钮的pressed信号连接到 `_on_audio_settings_pressed()` 函数
3. 或者直接调用 `AudioSettingsUI.show_audio_settings(self)`

## 注意事项

1. 确保在项目设置中将Global设置为自动加载
2. AudioManager会在游戏启动时自动创建音频总线
3. 音量设置范围为0.0到1.0
4. 静音状态不会影响音量滑块的值
5. 重置功能会将所有音量设置为1.0（100%）

## 扩展功能

可以根据需要添加更多功能：
- 音频淡入淡出效果
- 更多音频总线（如UI音效、环境音效等）
- 音频预设（如夜间模式、专注模式等）
- 键盘快捷键控制音量