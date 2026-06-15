-- 模块名: input
-- 功能: 输入管理系统
-- 说明: 统一管理键盘和鼠标输入，支持动作映射（语义化操作名）
-- 类比: Unity Input System / 游戏手柄按键映射

local Logger = require("src.core.logger")
local EventBus = require("src.core.event_bus")

local Input = {}

-- ============================================================
-- 内部状态
-- ============================================================

-- 动作 -> 按键的映射表
-- 结构: { action_name = key_name }
-- 类比: 键位设置
local _bindings = {}

-- 当前帧按下的动作（这一帧刚按下）
-- 类比: Input.GetButtonDown (Unity)
local _pressed = {}

-- 当前持续按住的动作
-- 类比: Input.GetButton (Unity)
local _held = {}

-- 这一帧刚松开的动作
-- 类比: Input.GetButtonUp (Unity)
local _released = {}

-- 鼠标状态
local _mouse = {
    x = 0,
    y = 0,
    dx = 0,  -- 这一帧的 x 移动量
    dy = 0,  -- 这一帧的 y 移动量
    buttons = {
        -- 1=左键, 2=右键, 3=中键
        pressed = {},   -- 这一帧刚按下
        held = {},      -- 持续按住
        released = {},  -- 这一帧刚松开
    },
}

-- ============================================================
-- 内部函数
-- ============================================================

-- 检查某个键是否被按下
-- 封装 love.keyboard.isDown
-- @param key (string) 键名
-- @return (boolean) 是否按下
local function _is_key_down(key)
    return love.keyboard.isDown(key)
end

-- ============================================================
-- 公开 API - 初始化
-- ============================================================

-- 初始化输入系统
-- 设置默认按键绑定
function Input.init()
    Logger.debug("Input: initializing...")

    -- 清空状态
    _pressed = {}
    _held = {}
    _released = {}

    -- 默认绑定（可以从配置覆盖）
    Input.bind("confirm", "return")   -- 回车 = 确认
    Input.bind("cancel", "escape")    -- ESC = 取消
    Input.bind("pause", "p")          -- P = 暂停
    Input.bind("debug", "f1")         -- F1 = 调试
    Input.bind("space", "space")      -- 空格

    Logger.info("Input: initialized")
end

-- ============================================================
-- 公开 API - 动作绑定
-- ============================================================

-- 绑定动作到按键
-- @param action (string) 动作名（语义化）
-- @param key (string) LÖVE2D 键名（如 "space", "escape", "a"）
function Input.bind(action, key)
    _bindings[action] = key
    Logger.debugf("Input: bind '%s' -> '%s'", action, key)
end

-- 解绑动作
-- @param action (string) 动作名
function Input.unbind(action)
    _bindings[action] = nil
end

-- 获取动作对应的按键
-- @param action (string) 动作名
-- @return (string|nil) 键名
function Input.get_binding(action)
    return _bindings[action]
end

-- 获取所有绑定
-- @return (table) 绑定表的拷贝
function Input.get_all_bindings()
    local copy = {}
    for k, v in pairs(_bindings) do
        copy[k] = v
    end
    return copy
end

-- ============================================================
-- 公开 API - 动作状态查询
-- ============================================================

-- 检查动作在这一帧是否刚按下（只在按下的那一帧返回 true）
-- 类比: Unity 的 Input.GetButtonDown
-- @param action (string) 动作名
-- @return (boolean) 是否刚按下
function Input.is_pressed(action)
    return _pressed[action] == true
end

-- 检查动作是否持续按住
-- 类比: Unity 的 Input.GetButton
-- @param action (string) 动作名
-- @return (boolean) 是否按住
function Input.is_held(action)
    return _held[action] == true
end

-- 检查动作在这一帧是否刚松开（只在松开的那一帧返回 true）
-- 类比: Unity 的 Input.GetButtonUp
-- @param action (string) 动作名
-- @return (boolean) 是否刚松开
function Input.is_released(action)
    return _released[action] == true
end

-- ============================================================
-- 公开 API - 鼠标
-- ============================================================

-- 获取鼠标位置
-- @return (number, number) x, y 坐标
function Input.get_mouse_position()
    return _mouse.x, _mouse.y
end

-- 获取鼠标 x 坐标
-- @return (number) x
function Input.get_mouse_x()
    return _mouse.x
