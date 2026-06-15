-- 模块名: config
-- 功能: 配置管理系统
-- 说明: 管理游戏配置，有默认值，支持持久化到文件
-- 类比: Java 的 properties / Python 的 configparser / JS 的 config 对象

local Utils = require("src.core.utils")
local Logger = require("src.core.logger")

local Config = {}

-- ============================================================
-- 默认配置
-- 所有配置项都必须在这里有默认值
-- 读取失败时回退到默认值
-- ============================================================

local DEFAULT_CONFIG = {
    -- 窗口设置
    window = {
        width = 1280,
        height = 720,
        fullscreen = false,
        vsync = true,
        resizable = true,
    },

    -- 音频设置
    audio = {
        master_volume = 1.0,
        music_volume = 0.8,
        sfx_volume = 1.0,
        muted = false,
    },

    -- 游戏设置
    game = {
        difficulty = "normal",  -- easy, normal, hard
        ai_think_time = 0.5,    -- AI 思考时间（秒）
    },

    -- 输入设置
    input = {
        -- 键位映射：动作名 -> 按键
        -- 类比: Unity Input Manager
        bindings = {
            confirm = "return",   -- 回车确认
            cancel = "escape",    -- ESC 取消
            pause = "p",          -- P 暂停
            debug = "f1",         -- F1 调试
            screenshot = "f12",   -- F12 截图
        },
    },

    -- 调试设置
    debug = {
        show_fps = true,
        show_debug_layer = false,
        log_level = "debug",
    },
}

-- ============================================================
-- 内部状态
-- ============================================================

local _config = {}  -- 当前配置（默认值 + 用户配置合并）
local _dirty = false  -- 是否有未保存的变更

-- 配置文件名（在 save directory 中）
-- LÖVE2D 的 save directory 是系统指定的，游戏只能读写这个目录
-- 类比: 浏览器的 localStorage / 手机的沙盒目录
local CONFIG_FILENAME = "config.lua"

-- ============================================================
-- 内部函数
-- ============================================================

-- 深度合并默认配置和用户配置
-- 用户配置覆盖默认配置，但不破坏默认配置的结构
-- @param defaults (table) 默认配置
-- @param user (table) 用户配置
-- @return (table) 合并后的配置
local function _merge_config(defaults, user)
    if type(user) ~= "table" then
        return Utils.deep_copy(defaults)
    end

    local result = {}
    for key, default_val in pairs(defaults) do
        if type(default_val) == "table" and type(user[key]) == "table" then
            -- 都是 table，递归合并
            result[key] = _merge_config(default_val, user[key])
        elseif user[key] ~= nil then
            -- 用户有值，用用户的
            result[key] = user[key]
        else
            -- 用户没有，用默认的（深拷贝）
            result[key] = Utils.deep_copy(default_val)
        end
    end
    return result
end

-- 通过点号分隔的键名获取嵌套值
-- 比如 Config.get("window.width")
-- 类比: lodash 的 _.get(obj, 'a.b.c')
-- @param key (string) 点号分隔的键路径
-- @return (any) 值，找不到返回 nil
local function _get_by_path(key)
    -- 分割键路径
    local parts = Utils.string_split(key, ".")
    local current = _config

    for _, part in ipairs(parts) do
        if type(current) ~= "table" or current[part] == nil then
            return nil
        end
        current = current[part]
    end

    return current
end

