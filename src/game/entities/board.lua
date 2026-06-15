-- 模块名: board
-- 功能: 棋盘实体
-- 说明: 中国象棋棋盘，负责渲染棋盘和坐标转换
-- 棋盘坐标: x: 1-9 (列，从左到右), y: 1-10 (行，从上到下)
-- 注意: 棋子放在交叉点上，不是格子里（和国际象棋不同）
-- 类比: 游戏中的地图/关卡实体

local Core = require("src.core")
local Logger = Core.Logger
local ResourceManager = Core.ResourceManager
local Utils = Core.Utils

local Board = {}
Board.__index = Board

-- ============================================================
-- 棋盘常量
-- ============================================================

Board.COLS = 9    -- 列数（9 条竖线）
Board.ROWS = 10   -- 行数（10 条横线）

-- 九宫格范围
Board.FORTRESS = {
    -- 黑方九宫（上方）
    black = { min_x = 4, max_x = 6, min_y = 1, max_y = 3 },
    -- 红方九宫（下方）
    red = { min_x = 4, max_x = 6, min_y = 8, max_y = 10 },
}

-- 楚河汉界位置（在 y=5 和 y=6 之间）
Board.RIVER_Y_TOP = 5     -- 河界上方
Board.RIVER_Y_BOTTOM = 6  -- 河界下方

-- ============================================================
-- 构造函数
-- ============================================================

-- 创建棋盘
-- @param options (table) 配置
--   - x, y: 棋盘左上角屏幕坐标
--   - cell_size: 格子大小（像素）
--   - padding: 边距
-- @return (Board) 棋盘实例
function Board.new(options)
    local self = setmetatable({}, Board)

    options = options or {}

    -- 棋盘位置（左上角）
    self.x = options.x or 100
    self.y = options.y or 50

    -- 格子大小（相邻交叉点之间的距离）
    self.cell_size = options.cell_size or 60

    -- 边距（棋盘边缘到最外侧线条的距离）
    self.padding = options.padding or 30

    -- 棋盘尺寸
    self.width = (Board.COLS - 1) * self.cell_size + self.padding * 2
    self.height = (Board.ROWS - 1) * self.cell_size + self.padding * 2

    -- 棋盘颜色
    self.colors = options.colors or {
        background = {0.82, 0.71, 0.55, 1},    -- 木色背景
        line = {0.2, 0.15, 0.1, 1},           -- 深色线条
        river_text = {0.3, 0.25, 0.2, 0.7},   -- 楚河汉界文字
        highlight = {1, 0.8, 0.2, 0.5},       -- 高亮（选中的位置）
        move_hint = {0.2, 0.8, 0.3, 0.6},     -- 可走位置提示
    }

    -- 选中的位置
    self.selected_x = nil
    self.selected_y = nil

    -- 可走位置列表（V2 才用，V1 留空）
    self.move_hints = {}

    Logger.debugf("Board: created (%.0f x %.0f, cell=%d)",
        self.width, self.height, self.cell_size)

    return self
end

-- ============================================================
-- 坐标转换
-- ============================================================

-- 棋盘坐标转屏幕坐标（交叉点中心）
-- @param bx, by (number) 棋盘坐标 (1-9, 1-10)
-- @return (number, number) 屏幕坐标
function Board:board_to_screen(bx, by)
    local sx = self.x + self.padding + (bx - 1) * self.cell_size
    local sy = self.y + self.padding + (by - 1) * self.cell_size
    return sx, sy
end

