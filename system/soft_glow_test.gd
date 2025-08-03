extends Node

# 测试柔光滤镜的脚本
# 可以通过按键来调整滤镜效果

func _ready():
	print("柔光滤镜测试脚本已加载")
	print("按键说明:")
	print("4 - 降低晕影强度")
	print("5 - 增加晕影强度")

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_4:
				# 降低晕影强度
				if SoftGlowManager.soft_glow_filter and SoftGlowManager.soft_glow_filter.filter_rect and SoftGlowManager.soft_glow_filter.filter_rect.material:
					var current_vignette = SoftGlowManager.soft_glow_filter.filter_rect.material.get_shader_parameter("vignette_strength")
					var new_vignette = max(0.0, current_vignette - 0.05)
					SoftGlowManager.set_vignette_strength(new_vignette)
					print("晕影强度: ", new_vignette)
			
			KEY_5:
				# 增加晕影强度
				if SoftGlowManager.soft_glow_filter and SoftGlowManager.soft_glow_filter.filter_rect and SoftGlowManager.soft_glow_filter.filter_rect.material:
					var current_vignette = SoftGlowManager.soft_glow_filter.filter_rect.material.get_shader_parameter("vignette_strength")
					var new_vignette = min(1.0, current_vignette + 0.05)
					SoftGlowManager.set_vignette_strength(new_vignette)
					print("晕影强度: ", new_vignette)