-- 通过点号分隔的键名设置嵌套值
-- @param key (string) 点号分隔的键路径
-- @param value (any) 要设置的值
local function _set_by_path(key, value)
    local parts = Utils.string_split(key, ".")
    local current = _config

    -- 找到父节点
    for i = 1, #parts - 1 do
        local part = parts[i]
        if type(current[part]) ~= "table" then
            -- 如果中间不存在，创建空 table
            current[part] = {}
        end
        current = current[part]
    end

    -- 设置值
    local last_key = parts[#parts]
    current[last_key] = value
    _dirty = true
end

-- ============================================================
-- 公开 API
-- ============================================================

-- 初始化配置系统
-- 加载保存的配置，和默认配置合并
function Config.init()
    Logger.debug("Config: initializing...")

    -- 先加载保存的配置
    local saved_config = Config.load(CONFIG_FILENAME)

    -- 合并默认配置和保存的配置
    _config = _merge_config(DEFAULT_CONFIG, saved_config)

    -- 应用日志级别
    Logger.set_level(_config.debug.log_level)

    _dirty = false
    Logger.info("Config: initialized")
end

-- 获取配置值
-- 支持点号路径：Config.get("window.width")
-- @param key (string) 配置键
-- @param default (any) 默认值（如果配置不存在）
-- @return (any) 配置值
function Config.get(key, default)
    local value = _get_by_path(key)
    if value == nil then
        return default
    end
    return value
end

-- 设置配置值
-- 支持点号路径：Config.set("window.width", 1920)
-- 设置后需要手动调用 save() 才会持久化
-- @param key (string) 配置键
-- @param value (any) 配置值
function Config.set(key, value)
    Logger.debugf("Config: set %s = %s", key, tostring(value))
    _set_by_path(key, value)

    -- 如果是日志级别变了，立即生效
    if key == "debug.log_level" then
        Logger.set_level(value)
    end
end

-- 重置为默认配置
function Config.reset()
    Logger.debug("Config: resetting to defaults")
    _config = Utils.deep_copy(DEFAULT_CONFIG)
    _dirty = true
end

-- 从文件加载配置
-- @param filename (string) 文件名（相对于 save directory）
-- @return (table) 加载的配置 table，失败返回空 table
function Config.load(filename)
    filename = filename or CONFIG_FILENAME

    -- 检查文件是否存在
    if not love.filesystem.getInfo(filename) then
        Logger.debugf("Config: file %s not found, using defaults", filename)
        return {}
    end

    -- 读取文件内容
    local content, error = love.filesystem.read(filename)
    if not content then
        Logger.warnf("Config: failed to read %s: %s", filename, error)
        return {}
    end

    -- 用 load 函数执行 Lua 代码获取配置
    -- 类比: Python 的 exec / JS 的 eval（但 Lua 的 load 更安全）
    local chunk, err = loadstring(content)
    if not chunk then
        Logger.warnf("Config: failed to parse %s: %s", filename, err)
        return {}
    end

    -- 执行代码，获取返回值
    -- 用 pcall 保护，防止配置文件有语法错误导致崩溃
    -- 类比: try-catch
    local success, result = pcall(chunk)
    if not success or type(result) ~= "table" then
        Logger.warnf("Config: invalid config in %s", filename)
        return {}
    end

    Logger.debugf("Config: loaded from %s", filename)
    return result
end

-- 保存配置到文件
-- @param filename (string) 文件名（相对于 save directory）
-- @return (boolean) 是否成功
function Config.save(filename)
    filename = filename or CONFIG_FILENAME

    if not _dirty then
        Logger.debug("Config: no changes to save")
        return true
    end

    -- 把 table 序列化为 Lua 代码字符串
    -- 类比: JSON.stringify，但序列化的是 Lua 代码
    local content = Config.serialize(_config)

    -- 写入文件
    local success, error = love.filesystem.write(filename, content)
    if not success then
        Logger.errorf("Config: failed to save %s: %s", filename, error)
        return false
    end

    _dirty = false
    Logger.infof("Config: saved to %s", filename)
    return true
end

-- 把 table 序列化为 Lua 代码字符串
-- 生成的字符串可以用 loadstring 执行后得到原 table
-- @param tbl (table) 要序列化的表
-- @param indent (number) 缩进层级（内部用）
-- @return (string) Lua 代码字符串
function Config.serialize(tbl, indent)
    indent = indent or 0
    local indent_str = string.rep("    ", indent)  -- 4个空格缩进
    local next_indent = indent + 1
    local next_indent_str = string.rep("    ", next_indent)

    if type(tbl) ~= "table" then
        -- 非 table 类型直接返回
        if type(tbl) == "string" then
            -- 字符串加引号
            return string.format("%q", tbl)
        else
            return tostring(tbl)
        end
    end

    -- 判断是数组还是对象（简单判断：是否有 1 作为键）
    -- 注意: 这是简化判断，不完全准确但对配置文件够用
    local is_array = #tbl > 0 and tbl[1] ~= nil

    local parts = {}
    table.insert(parts, "{")

    if is_array then
        -- 数组格式
        for i, v in ipairs(tbl) do
            local val_str = Config.serialize(v, next_indent)
            table.insert(parts, next_indent_str .. val_str .. ",")
        end
    else
        -- 对象格式
        for k, v in pairs(tbl) do
            local val_str = Config.serialize(v, next_indent)
            -- 键名如果是合法标识符就不用加引号
            if type(k) == "string" and string.match(k, "^[%a_][%w_]*$") then
                table.insert(parts, next_indent_str .. k .. " = " .. val_str .. ",")
            else
                table.insert(parts, next_indent_str .. "[" .. string.format("%q", k) .. "] = " .. val_str .. ",")
            end
        end
    end

    table.insert(parts, indent_str .. "}")
    return table.concat(parts, "\n")
end

-- 检查是否有未保存的变更
-- @return (boolean) 是否有变更
function Config.is_dirty()
    return _dirty
end

-- 获取整个配置表（只读，不要直接修改）
-- @return (table) 配置表的浅拷贝
function Config.get_all()
    return Utils.shallow_copy(_config)
end

return Config
