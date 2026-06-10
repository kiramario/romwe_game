-- 模块名: render_layer
-- 功能: 渲染分层系统
-- 说明: 按固定层级顺序绘制，避免 z-index 混乱
-- 类比: Photoshop 图层 / CSS z-index 组 / Unity 的 Sorting Layer

local Logger = require("src.core.logger")

local RenderLayer = {}

-- ============================================================
-- 层级定义（从下到上）
-- 数字越小越先绘制（越靠下）
-- ============================================================

RenderLayer.LAYERS = {
    BACKGROUND = 0,   -- 背景、远景、视差层
    GAME = 1,         -- 游戏主体（棋盘、棋子、实体）
    EFFECTS = 2,      -- 特效、粒子、光影
    UI = 3,           -- 界面元素、HUD、按钮
    DEBUG = 4,        -- 调试信息、FPS、碰撞盒
}

-- 层级名称到数字的映射（用于按名字查找）
local _layer_order = {"BACKGROUND", "GAME", "EFFECTS", "UI", "DEBUG"}

-- ============================================================
-- 内部状态
-- ============================================================

-- 各层的绘制函数列表
-- 结构: { layer_num = { {id, func}, {id, func}, ... } }
local _layers = {}

-- 下一个绘制项的 ID
local _next_id = 1

-- 各层是否可见
local _layer_visible = {
    [0] = true,  -- BACKGROUND
    [1] = true,  -- GAME
    [2] = true,  -- EFFECTS
    [3] = true,  -- UI
    [4] = false, -- DEBUG 默认关闭
}

-- 每帧绘制计数（调试用）
local _draw_counts = {}

-- ============================================================
-- 内部函数
-- ============================================================

-- 获取层级编号（支持数字和字符串）
-- @param layer (number|string) 层级
-- @return (number) 层级编号
local function _get_layer_num(layer)
    if type(layer) == "number" then
        return layer
    elseif type(layer) == "string" then
        local upper = string.upper(layer)
        if RenderLayer.LAYERS[upper] ~= nil then
            return RenderLayer.LAYERS[upper]
        end
    end
    Logger.warnf("RenderLayer: unknown layer '%s', using GAME layer", tostring(layer))
    return RenderLayer.LAYERS.GAME
end

-- 确保某层的列表存在
local function _ensure_layer(layer_num)
    if not _layers[layer_num] then
        _layers[layer_num] = {}
    end
end

-- ============================================================
-- 公开 API - 添加/移除绘制项
-- ============================================================

-- 添加绘制函数到某层
-- @param layer (string|number) 层级名或编号
-- @param draw_func (function) 绘制函数
-- @return (number) 绘制项 ID，用于移除
function RenderLayer.add(layer, draw_func)
    if type(draw_func) ~= "function" then
        Logger.warn("RenderLayer.add: draw_func is not a function")
        return nil
    end

    local layer_num = _get_layer_num(layer)
    _ensure_layer(layer_num)

    local id = _next_id
    _next_id = _next_id + 1

    table.insert(_layers[layer_num], {
        id = id,
        func = draw_func,
    })

    Logger.debugf("RenderLayer: added item %d to layer %d", id, layer_num)
    return id
end

-- 移除某个绘制项
-- @param id (number) 绘制项 ID
-- @return (boolean) 是否成功移除
function RenderLayer.remove(id)
    for layer_num, items in pairs(_layers) do
        for i, item in ipairs(items) do
            if item.id == id then
                table.remove(items, i)
                Logger.debugf("RenderLayer: removed item %d from layer %d", id, layer_num)
                return true
            end
        end
    end
    Logger.debugf("RenderLayer: item %d not found", id)
    return false
end

-- 清空某层的所有绘制项
-- @param layer (string|number) 层级
function RenderLayer.clear(layer)
    local layer_num = _get_layer_num(layer)
    _layers[layer_num] = {}
    Logger.debugf("RenderLayer: cleared layer %d", layer_num)
end

-- 清空所有层的所有绘制项
function RenderLayer.clear_all()
    _layers = {}
    _next_id = 1
    Logger.debug("RenderLayer: cleared all layers")
end

-- ============================================================
-- 公开 API - 可见性控制
-- ============================================================

-- 设置某层是否可见
-- @param layer (string|number) 层级
-- @param visible (boolean) 是否可见
function RenderLayer.set_visible(layer, visible)
    local layer_num = _get_layer_num(layer)
    _layer_visible[layer_num] = visible
    Logger.debugf("RenderLayer: layer %d %s", layer_num, visible and "shown" or "hidden")
end

-- 检查某层是否可见
-- @param layer (string|number) 层级
-- @return (boolean) 是否可见
function RenderLayer.is_visible(layer)
    local layer_num = _get_layer_num(layer)
    return _layer_visible[layer_num] == true
end

-- 切换调试层显示状态
-- 按 F1 等快捷键时调用
function RenderLayer.toggle_debug()
    _layer_visible[RenderLayer.LAYERS.DEBUG] = not _layer_visible[RenderLayer.LAYERS.DEBUG]
    return _layer_visible[RenderLayer.LAYERS.DEBUG]
end

-- ============================================================
-- 公开 API - 绘制
-- ============================================================

-- 绘制所有层
-- 按层级顺序从下到上绘制
-- 由主循环的 love.draw 调用
function RenderLayer.draw()
    -- 重置绘制计数
    _draw_counts = {}

    -- 按层级顺序绘制
    for i, layer_name in ipairs(_layer_order) do
        local layer_num = RenderLayer.LAYERS[layer_name]

        -- 不可见的层跳过
        if not _layer_visible[layer_num] then
            goto continue
        end

        local items = _layers[layer_num]
        if items and #items > 0 then
            _draw_counts[layer_name] = #items

            -- 绘制该层的所有项
            -- 注意：按添加顺序绘制，先加的在下面（同层内）
            for _, item in ipairs(items) do
                -- 用 pcall 保护，防止一个绘制项出错导致整个画面黑屏
                local success, err = pcall(item.func)
                if not success then
                    Logger.errorf("RenderLayer: error drawing item %d on layer %s: %s",
                        item.id, layer_name, err)
                end
            end
        end

        ::continue::
    end
end

-- ============================================================
-- 公开 API - 调试信息
-- ============================================================

-- 获取绘制统计（每层绘制了多少项）
-- @return (table) 各层绘制数量
function RenderLayer.get_draw_counts()
    local result = {}
    for _, name in ipairs(_layer_order) do
        result[name] = _draw_counts[name] or 0
    end
    return result
end

-- 获取某层的绘制项数量
-- @param layer (string|number) 层级
-- @return (number) 绘制项数量
function RenderLayer.get_item_count(layer)
    local layer_num = _get_layer_num(layer)
    if not _layers[layer_num] then
        return 0
    end
    return #_layers[layer_num]
end

-- 获取总绘制项数量
-- @return (number) 总数
function RenderLayer.get_total_items()
    local total = 0
    for _, items in pairs(_layers) do
        total = total + #items
    end
    return total
end

return RenderLayer
