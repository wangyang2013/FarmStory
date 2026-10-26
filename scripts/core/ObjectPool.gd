class_name ObjectPool
extends RefCounted
## 通用节点对象池：高频创建/销毁的短命节点（挥砍弧光、粒子等）复用。
##
## 用法：
##     var pool := ObjectPool.new(parent, func() -> Node: return MyNode.new(), 4)
##     var node := pool.acquire()
##     pool.release(node)

var _parent: Node
var _factory: Callable
var _available: Array[Node] = []
var _active: Array[Node] = []


func _init(parent: Node, factory: Callable, prewarm := 0) -> void:
	_parent = parent
	_factory = factory
	for index in maxi(0, prewarm):
		var node: Node = _factory.call()
		_prepare_idle(node)
		_parent.add_child(node)
		_available.append(node)


## 取出一个节点：池空时自动创建，并让节点恢复可见与处理。
func acquire() -> Node:
	var node: Node
	if _available.is_empty():
		node = _factory.call()
		_parent.add_child(node)
	else:
		node = _available.pop_back()
	node.visible = true
	node.process_mode = Node.PROCESS_MODE_INHERIT
	if node.has_method("on_pool_acquire"):
		node.call("on_pool_acquire")
	_active.append(node)
	return node


## 归还节点：隐藏并停止处理，留待下次复用。
func release(node: Node) -> void:
	if node == null or not _active.has(node):
		return
	_active.erase(node)
	if node.has_method("on_pool_release"):
		node.call("on_pool_release")
	_prepare_idle(node)
	_available.append(node)


func release_all() -> void:
	for node: Node in _active.duplicate():
		release(node)


func active_count() -> int:
	return _active.size()


func available_count() -> int:
	return _available.size()


func _prepare_idle(node: Node) -> void:
	node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
