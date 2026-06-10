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
-- V1 之后用过渡动画替代，但变量保留用于兼容
local _pending_switch = nil
local _pending_push = nil
local _pending_pop = false

-- ============================================================
-- 场景过渡动画
-- ============================================================

-- 过渡状态常量
local TRANSITION_STATE = {
    IDLE = "idle",       -- 没有过渡
    FADING_OUT = "out",  -- 淡出（变黑）
    FADING_IN = "in",    -- 淡入（变明）
}

-- 过渡配置（内部状态）
local _transition = {
    state = TRANSITION_STATE.IDLE,
    progress = 0,        -- 0-1，过渡进度
    duration = 0.3,      -- 过渡时长（秒）
    pending_scene = nil, -- 过渡结束后要切换的场景
    pending_params = nil,
    pending_type = nil,  -- "switch", "push", "pop"
}

-- 过渡函数的前向声明（Lua 作用域规则：local 变量在声明后才可见）
-- 这些函数在文件后面定义
local _start_transition
local _update_transition
local _draw_transition

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
-- 带有淡入淡出过渡效果
-- 类比: history.replace 或 router.replace
-- @param name (string) 场景名
-- @param params (table) 传给新场景 enter 的参数
function SceneManager.switch(name, params)
    if not _scenes[name] then
        Logger.errorf("SceneManager: cannot switch to '%s', not registered", name)
        return false
    end

    -- 如果正在过渡中，忽略请求
    if _transition.state ~= TRANSITION_STATE.IDLE then
        Logger.warn("SceneManager: transition in progress, ignoring switch")
        return false
    end

    return _start_transition("switch", name, params)
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

    if _transition.state ~= TRANSITION_STATE.IDLE then
        Logger.warn("SceneManager: transition in progress, ignoring push")
        return false
    end

    return _start_transition("push", name, params)
end

-- 弹出场景（回到上一个场景）
-- 类比: history.back
function SceneManager.pop()
    if #_stack <= 1 then
        Logger.warn("SceneManager: cannot pop, at bottom of stack")
        return false
    end

    if _transition.state ~= TRANSITION_STATE.IDLE then
        Logger.warn("SceneManager: transition in progress, ignoring pop")
        return false
    end

    return _start_transition("pop", nil, nil)
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
    -- 更新过渡动画
    _update_transition(dt)

    -- 如果正在过渡中，场景的 update 仍然执行吗？
    -- 淡出阶段：当前场景还在显示，继续 update
    -- 淡入阶段：新场景已经切换了，继续 update
    -- 所以不管什么状态，都更新当前场景

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

    -- 绘制过渡覆盖层
    _draw_transition()
end

-- 设置过渡时长
-- @param duration (number) 秒
function SceneManager.set_transition_duration(duration)
    _transition.duration = duration or 0.3
end

-- 检查是否正在过渡
-- @return (boolean)
function SceneManager.is_transitioning()
    return _transition.state ~= TRANSITION_STATE.IDLE
end

-- 开始过渡（内部用）
-- @param type (string) 切换类型: "switch", "push", "pop"
-- @param scene_name (string) 场景名（pop 时为 nil）
-- @param params (table) 参数
_start_transition = function(switch_type, scene_name, params)
    if _transition.state ~= TRANSITION_STATE.IDLE then
        Logger.warn("SceneManager: transition already in progress, ignoring")
        return false
    end

    _transition.state = TRANSITION_STATE.FADING_OUT
    _transition.progress = 0
    _transition.pending_type = switch_type
    _transition.pending_scene = scene_name
    _transition.pending_params = params

    return true
end

-- 更新过渡动画
_update_transition = function(dt)
    if _transition.state == TRANSITION_STATE.IDLE then
        return
    end

    _transition.progress = _transition.progress + dt / _transition.duration

    if _transition.state == TRANSITION_STATE.FADING_OUT then
        -- 淡出阶段
        if _transition.progress >= 1 then
            -- 淡出完成，执行切换
            _transition.progress = 0
            _transition.state = TRANSITION_STATE.FADING_IN

            if _transition.pending_type == "switch" then
                _do_switch(_transition.pending_scene, _transition.pending_params)
            elseif _transition.pending_type == "push" then
                _do_push(_transition.pending_scene, _transition.pending_params)
            elseif _transition.pending_type == "pop" then
                _do_pop()
            end
        end

    elseif _transition.state == TRANSITION_STATE.FADING_IN then
        -- 淡入阶段
        if _transition.progress >= 1 then
            -- 淡入完成，结束过渡
            _transition.state = TRANSITION_STATE.IDLE
            _transition.progress = 0
            _transition.pending_scene = nil
            _transition.pending_params = nil
            _transition.pending_type = nil

            -- 发布事件
            EventBus.emit("scene:transition_complete")
        end
    end
end

-- 绘制过渡覆盖层
_draw_transition = function()
    if _transition.state == TRANSITION_STATE.IDLE then
        return
    end

    local alpha
    if _transition.state == TRANSITION_STATE.FADING_OUT then
        -- 淡出：从透明到黑
        alpha = _transition.progress
    else
        -- 淡入：从黑到透明
        alpha = 1 - _transition.progress
    end

    -- 全屏黑色覆盖
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    love.graphics.setColor(1, 1, 1, 1)
end

return SceneManager
