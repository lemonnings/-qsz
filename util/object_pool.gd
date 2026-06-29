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
## 是否在预热时短暂入树，提前触发 _ready，避免首次 acquire 集中初始化。
var _initialize_warm_up_instances: bool = false
## 活跃计数（用于外部监控）
var active_count: int = 0
## 追踪待延迟移除的节点 instance_id，防止 reacquire 后被延迟 remove_child 误移除
var _pending_removes: Dictionary = {}

## scene   : 要池化的 PackedScene（必须 preload）
## warm_up : 预热数量，构造时立即创建缓存
func _init(scene: PackedScene, warm_up: int = 0, initialize_warm_up_instances: bool = false) -> void:
	_scene = scene
	_warm_up_count = warm_up
	_initialize_warm_up_instances = initialize_warm_up_instances

func _ready() -> void:
	# 预热：提前创建一批实例放入空闲列表
	for i in range(_warm_up_count):
		var inst = _scene.instantiate()
		if _initialize_warm_up_instances:
			add_child(inst)
		_deactivate(inst)
		if _initialize_warm_up_instances and inst.get_parent() == self:
			remove_child(inst)
		_free_list.append(inst)

## 从池中取出一个实例。
## parent : 取出后挂载的父节点（默认 null 则挂到 get_tree().current_scene）
## 返回 : 可用的节点实例（已 visible = true，已加入场景树）
## 注意：CollisionObject2D 子类在物理回调中需延迟 add_child，
##       非 CollisionObject2D 节点直接入树，保证 create_tween 等立即可用。
func acquire(parent: Node = null) -> Node:
	var inst: Node
	if _free_list.size() > 0:
		inst = _free_list.pop_back()
		# 池中缓存的实例可能已经因为外部 queue_free 等原因失效
		if not is_instance_valid(inst):
			inst = _scene.instantiate()
	else:
		inst = _scene.instantiate()
	
	# 取消待移除标记（防止延迟 remove_child 误移除已重新取出的节点）
	_pending_removes.erase(inst.get_instance_id())
	# 移除回收标记
	inst.remove_meta("_pool_recycled")
	
	# 绑定池引用，便于 recycle() 时找回归属的池
	inst.set_meta("_object_pool", self)
	_activate(inst)
	
	var target_parent = parent if parent else get_tree().current_scene
	if target_parent and inst.get_parent() != target_parent:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		# CollisionObject2D 在物理回调中 add_child 会报错，需要延迟
		# 非 CollisionObject2D（如 damage_label）直接入树，保证立即可用
		if inst is CollisionObject2D:
			target_parent.call_deferred("add_child", inst)
		else:
			target_parent.add_child(inst)
	
	active_count += 1
	return inst

## 静态回收工具：若节点属于某个对象池则回收复用，否则 queue_free。
## 用法：在子弹脚本中用 ObjectPool.recycle(self) 替代 queue_free()
static func recycle(inst: Node) -> void:
	if not is_instance_valid(inst):
		return
	# 防止双重回收（同一帧内物理回调可能多次触发）
	if inst.has_meta("_pool_recycled"):
		return
	if inst.has_meta("_object_pool"):
		var pool = inst.get_meta("_object_pool")
		if pool and is_instance_valid(pool):
			inst.set_meta("_pool_recycled", true)
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
	# CollisionObject2D 在物理回调中 remove_child 会报错，需延迟移除
	# 非 CollisionObject2D 直接移除，保证池状态一致
	if inst.get_parent():
		if inst is CollisionObject2D:
			_pending_removes[inst.get_instance_id()] = true
			call_deferred("_deferred_remove_from_tree", inst)
		else:
			inst.get_parent().remove_child(inst)
	_free_list.append(inst)
	active_count = max(active_count - 1, 0)

## 延迟执行从场景树移除，带安全检查防止误移除已重新取出的节点
func _deferred_remove_from_tree(inst: Node) -> void:
	if not is_instance_valid(inst):
		return
	var id = inst.get_instance_id()
	if not _pending_removes.has(id):
		# 已被 acquire 重新取出，跳过移除
		return
	_pending_removes.erase(id)
	if inst.get_parent():
		inst.get_parent().remove_child(inst)

## 清空池（真正释放所有缓存实例的内存）
func clear_pool() -> void:
	_pending_removes.clear()
	for inst in _free_list:
		if is_instance_valid(inst):
			inst.queue_free()
	_free_list.clear()
	active_count = 0

## 获取当前缓存的空闲实例数
func free_count() -> int:
	return _free_list.size()

func pending_remove_count() -> int:
	return _pending_removes.size()

func get_debug_stats() -> Dictionary:
	var valid_free := 0
	var parented_free := 0
	for inst in _free_list:
		if not is_instance_valid(inst):
			continue
		valid_free += 1
		if inst.get_parent() != null:
			parented_free += 1
	return {
		"active": active_count,
		"free": valid_free,
		"pending_remove": _pending_removes.size(),
		"parented_free": parented_free,
		"pool_children": get_child_count(),
	}

# ── 内部工具 ──

func _activate(inst: Node) -> void:
	inst.set_process(true)
	inst.set_physics_process(true)
	inst.visible = true
	# 重新启用碰撞（如果有的话）
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
