-- 模块名: utils
-- 功能: 通用工具函数集合
-- 说明: 纯函数，无副作用。所有模块都可以调用。
-- 类比: lodash (JS) / Python stdlib 工具函数

local Utils = {}

-- ============================================================
-- 数学工具
-- ============================================================

-- 把值限制在 [min, max] 范围内
-- 类比: Math.clamp (JS) / numpy.clip
-- @param value (number) 要限制的值
-- @param min (number) 最小值
-- @param max (number) 最大值
-- @return (number) 限制后的值
function Utils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- 线性插值
-- 类比: lerp 函数
-- @param a (number) 起始值
-- @param b (number) 结束值
-- @param t (number) 插值因子 (0-1)
-- @return (number) 插值结果
function Utils.lerp(a, b, t)
    return a + (b - a) * t
end

-- 计算两点之间的距离
-- @param x1, y1 (number) 点1坐标
-- @param x2, y2 (number) 点2坐标
-- @return (number) 距离
function Utils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- 随机浮点数 [min, max)
-- 封装 love.math.random，比 math.random 随机性更好
-- @param min (number) 最小值
-- @param max (number) 最大值
-- @return (number) 随机数
function Utils.random(min, max)
    if max == nil then
        -- 只传一个参数时，返回 [0, min)
        return love.math.random() * min
    end
    return min + love.math.random() * (max - min)
end

-- 随机整数 [min, max]
-- @param min (number) 最小值
-- @param max (number) 最大值
-- @return (number) 随机整数
function Utils.random_int(min, max)
    return love.math.random(min, max)
end

-- ============================================================
-- 表 (Table) 工具
-- 注意: Lua 的 table 既是数组也是对象（哈希表）
-- 类比: JS 的 Array + Object 合二为一
-- ============================================================

-- 浅拷贝一个表
-- 类比: Object.assign({}, obj) (JS) / dict.copy() (Python)
-- @param tbl (table) 原表
-- @return (table) 新表
function Utils.shallow_copy(tbl)
    local copy = {}
    -- pairs 遍历所有键值对，不保证顺序
    -- 类比: JS 的 for...in
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

-- 深拷贝一个表（递归）
-- 注意: 不处理循环引用，遇到会无限递归
-- @param tbl (table) 原表
-- @return (table) 新表
function Utils.deep_copy(tbl)
    if type(tbl) ~= "table" then
        return tbl
    end
    local copy = {}
    for k, v in pairs(tbl) do
        -- 递归拷贝值
        copy[k] = Utils.deep_copy(v)
    end
    -- 保留元表（metatable）—— 类比原型链
    local mt = getmetatable(tbl)
    if mt then
        setmetatable(copy, mt)
    end
    return copy
end

-- 合并两个表，后者覆盖前者
-- 类比: Object.assign (JS) / {**dict1, **dict2} (Python)
-- @param tbl1 (table) 基础表
-- @param tbl2 (table) 覆盖表
-- @return (table) 合并后的新表
function Utils.table_merge(tbl1, tbl2)
    local result = Utils.shallow_copy(tbl1)
    for k, v in pairs(tbl2) do
        result[k] = v
    end
    return result
end

-- 计算表中键的数量（包括非数字键）
-- 注意: # 运算符只计算数组部分（连续整数索引从1开始）
-- 类比: Object.keys(obj).length (JS)
-- @param tbl (table) 表
-- @return (number) 键的总数
function Utils.table_length(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

-- 检查表中是否包含某个值
-- @param tbl (table) 表
-- @param value (any) 要查找的值
-- @return (boolean) 是否包含
function Utils.table_contains(tbl, value)
    for _, v in pairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- ============================================================
-- 字符串工具
-- ============================================================

-- 判断字符串是否以某个前缀开头
-- 类比: str.startsWith(prefix) (JS) / str.startswith(prefix) (Python)
-- @param str (string) 字符串
-- @param prefix (string) 前缀
-- @return (boolean) 是否匹配
function Utils.string_starts_with(str, prefix)
    return string.sub(str, 1, string.len(prefix)) == prefix
end

-- 判断字符串是否以某个后缀结尾
-- @param str (string) 字符串
-- @param suffix (string) 后缀
-- @return (boolean) 是否匹配
function Utils.string_ends_with(str, suffix)
    return string.sub(str, -string.len(suffix)) == suffix
end

-- 分割字符串
-- 类比: str.split(delimiter) (JS/Python)
-- @param str (string) 字符串
-- @param delimiter (string) 分隔符
-- @return (table) 分割后的数组
function Utils.string_split(str, delimiter)
    delimiter = delimiter or ","
    local result = {}
    local pattern = string.format("([^%s]+)", delimiter)
    -- string.gmatch 返回一个迭代器
    -- 类比: JS 的 matchAll 或 generator
    for match in string.gmatch(str, pattern) do
        table.insert(result, match)
    end
    return result
end

-- ============================================================
-- 颜色常量
-- 颜色格式: {r, g, b, a}，值范围 0-1
-- LÖVE2D 用 0-1 而不是 0-255
-- ============================================================

Utils.Colors = {
    WHITE = {1, 1, 1, 1},
    BLACK = {0, 0, 0, 1},
    RED = {1, 0, 0, 1},
    GREEN = {0, 1, 0, 1},
    BLUE = {0, 0, 1, 1},
    YELLOW = {1, 1, 0, 1},
    CYAN = {0, 1, 1, 1},
    MAGENTA = {1, 0, 1, 1},
    GRAY = {0.5, 0.5, 0.5, 1},
    DARK_GRAY = {0.3, 0.3, 0.3, 1},
    LIGHT_GRAY = {0.8, 0.8, 0.8, 1},
    TRANSPARENT = {0, 0, 0, 0},
}

-- 从 0-255 的 RGB 创建颜色（转为 0-1）
-- 类比: CSS 的 rgb() 函数
-- @param r, g, b (number) 0-255 的颜色值
-- @param a (number) 0-255 的 alpha，默认 255
-- @return (table) {r, g, b, a} 格式（0-1）
function Utils.rgb(r, g, b, a)
    a = a or 255
    return {r / 255, g / 255, b / 255, a / 255}
end

-- ============================================================
-- 类型检查
-- ============================================================

-- 判断值是否为 nil
-- 注意: 在 Lua 中 0, "", {} 都是 truthy，只有 nil 和 false 是 falsy
-- 类比: 但和 JS/Python 很不一样，要特别注意！
-- @param value (any) 值
-- @return (boolean) 是否为 nil
function Utils.is_nil(value)
    return value == nil
end

-- 判断值是否为 table
function Utils.is_table(value)
    return type(value) == "table"
end

-- 判断值是否为函数
function Utils.is_function(value)
    return type(value) == "function"
end

-- 判断值是否为数字
function Utils.is_number(value)
    return type(value) == "number"
end

-- 判断值是否为字符串
function Utils.is_string(value)
    return type(value) == "string"
end

return Utils
