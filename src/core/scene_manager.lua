-- 模块名: scene_manager
-- 功能: 场景管理器
-- 说明: 管理游戏场景（屏幕/页面），支持切换、压栈、弹出
-- 类比: React Router / iOS 视图控制器 / Android Activity 栈

local Logger = require("src.core.logger")
local EventBus = require("src.core.event_bus")

local SceneManager = {}

-- ============================================================
-- 场景生命周期说明
--
-- 每个场景是一个 table，包含以下方法（都是可选的）：
--   scene:enter(params)   - 进入场景时调用（类似 componentDidMount）
--   scene:update(dt)      - 每帧更新逻辑
--   scene:draw()          - 每帧渲染
--   scene:exit()          - 离开场景时调用（类似 componentWillUnmount）
--   scene:pause()         - 被 push 到下面时调用（暂停）
--   scene:resume()        - 上面的场景 pop 后调用（恢复）
--
-- 类比: 每个场景 = 一个页面/屏幕
-- ============================================================

-- ============================================================
-- 内部状态
-- ============================================================

-- 已注册的场景表
-- 结构: { scene_name = scene_table_or_class }
local _scenes = {}

-- 场景栈
-- 数组形式，栈顶在最后
-- 每个元素: { name = "scene_name", instance = scene_table, params = {...} }
local _stack = {}

-- 是否有挂起的场景切换（在下一帧开头执行）
-- 避免在 update 中间切换场景导致状态不一致
local _pending_switch = nil
local _pending_push = nil
local _pending_pop = false

-- ============================================================
-- 内部函数
-- ============================================================

