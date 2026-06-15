-- 模块名: logger
-- 功能: 分级日志系统
-- 说明: 替代直接 print，支持不同级别、格式化输出、调用栈信息
-- 类比: Python logging 模块 / JS 的 console.log/warn/error

local Utils = require("src.core.utils")

local Logger = {}

-- ============================================================
-- 日志级别定义
-- 数字越大，级别越高（越严重）
-- ============================================================

Logger.LEVELS = {
    TRACE = 10,  -- 最细粒度，跟踪执行流程
    DEBUG = 20,  -- 调试信息
    INFO = 30,   -- 一般信息
    WARN = 40,   -- 警告
    ERROR = 50,  -- 错误
    OFF = 100,   -- 关闭所有日志
}

-- 级别名称对应的颜色（ANSI 转义码）
-- 只在终端显示时有效
local LEVEL_COLORS = {
    TRACE = "\27[37m",   -- 灰色/白色
    DEBUG = "\27[36m",   -- 青色
    INFO = "\27[32m",    -- 绿色
    WARN = "\27[33m",    -- 黄色
    ERROR = "\27[31m",   -- 红色
}

-- 重置颜色
local RESET_COLOR = "\27[0m"

-- ============================================================
-- 内部状态
-- ============================================================

local _level = Logger.LEVELS.DEBUG  -- 当前日志级别
local _show_timestamp = true        -- 是否显示时间戳
local _show_level = true            -- 是否显示级别
local _use_color = true             -- 是否使用颜色（终端中用）

-- ============================================================
-- 内部工具函数
-- ============================================================

-- 获取当前时间戳字符串
-- @return (string) 格式化的时间
local function _get_timestamp()
    -- os.date 格式化时间，类比 Python 的 strftime
    return os.date("%Y-%m-%d %H:%M:%S")
end

-- 获取调用者信息（文件名和行号）
-- 用 debug 库获取调用栈
-- 类比: JS 的 console.trace / Python 的 traceback
-- @param level (number) 往上找几层（1=直接调用者）
-- @return (string) "文件名:行号"
local function _get_caller_info(level)
    -- debug.getinfo 获取调用栈信息
    -- level=2 表示 logger 函数的调用者
    -- level=3 表示调用者的调用者（用于内部调用时）
    level = level or 2
    local info = debug.getinfo(level, "Sl")
    if info then
        -- info.short_src = 文件名
        -- info.currentline = 当前行号
        return string.format("%s:%d", info.short_src, info.currentline)
    end
    return "unknown"
end

-- 格式化日志消息
-- @param level_name (string) 级别名称
-- @param message (string) 日志消息
-- @param caller_level (number) 调用者层级
-- @return (string) 格式化后的完整日志
local function _format_message(level_name, message, caller_level)
    local parts = {}

    if _show_timestamp then
        table.insert(parts, _get_timestamp())
    end

    if _show_level then
        local level_str = string.format("[%s]", string.upper(level_name))
        if _use_color and LEVEL_COLORS[level_name] then
            level_str = LEVEL_COLORS[level_name] .. level_str .. RESET_COLOR
        end
        table.insert(parts, level_str)
    end

    -- 调用者信息
    table.insert(parts, _get_caller_info(caller_level or 3))

    table.insert(parts, tostring(message))

    -- 用 table.concat 拼接，避免循环用 .. 产生大量临时字符串
    -- 类比: JS 的 array.join()
    return table.concat(parts, " ")
end

-- ============================================================
-- 日志输出核心函数
-- ============================================================