-- 屏幕坐标转棋盘坐标
-- 找到最近的交叉点
-- @param sx, sy (number) 屏幕坐标
-- @return (number, number|nil, nil) 棋盘坐标，如果超出范围返回 nil
function Board:screen_to_board(sx, sy)
    -- 计算相对于棋盘左上角的位置
    local rel_x = sx - self.x - self.padding
    local rel_y = sy - self.y - self.padding

    -- 四舍五入到最近的交叉点
    local bx = math.floor(rel_x / self.cell_size + 0.5) + 1
    local by = math.floor(rel_y / self.cell_size + 0.5) + 1

    -- 检查是否在范围内
    if bx < 1 or bx > Board.COLS or by < 1 or by > Board.ROWS then
        return nil
    end

    -- 检查点击是否离交叉点太远（超过半个格子）
    local expected_x = (bx - 1) * self.cell_size
    local expected_y = (by - 1) * self.cell_size
    local dist = math.abs(rel_x - expected_x) + math.abs(rel_y - expected_y)

    if dist > self.cell_size * 0.6 then
        return nil
    end

    return bx, by
end

-- 检查点是否在棋盘内
-- @param bx, by (number) 棋盘坐标
-- @return (boolean)
function Board:is_valid_position(bx, by)
    return bx >= 1 and bx <= Board.COLS and by >= 1 and by <= Board.ROWS
end

-- 检查是否在九宫内
-- @param bx, by (number) 棋盘坐标
-- @param side (string) "red" 或 "black"
-- @return (boolean)
function Board:is_in_fortress(bx, by, side)
    local f = Board.FORTRESS[side]
    if not f then return false end
    return bx >= f.min_x and bx <= f.max_x and
           by >= f.min_y and by <= f.max_y
end

-- 检查是否过河
-- @param by (number) y 坐标
-- @param side (string) "red" 或 "black"
-- @return (boolean)
function Board:has_crossed_river(by, side)
    if side == "red" then
        -- 红方的棋子往上走，y < 6 表示过河了
        return by <= Board.RIVER_Y_TOP
    else
        -- 黑方的棋子往下走，y > 5 表示过河了
        return by >= Board.RIVER_Y_BOTTOM
    end
end

-- ============================================================
-- 设置选中位置
-- ============================================================

function Board:set_selected(bx, by)
    self.selected_x = bx
    self.selected_y = by
end

function Board:clear_selected()
    self.selected_x = nil
    self.selected_y = nil
end

-- 设置可走位置提示
-- @param hints (table) { {x, y}, ... }
function Board:set_move_hints(hints)
    self.move_hints = hints or {}
end

-- ============================================================
-- 设置棋盘大小和位置（窗口大小改变时调用）
-- ============================================================

-- 自动调整棋盘大小以适应给定区域
-- @param max_width, max_height (number) 最大可用区域
-- @param center_x, center_y (number) 居中位置
function Board:fit_into(max_width, max_height, center_x, center_y)
    -- 计算合适的格子大小
    local cell_w = (max_width - self.padding * 2) / (Board.COLS - 1)
    local cell_h = (max_height - self.padding * 2) / (Board.ROWS - 1)

    self.cell_size = math.floor(math.min(cell_w, cell_h))

    -- 重新计算尺寸
    self.width = (Board.COLS - 1) * self.cell_size + self.padding * 2
    self.height = (Board.ROWS - 1) * self.cell_size + self.padding * 2

    -- 居中
    self.x = center_x - self.width / 2
    self.y = center_y - self.height / 2

    Logger.debugf("Board: fit into %dx%d, cell=%d",
        max_width, max_height, self.cell_size)
end

-- ============================================================
-- 更新
-- ============================================================

function Board:update(dt)
    -- V1 棋盘没有动画，暂时空着
    -- 后续版本可以加棋盘晃动、闪烁等效果
end

-- ============================================================
-- 绘制
-- ============================================================

function Board:draw()
    -- 1. 绘制背景
    self:draw_background()

    -- 2. 绘制棋盘线条
    self:draw_lines()

    -- 3. 绘制楚河汉界
    self:draw_river()

    -- 4. 绘制九宫格斜线
    self:draw_fortress()

    -- 5. 绘制位置标记（炮位、兵位的小十字）
    self:draw_position_marks()

    -- 6. 绘制选中高亮
    if self.selected_x and self.selected_y then
        self:draw_highlight(self.selected_x, self.selected_y, self.colors.highlight)
    end

    -- 7. 绘制可走位置提示
    for _, hint in ipairs(self.move_hints) do
        self:draw_move_hint(hint.x, hint.y)
    end