-- 获取当前场景（栈顶）
-- @return (table|nil) 当前场景实例
local function _get_current()
    if #_stack == 0 then
        return nil
    end
    return _stack[#_stack]
end

-- 执行场景切换（内部用）
-- @param scene_name (string) 场景名
-- @param params (table) 参数
local function _do_switch(scene_name, params)
    Logger.debugf("SceneManager: switching to '%s'", scene_name)

    -- 先退出当前场景
    if #_stack > 0 then
        local current = _stack[#_stack]
        if current.instance and current.instance.exit then
            local success, err = pcall(function()
                current.instance:exit()
            end)
            if not success then
                Logger.errorf("SceneManager: error in scene exit '%s': %s", current.name, err)
            end
        end
        -- 弹出旧场景
        table.remove(_stack)
    end

    -- 创建新场景
    local scene_class = _scenes[scene_name]
    if not scene_class then
        Logger.errorf("SceneManager: scene '%s' not found", scene_name)
        return false
    end

    -- 创建场景实例
    -- 如果是 table，直接用（简单场景）
    -- 如果有 new 方法，调用 new 创建（复杂场景）
    local instance
    if type(scene_class.new) == "function" then
        instance = scene_class.new()
    else
        -- 浅拷贝一份，避免多个场景共享状态
        instance = {}
        for k, v in pairs(scene_class) do
            instance[k] = v
        end
    end

    -- 入栈
    table.insert(_stack, {
        name = scene_name,
        instance = instance,
        params = params or {},
    })

    -- 调用 enter
    if instance.enter then
        local success, err = pcall(function()
            instance:enter(params or {})
        end)
        if not success then
            Logger.errorf("SceneManager: error in scene enter '%s': %s", scene_name, err)
        end
    end

    -- 发布事件
    EventBus.emit("scene:changed", scene_name)

    Logger.infof("SceneManager: switched to '%s'", scene_name)
    return true
end

-- 执行 push（内部用）
local function _do_push(scene_name, params)
    Logger.debugf("SceneManager: pushing '%s'", scene_name)

    -- 暂停当前场景
    if #_stack > 0 then
        local current = _stack[#_stack]
        if current.instance and current.instance.pause then
            current.instance:pause()
        end
    end

    -- 创建新场景
    local scene_class = _scenes[scene_name]
    if not scene_class then
        Logger.errorf("SceneManager: scene '%s' not found", scene_name)
        return false
    end

    local instance
    if type(scene_class.new) == "function" then
        instance = scene_class.new()
    else
        instance = {}
        for k, v in pairs(scene_class) do
            instance[k] = v
        end
    end

    table.insert(_stack, {
        name = scene_name,
        instance = instance,
        params = params or {},
    })

    if instance.enter then
        local success, err = pcall(function()
            instance:enter(params or {})
        end)
        if not success then
            Logger.errorf("SceneManager: error in scene enter '%s': %s", scene_name, err)
        end
    end

    EventBus.emit("scene:pushed", scene_name)
    Logger.infof("SceneManager: pushed '%s'", scene_name)
    return true
end

-- 执行 pop（内部用）
local function _do_pop()
    if #_stack <= 1 then
        Logger.warn("SceneManager: cannot pop, only one scene in stack")
        return false
    end

    local current = _stack[#_stack]
    Logger.debugf("SceneManager: popping '%s'", current.name)

    -- 退出当前场景
    if current.instance and current.instance.exit then
        local success, err = pcall(function()
            current.instance:exit()
        end)
        if not success then
            Logger.errorf("SceneManager: error in scene exit '%s': %s", current.name, err)
        end
    end

    -- 弹出
    table.remove(_stack)

    -- 恢复上一个场景
    local prev = _stack[#_stack]
    if prev.instance and prev.instance.resume then
        prev.instance:resume()
    end

    EventBus.emit("scene:popped", prev.name)
    Logger.infof("SceneManager: popped to '%s'", prev.name)
    return true
end

-- ============================================================
-- 公开 API - 注册场景
-- ============================================================

-- 注册场景
-- 场景必须先注册才能切换
-- 类比: 路由注册
-- @param name (string) 场景名
-- @param scene (table) 场景 table 或类
function SceneManager.register(name, scene)
    if type(scene) ~= "table" then
        Logger.errorf("SceneManager: cannot register '%s', not a table", name)
        return
    end

    _scenes[name] = scene
    Logger.debugf("SceneManager: registered scene '%s'", name)
end

-- 批量注册场景
-- @param scenes (table) { name = scene_table, ... }
function SceneManager.register_all(scenes)
    for name, scene in pairs(scenes) do
        SceneManager.register(name, scene)
    end
end

-- 检查场景是否已注册
-- @param name (string) 场景名
-- @return (boolean)
function SceneManager.is_registered(name)
    return _scenes[name] ~= nil
end

-- ============================================================
-- 公开 API - 场景切换
-- ============================================================

-- 切换场景（替换当前场景）
-- 旧场景会被销毁（exit）
-- 注意：切换在下一帧开始时生效，不在当前帧执行
-- 类比: history.replace 或 router.replace
-- @param name (string) 场景名
-- @param params (table) 传给新场景 enter 的参数
function SceneManager.switch(name, params)
    if not _scenes[name] then
        Logger.errorf("SceneManager: cannot switch to '%s', not registered", name)
        return false
    end

    -- 设置挂起的切换，在下一帧 update 开始时执行
    -- 避免在当前帧的 update/draw 中间切换导致问题
    _pending_switch = { name = name, params = params }
    _pending_push = nil
    _pending_pop = false

    return true
end

-- 压入场景（保留当前场景在栈下）
-- 用于弹窗、暂停菜单等
-- 类比: history.push 或 modal
-- @param name (string) 场景名
-- @param params (table) 参数
function SceneManager.push(name, params)
    if not _scenes[name] then
        Logger.errorf("SceneManager: cannot push '%s', not registered", name)
        return false
    end

    _pending_push = { name = name, params = params }
    _pending_switch = nil

    return true
end

-- 弹出场景（回到上一个场景）
-- 类比: history.back
function SceneManager.pop()
    if #_stack <= 1 then
        Logger.warn("SceneManager: cannot pop, at bottom of stack")
        return false
    end

    _pending_pop = true
    _pending_switch = nil

    return true
end

-- ============================================================
-- 公开 API - 查询
-- ============================================================

-- 获取当前场景名
-- @return (string|nil) 当前场景名
function SceneManager.get_current_name()
    local current = _get_current()
    if current then
        return current.name
    end
    return nil
end

-- 获取当前场景实例
-- 谨慎使用，尽量通过事件通信
-- @return (table|nil) 当前场景实例
function SceneManager.get_current_scene()
    local current = _get_current()
    if current then
        return current.instance
    end
    return nil
end

-- 获取场景栈深度
-- @return (number) 栈深度
function SceneManager.get_stack_depth()
    return #_stack
end

-- ============================================================
-- 公开 API - 主循环调用
-- ============================================================

-- 每帧更新
-- 由主循环的 love.update 调用
-- @param dt (number) 距上一帧的时间（秒）
function SceneManager.update(dt)
    -- 先处理挂起的场景切换
    if _pending_switch then
        _do_switch(_pending_switch.name, _pending_switch.params)
        _pending_switch = nil
        -- 切换后这一帧的 update 就不执行了？
        -- 还是执行吧，新场景也需要 update
    end

    if _pending_push then
        _do_push(_pending_push.name, _pending_push.params)
        _pending_push = nil
    end

    if _pending_pop then
        _do_pop()
        _pending_pop = false
    end

    -- 更新当前场景
    local current = _get_current()
    if current and current.instance and current.instance.update then
        local success, err = pcall(function()
            current.instance:update(dt)
        end)
        if not success then
            Logger.errorf("SceneManager: error in scene update '%s': %s", current.name, err)
        end
    end
end

-- 每帧绘制
-- 由主循环的 love.draw 调用
-- 注意：场景自己决定用 RenderLayer 还是直接画
-- V0 的简单场景可以直接画，复杂场景用 RenderLayer
function SceneManager.draw()
    local current = _get_current()
    if current and current.instance and current.instance.draw then
        local success, err = pcall(function()
            current.instance:draw()
        end)
        if not success then
            Logger.errorf("SceneManager: error in scene draw '%s': %s", current.name, err)
            -- 画一个错误提示
            love.graphics.setColor(1, 0, 0)
            love.graphics.print("Scene draw error: " .. err, 10, 10)
            love.graphics.setColor(1, 1, 1)
        end
    else
        -- 没有场景时显示提示
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print("No scene loaded", 10, 10)
        love.graphics.setColor(1, 1, 1)
    end
end

return SceneManager