end

-- 获取鼠标 y 坐标
-- @return (number) y
function Input.get_mouse_y()
    return _mouse.y
end

-- 获取鼠标这一帧的移动量
-- @return (number, number) dx, dy
function Input.get_mouse_delta()
    return _mouse.dx, _mouse.dy
end

-- 检查鼠标按键是否刚按下
-- @param button (number) 按键编号 (1=左, 2=右, 3=中)
-- @return (boolean)
function Input.is_mouse_pressed(button)
    button = button or 1
    return _mouse.buttons.pressed[button] == true
end

-- 检查鼠标按键是否按住
-- @param button (number) 按键编号
-- @return (boolean)
function Input.is_mouse_held(button)
    button = button or 1
    return _mouse.buttons.held[button] == true
end

-- 检查鼠标按键是否刚松开
-- @param button (number) 按键编号
-- @return (boolean)
function Input.is_mouse_released(button)
    button = button or 1
    return _mouse.buttons.released[button] == true
end

-- ============================================================
-- 每帧更新 - 由引擎主循环调用
-- ============================================================

-- 每帧开始时调用，更新输入状态
-- 注意：必须在每帧开始时调用，pressed/released 只在一帧内有效
function Input.update(dt)
    -- 重置 pressed 和 released（只在一帧内有效）
    _pressed = {}
    _released = {}

    -- 更新动作状态
    for action, key in pairs(_bindings) do
        local is_down = _is_key_down(key)

        if is_down then
            if not _held[action] then
                -- 这一帧刚按下
                _pressed[action] = true
                -- 发布事件
                EventBus.emit("input:pressed", action)
            end
            _held[action] = true
        else
            if _held[action] then
                -- 这一帧刚松开
                _released[action] = true
                -- 发布事件
                EventBus.emit("input:released", action)
            end
            _held[action] = false
        end
    end

    -- 更新鼠标位置
    local new_x, new_y = love.mouse.getPosition()
    _mouse.dx = new_x - _mouse.x
    _mouse.dy = new_y - _mouse.y
    _mouse.x = new_x
    _mouse.y = new_y

    -- 重置鼠标按键的 pressed/released
    _mouse.buttons.pressed = {}
    _mouse.buttons.released = {}
end

-- ============================================================
-- LÖVE2D 回调处理 - 由 main.lua 调用
-- ============================================================

-- 键盘按下事件
-- 由 love.keypressed 调用
-- @param key (string) 键名
-- @param scancode (string) 扫描码
-- @param isrepeat (boolean) 是否是重复输入
function Input.keypressed(key, scancode, isrepeat)
    -- 注意：pressed 状态在 update 里根据 isDown 判断
    -- 这里可以做即时响应的事情（比如输入文字）
    -- 目前留空，有需要再加
    Logger.debugf("Input: key pressed: %s (repeat: %s)", key, tostring(isrepeat))
end

-- 键盘松开事件
-- @param key (string) 键名
-- @param scancode (string) 扫描码
function Input.keyreleased(key, scancode)
    Logger.debugf("Input: key released: %s", key)
end

-- 鼠标按下事件
-- @param x (number) x 坐标
-- @param y (number) y 坐标
-- @param button (number) 按键编号
-- @param isTouch (boolean) 是否触屏
function Input.mousepressed(x, y, button, isTouch)
    _mouse.buttons.pressed[button] = true
    _mouse.buttons.held[button] = true
    Logger.debugf("Input: mouse pressed: button=%d at (%d, %d)", button, x, y)
    EventBus.emit("input:mouse_pressed", button, x, y)
end

-- 鼠标松开事件
function Input.mousereleased(x, y, button, isTouch)
    _mouse.buttons.released[button] = true
    _mouse.buttons.held[button] = false
    Logger.debugf("Input: mouse released: button=%d at (%d, %d)", button, x, y)
    EventBus.emit("input:mouse_released", button, x, y)
end

-- 鼠标移动事件
-- @param x, y (number) 新位置
-- @param dx, dy (number) 移动量
-- @param isTouch (boolean) 是否触屏
function Input.mousemoved(x, y, dx, dy, isTouch)
    -- 大部分情况在 update 里更新位置就够了
    -- 这里可以做高频率鼠标跟踪（比如拖拽）
end

return Input
