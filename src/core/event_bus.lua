-- 模块名: event_bus
-- 功能: 事件总线（发布/订阅模式）
-- 说明: 模块间解耦通信，各模块通过事件通信，不直接引用
-- 类比: Node.js 的 EventEmitter / RxJS Subject / 观察者模式

local Logger = require("src.core.logger")
local Utils = require("src.core.utils")

local EventBus = {}

-- ============================================================
-- 内部状态
-- ============================================================

-- 事件订阅表
-- 结构: { event_name = { handler1, handler2, ... } }
-- 类比: Map<string, Array<Function>>
local _listeners = {}

-- 是否启用（可以全局关闭事件）
local _enabled = true

-- 事件统计（调试用）
local _stats = {
    emits = 0,     -- 总共发布了多少次事件
    handlers = 0,  -- 当前订阅数
}

-- ============================================================
-- 内部函数
-- ============================================================

-- 确保某个事件有监听器列表
-- @param event_name (string) 事件名
local function _ensure_listeners(event_name)
    if not _listeners[event_name] then
        _listeners[event_name] = {}
    end
end

-- ============================================================
-- 公开 API
-- ============================================================

-- 订阅事件
-- 多次订阅同一个事件，每次都会调用
-- 类比: addEventListener / EventEmitter.on
-- @param event_name (string) 事件名（建议用 "类别:动作" 格式，如 "piece:moved"）
-- @param handler (function) 事件处理函数，参数是事件携带的数据
function EventBus.on(event_name, handler)
    if type(handler) ~= "function" then
        Logger.warnf("EventBus.on: handler for '%s' is not a function", event_name)
        return
    end

    _ensure_listeners(event_name)
    table.insert(_listeners[event_name], handler)
    _stats.handlers = _stats.handlers + 1

    Logger.debugf("EventBus: subscribed to '%s'", event_name)
end

-- 只订阅一次，触发后自动取消
-- 类比: EventEmitter.once
-- @param event_name (string) 事件名
-- @param handler (function) 事件处理函数
function EventBus.once(event_name, handler)
    -- 注意：这里用 local function 语法糖，避免闭包自引用问题
    -- （见 docs/05_code_style.md 中的 Lua 特有规范）
    local once_handler
    once_handler = function(...)
        -- 先取消订阅，再执行处理函数
        EventBus.off(event_name, once_handler)
        handler(...)
    end

    EventBus.on(event_name, once_handler)
end

-- 取消订阅
-- 需要传入和 on 时相同的函数引用
-- 类比: removeEventListener
-- @param event_name (string) 事件名
-- @param handler (function) 要取消的处理函数
-- @return (boolean) 是否成功取消
function EventBus.off(event_name, handler)
    if not _listeners[event_name] then
        return false
    end

    -- 遍历找到并移除
    for i, h in ipairs(_listeners[event_name]) do
        if h == handler then
            table.remove(_listeners[event_name], i)
            _stats.handlers = _stats.handlers - 1
            Logger.debugf("EventBus: unsubscribed from '%s'", event_name)
            return true
        end
    end

    return false
end

-- 发布事件
-- 所有订阅者按订阅顺序依次执行
-- 注意：V0 是同步发布，即 emit 时立即执行所有 handler
-- 类比: 同步触发事件
-- @param event_name (string) 事件名
-- @param ... 可变参数，会传给所有 handler
function EventBus.emit(event_name, ...)
    if not _enabled then
        return
    end

    if not _listeners[event_name] or #_listeners[event_name] == 0 then
        -- 没有监听器，直接返回
        return
    end

    _stats.emits = _stats.emits + 1

    Logger.debugf("EventBus: emitting '%s'", event_name)

    -- 遍历所有 handler 并调用
    -- 注意：这里用一个临时表来遍历，防止 handler 内部 off 导致的问题
    -- 类比: JS 中遍历数组时删除元素的坑
    local handlers = {}
    for i, h in ipairs(_listeners[event_name]) do
        handlers[i] = h
    end

    for _, h in ipairs(handlers) do
        -- 用 pcall 保护，防止一个 handler 出错导致后面的都不执行
        -- 类比: try-catch 每个 listener
        local success, err = pcall(h, ...)
        if not success then
            Logger.errorf("EventBus: error in handler for '%s': %s", event_name, err)
        end
    end
end

-- 清除某个事件的所有订阅
-- @param event_name (string) 事件名
function EventBus.clear(event_name)
    if _listeners[event_name] then
        local count = #_listeners[event_name]
        _listeners[event_name] = nil
        _stats.handlers = _stats.handlers - count
        Logger.debugf("EventBus: cleared all handlers for '%s'", event_name)
    end
end

-- 清除所有事件的所有订阅
function EventBus.clear_all()
    _listeners = {}
    _stats.handlers = 0
    Logger.debug("EventBus: cleared all handlers")
end

-- 启用/禁用事件总线
-- @param enabled (boolean) 是否启用
function EventBus.set_enabled(enabled)
    _enabled = enabled
    Logger.debugf("EventBus: %s", enabled and "enabled" or "disabled")
end

-- 检查事件总线是否启用
-- @return (boolean) 是否启用
function EventBus.is_enabled()
    return _enabled
end

-- 检查某个事件是否有订阅者
-- @param event_name (string) 事件名
-- @return (boolean) 是否有订阅者
function EventBus.has_listeners(event_name)
    return _listeners[event_name] ~= nil and #_listeners[event_name] > 0
end

-- 获取统计信息（调试用）
-- @return (table) { emits, handlers }
function EventBus.get_stats()
    return {
        emits = _stats.emits,
        handlers = _stats.handlers,
        event_count = Utils and Utils.table_length(_listeners) or "unknown",
    }
end

-- 获取所有事件名（调试用）
-- @return (table) 事件名数组
function EventBus.get_event_names()
    local names = {}
    for name, _ in pairs(_listeners) do
        table.insert(names, name)
    end
    return names
end

return EventBus