end

-- 绘制背景
function Board:draw_background()
    -- 木色背景板
    love.graphics.setColor(self.colors.background)

    -- 圆角矩形（模拟木质棋盘）
    local corner = 10
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, corner, corner)

    -- 边框
    love.graphics.setColor(self.colors.line)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, corner, corner)
    love.graphics.setLineWidth(1)
end

-- 绘制棋盘线条
function Board:draw_lines()
    love.graphics.setColor(self.colors.line)
    love.graphics.setLineWidth(1)

    -- 竖线（9 条）
    -- 注意：楚河汉界处不画竖线（河上没有线）
    for col = 1, Board.COLS do
        local x = self.x + self.padding + (col - 1) * self.cell_size

        if col == 1 or col == Board.COLS then
            -- 最左和最右边的线是完整的（边框线）
            local y_top = self.y + self.padding
            local y_bottom = self.y + self.padding + (Board.ROWS - 1) * self.cell_size
            love.graphics.line(x, y_top, x, y_bottom)
        else
            -- 中间的线，被楚河汉界分成两段
            -- 上半部分（y=1 到 y=5）
            local y_top = self.y + self.padding
            local y_mid_top = self.y + self.padding + (Board.RIVER_Y_TOP - 1) * self.cell_size
            love.graphics.line(x, y_top, x, y_mid_top)

            -- 下半部分（y=6 到 y=10）
            local y_mid_bottom = self.y + self.padding + (Board.RIVER_Y_BOTTOM - 1) * self.cell_size
            local y_bottom = self.y + self.padding + (Board.ROWS - 1) * self.cell_size
            love.graphics.line(x, y_mid_bottom, x, y_bottom)
        end
    end

    -- 横线（10 条）
    for row = 1, Board.ROWS do
        local y = self.y + self.padding + (row - 1) * self.cell_size
        local x_left = self.x + self.padding
        local x_right = self.x + self.padding + (Board.COLS - 1) * self.cell_size
        love.graphics.line(x_left, y, x_right, y)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制楚河汉界
function Board:draw_river()
    local y_top = self.y + self.padding + (Board.RIVER_Y_TOP - 1) * self.cell_size
    local y_bottom = self.y + self.padding + (Board.RIVER_Y_BOTTOM - 1) * self.cell_size
    local x_left = self.x + self.padding
    local x_right = self.x + self.padding + (Board.COLS - 1) * self.cell_size

    -- 河界区域（用稍微浅一点的颜色）
    love.graphics.setColor(0.85, 0.75, 0.6, 0.5)
    love.graphics.rectangle("fill", x_left, y_top, x_right - x_left, y_bottom - y_top)

    -- 楚河 汉界 文字
    local font = ResourceManager.get_font("NotoSansSC-Regular.ttc", self.cell_size * 0.6)
    love.graphics.setFont(font)
    love.graphics.setColor(self.colors.river_text)

    -- 楚河（左侧，竖排？不，横排就好）
    local chu_text = "楚河"
    local han_text = "汉界"
    local text_y = y_top + (y_bottom - y_top - font:getHeight()) / 2

    local chu_w = font:getWidth(chu_text)
    local han_w = font:getWidth(han_text)

    -- 楚河在左边，汉界在右边，中间留白
    local gap = self.cell_size * 1.5
    local total_w = chu_w + gap + han_w
    local start_x = x_left + (x_right - x_left - total_w) / 2

    love.graphics.print(chu_text, start_x, text_y)
    love.graphics.print(han_text, start_x + chu_w + gap, text_y)

    -- 恢复默认字体
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制九宫格斜线
function Board:draw_fortress()
    love.graphics.setColor(self.colors.line)
    love.graphics.setLineWidth(1)

    -- 黑方九宫（上方）
    do
        local f = Board.FORTRESS.black
        local x1, y1 = self:board_to_screen(f.min_x, f.min_y)
        local x2, y2 = self:board_to_screen(f.max_x, f.max_y)
        -- 两条对角线
        love.graphics.line(x1, y1, x2, y2)
        love.graphics.line(x2, y1, x1, y2)
    end

    -- 红方九宫（下方）
    do
        local f = Board.FORTRESS.red
        local x1, y1 = self:board_to_screen(f.min_x, f.min_y)
        local x2, y2 = self:board_to_screen(f.max_x, f.max_y)
        love.graphics.line(x1, y1, x2, y2)
        love.graphics.line(x2, y1, x1, y2)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制位置标记（炮位和兵位的小记号）