-- 输出一条日志
-- @param level (number) 日志级别
-- @param level_name (string) 级别名称
-- @param message (string) 日志消息
-- @param caller_level (number) 调用者层级（用于正确显示调用位置）
local function _log(level, level_name, message, caller_level)
    -- 如果当前级别高于设置的级别，就不输出
    if level < _level then
        return
    end

    local formatted = _format_message(level_name, message, caller_level or 4)

    -- 用 print 输出到控制台
    -- LÖVE2D 的 print 会同时输出到终端和游戏内控制台
    print(formatted)

    -- 如果是 ERROR 级别，额外输出调用栈
    if level >= Logger.LEVELS.ERROR then
        local traceback = debug.traceback("", 3)
        if traceback and traceback ~= "" then
            print("Stack trace:" .. traceback)
        end
    end
end

-- ============================================================
-- 公开的日志函数
-- ============================================================

-- 输出 trace 级别日志（最细粒度）
-- @param message (string) 日志消息
function Logger.trace(message)
    _log(Logger.LEVELS.TRACE, "TRACE", message, 3)
end

-- 输出 debug 级别日志
-- @param message (string) 日志消息
function Logger.debug(message)
    _log(Logger.LEVELS.DEBUG, "DEBUG", message, 3)
end

-- 输出 info 级别日志
-- @param message (string) 日志消息
function Logger.info(message)
    _log(Logger.LEVELS.INFO, "INFO", message, 3)
end

-- 输出 warn 级别日志（警告）
-- @param message (string) 日志消息
function Logger.warn(message)
    _log(Logger.LEVELS.WARN, "WARN", message, 3)
end

-- 输出 error 级别日志（错误，带调用栈）
-- @param message (string) 日志消息
function Logger.error(message)
    _log(Logger.LEVELS.ERROR, "ERROR", message, 3)
end

-- 格式化输出（类似 printf / string.format）
-- 用法: Logger.debugf("Player %s has %d health", name, hp)
-- @param format (string) 格式化字符串
-- @param ... 可变参数
function Logger.debugf(format, ...)
    if Logger.LEVELS.DEBUG >= _level then
        -- string.format 类比 Python 的 % 格式化或 JS 的模板字符串
        local msg = string.format(format, ...)
        _log(Logger.LEVELS.DEBUG, "DEBUG", msg, 3)
    end
end

function Logger.infof(format, ...)
    if Logger.LEVELS.INFO >= _level then
        local msg = string.format(format, ...)
        _log(Logger.LEVELS.INFO, "INFO", msg, 3)
    end
end

function Logger.warnf(format, ...)
    if Logger.LEVELS.WARN >= _level then
        local msg = string.format(format, ...)
        _log(Logger.LEVELS.WARN, "WARN", msg, 3)
    end
end

function Logger.errorf(format, ...)
    if Logger.LEVELS.ERROR >= _level then
        local msg = string.format(format, ...)
        _log(Logger.LEVELS.ERROR, "ERROR", msg, 3)
    end
end

-- ============================================================
-- 配置函数
-- ============================================================

-- 设置日志级别
-- @param level (number|string) 级别，比如 Logger.LEVELS.INFO 或 "info"
function Logger.set_level(level)
    if type(level) == "string" then
        -- 字符串转级别常量
        local upper = string.upper(level)
        if Logger.LEVELS[upper] then
            _level = Logger.LEVELS[upper]
        else
            Logger.warn("Unknown log level: " .. level)
        end
    elseif type(level) == "number" then
        _level = level
    end
end

-- 获取当前日志级别
-- @return (number) 当前级别
function Logger.get_level()
    return _level
end

-- 设置是否显示时间戳
function Logger.set_show_timestamp(show)
    _show_timestamp = show
end

-- 设置是否显示级别
function Logger.set_show_level(show)
    _show_level = show
end

-- 设置是否使用颜色
function Logger.set_use_color(use)
    _use_color = use
end

-- 断言：如果条件不满足，输出 error 日志
-- 类比: Python 的 assert 语句
-- @param condition (boolean) 条件
-- @param message (string) 断言失败时的消息
function Logger.assert(condition, message)
    if not condition then
        Logger.error("Assertion failed: " .. (message or "unknown"))
    end
    return condition
end

return Logger
