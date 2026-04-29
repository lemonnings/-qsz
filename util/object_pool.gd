## 通用对象池 —— 用于高频创建/销毁的场景实例复用
## 使用方式：
##   var pool = ObjectPool.new(preload("res://Scenes/xxx.tscn"), 20)
##   add_child(pool)          # 必须挂到场景树上
##   var obj = pool.acquire() # 取出一个可用实例（自动 add_child 到 pool）
##   pool.release(obj)        # 回收实例（隐藏并从场景树摘除到池中缓存）
class_name ObjectPool
extends Node

## 预加载的 PackedScene
var _scene: PackedScene
## 空闲对象队列
var _free_list: Array[Node] = []
## 预热数量上限
var _warm_up_count: int = 0
## 活跃计数（用于外部监控）
var active_count: int = 0

## scene   : 要池化的 PackedScene（必须 preload）
## warm_up : 预热数量，构造时立即创建缓存
func _init(scene: PackedScene, warm_up: int = 0) -> void:
	_scene = scene
	_warm_up_count = warm_up

func _ready() -> void:
	# 预热：提前创建一批实例放入空闲列表
	for i in range(_warm_up_count):
		var inst = _scene.instantiate()
		_deactivate(inst)
		_free_list.append(inst)

## 从池中取出一个实例。
## parent : 取出后挂载的父节点（默认 null 则挂到 get_tree().current_scene）
## 返回 : 可用的节点实例（已 visible = true，已加入场景树）
func acquire(parent: Node = null) -> Node:
	var inst: Node
	if _free_list.size() > 0:
		inst = _free_list.pop_back()
		# 池中缓存的实例可能已经因为外部 queue_free 等原因失效
		if not is_instance_valid(inst):
			inst = _scene.instantiate()
	else:
		inst = _scene.instantiate()
	
	# 绑定池引用，便于 recycle() 时找回归属的池
	inst.set_meta("_object_pool", self )
	_activate(inst)
	
	var target_parent = parent if parent else get_tree().current_scene
	if target_parent and inst.get_parent() != target_parent:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		target_parent.add_child(inst)
	
	active_count += 1
	return inst

## 静态回收工具：若节点属于某个对象池则回收复用，否则 queue_free。
## 用法：在子弹脚本中用 ObjectPool.recycle(self) 替代 queue_free()
static func recycle(inst: Node) -> void:
	if not is_instance_valid(inst):
		return
	if inst.has_meta("_object_pool"):
		var pool = inst.get_meta("_object_pool")
		if pool and is_instance_valid(pool):
			# 调用实例的重置方法（如果有）
			if inst.has_method("reset_for_pool"):
				inst.reset_for_pool()
			pool.release(inst)
			return
	inst.queue_free()

## 回收实例到池中（不销毁，隐藏并从场景树移除）
func release(inst: Node) -> void:
	if not is_instance_valid(inst):
		return
	_deactivate(inst)
	# 立即移除（而非 deferred），避免快速 acquire/release 循环时的竞态
	if inst.get_parent():
		inst.get_parent().remove_child(inst)
	_free_list.append(inst)
	active_count = max(active_count - 1, 0)

## 清空池（真正释放所有缓存实例的内存）
func clear_pool() -> void:
	for inst in _free_list:
		if is_instance_valid(inst):
			inst.queue_free()
	_free_list.clear()
	active_count = 0

## 获取当前缓存的空闲实例数
func free_count() -> int:
	return _free_list.size()

# ── 内部工具 ──

func _activate(inst: Node) -> void:
	inst.set_process(true)
	inst.set_physics_process(true)
	inst.visible = true
	# 重新启用碰撞（如果有的话）
	if inst.has_method("set_deferred"):
		var cs = inst.get_node_or_null("CollisionShape2D")
		if cs:
			cs.set_deferred("disabled", false)

func _deactivate(inst: Node) -> void:
	inst.set_process(false)
	inst.set_physics_process(false)
	inst.visible = false
	# 禁用碰撞
	var cs = inst.get_node_or_null("CollisionShape2D")
	if cs:
		cs.set_deferred("disabled", true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear_pool()