function Board:draw_position_marks()
    love.graphics.setColor(self.colors.line)

    -- 炮的位置标记（小十字）
    -- 黑方炮: (2,3) 和 (8,3)
    -- 红方炮: (2,8) 和 (8,8)
    local cannon_positions = {
        {2, 3}, {8, 3},
        {2, 8}, {8, 8},
    }

    for _, pos in ipairs(cannon_positions) do
        self:draw_position_mark(pos[1], pos[2])
    end

    -- 兵/卒的位置标记
    -- 黑方卒: (1,4), (3,4), (5,4), (7,4), (9,4)
    -- 红方兵: (1,7), (3,7), (5,7), (7,7), (9,7)
    local pawn_positions = {
        {1, 4}, {3, 4}, {5, 4}, {7, 4}, {9, 4},
        {1, 7}, {3, 7}, {5, 7}, {7, 7}, {9, 7},
    }

    for _, pos in ipairs(pawn_positions) do
        self:draw_position_mark(pos[1], pos[2])
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制单个位置标记（小 L 形）
-- @param bx, by (number) 棋盘坐标
function Board:draw_position_mark(bx, by)
    local sx, sy = self:board_to_screen(bx, by)
    local size = self.cell_size * 0.12
    local gap = self.cell_size * 0.08

    love.graphics.setLineWidth(1)

    -- 左上角
    if bx > 1 and by > 1 then
        love.graphics.line(sx - gap, sy - size, sx - gap, sy - gap)
        love.graphics.line(sx - size, sy - gap, sx - gap, sy - gap)
    end

    -- 右上角
    if bx < Board.COLS and by > 1 then
        love.graphics.line(sx + gap, sy - size, sx + gap, sy - gap)
        love.graphics.line(sx + gap, sy - gap, sx + size, sy - gap)
    end

    -- 左下角
    if bx > 1 and by < Board.ROWS then
        love.graphics.line(sx - gap, sy + gap, sx - gap, sy + size)
        love.graphics.line(sx - size, sy + gap, sx - gap, sy + gap)
    end

    -- 右下角
    if bx < Board.COLS and by < Board.ROWS then
        love.graphics.line(sx + gap, sy + gap, sx + gap, sy + size)
        love.graphics.line(sx + gap, sy + gap, sx + size, sy + gap)
    end
end

-- 绘制选中高亮
-- @param bx, by (number) 棋盘坐标
-- @param color (table) 颜色
function Board:draw_highlight(bx, by, color)
    local sx, sy = self:board_to_screen(bx, by)
    local size = self.cell_size * 0.45

    love.graphics.setColor(color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", sx - size, sy - size, size * 2, size * 2, 4, 4)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制可走位置提示
function Board:draw_move_hint(bx, by)
    local sx, sy = self:board_to_screen(bx, by)
    local radius = self.cell_size * 0.15

    love.graphics.setColor(self.colors.move_hint)
    love.graphics.circle("fill", sx, sy, radius)
    love.graphics.setColor(1, 1, 1, 1)
end

return Board
