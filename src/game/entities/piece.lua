-- 模块名: piece
-- 功能: 棋子实体
-- 说明: 中国象棋棋子，包含类型、颜色、位置、绘制
-- 棋子类型: king(将/帅), advisor(士/仕), elephant(象/相),
--           horse(马/馬), chariot(车/車), cannon(炮/砲), pawn(兵/卒)
-- 类比: 游戏中的角色/单位实体

local Core = require("src.core")
local Logger = Core.Logger
local ResourceManager = Core.ResourceManager
local Utils = Core.Utils

local Piece = {}
Piece.__index = Piece

-- ============================================================
-- 棋子类型定义
-- ============================================================

-- 棋子类型常量
Piece.TYPE = {
    KING = "king",       -- 将/帅
    ADVISOR = "advisor", -- 士/仕
    ELEPHANT = "elephant", -- 象/相
    HORSE = "horse",     -- 马/馬
    CHARIOT = "chariot", -- 车/車
    CANNON = "cannon",   -- 炮/砲
    PAWN = "pawn",       -- 兵/卒
}

-- 棋子中文名称（红方 / 黑方）
-- 中国象棋传统：红方用汉字的简体/异体，黑方用繁体/异体
-- 如：帅(红) vs 将(黑)，仕(红) vs 士(黑)，相(红) vs 象(黑)
--     兵(红) vs 卒(黑)，炮(红) vs 砲(黑)
-- 马和车红黑写法有时相同，有时不同，这里统一
Piece.CHAR = {
    red = {
        king = "帅",
        advisor = "仕",
        elephant = "相",
        horse = "马",
        chariot = "车",
        cannon = "炮",
        pawn = "兵",
    },
    black = {
        king = "将",
        advisor = "士",
        elephant = "象",
        horse = "马",
        chariot = "车",
        cannon = "砲",
        pawn = "卒",
    },
}

-- 棋子分值（用于 AI 评估，先定义着，V4 用）
Piece.VALUE = {
    king = 10000,    -- 将帅无价
    chariot = 900,   -- 车
    horse = 400,     -- 马
    cannon = 450,    -- 炮
    advisor = 200,   -- 士
    elephant = 200,  -- 象
    pawn = 100,      -- 兵（过河后升值）
}

-- ============================================================
-- 构造函数
-- ============================================================

-- 创建棋子
-- @param options (table) 配置
--   - type: 棋子类型 (Piece.TYPE.xxx)
--   - side: "red" 或 "black"
--   - x, y: 棋盘坐标
-- @return (Piece) 棋子实例
function Piece.new(options)
    local self = setmetatable({}, Piece)

    options = options or {}

    -- 基本属性
    self.type = options.type or Piece.TYPE.PAWN
    self.side = options.side or "red"
    self.x = options.x or 1
    self.y = options.y or 1

    -- 状态
    self.alive = true       -- 是否存活
    self.selected = false   -- 是否被选中

    -- 动画状态
    self.animating = false       -- 是否正在动画中
    self.anim_progress = 0       -- 动画进度 0-1
    self.anim_duration = 0.25    -- 动画时长（秒）
    self.anim_from_x = 0         -- 动画起点（棋盘坐标）
    self.anim_from_y = 0
    self.anim_to_x = 0           -- 动画终点
    self.anim_to_y = 0
    self.render_offset_x = 0     -- 渲染偏移（像素，用于动画）
    self.render_offset_y = 0

    -- 被吃的动画
    self.capturing = false       -- 正在被吃掉
    self.capture_progress = 0
    self.capture_duration = 0.3

    Logger.debugf("Piece: created %s %s at (%d,%d)",
        self.side, self.type, self.x, self.y)

    return self
end

-- ============================================================
-- 获取棋子中文文字
-- ============================================================

function Piece:get_char()
    local side_chars = Piece.CHAR[self.side]
    if not side_chars then return "?" end
    return side_chars[self.type] or "?"
end

-- ============================================================
-- 获取棋子分值
-- ============================================================

function Piece:get_value()
    local base = Piece.VALUE[self.type] or 0

    -- 兵过河后升值
    if self.type == Piece.TYPE.PAWN then
        -- V2 先给个简单估值，V4 AI 时再细化
        -- 这里需要知道是否过河，但棋子本身不知道棋盘...
        -- 所以暂时返回基础值，AI 层自己处理
    end

    return base
end

-- ============================================================
-- 设置选中状态
-- ============================================================

function Piece:set_selected(selected)
    self.selected = selected
end

-- ============================================================
-- 移动动画
-- ============================================================

-- 开始移动动画（从当前位置到目标位置）
-- 动画期间棋子的逻辑位置不变，只是视觉上在移动
-- @param to_x, to_y (number) 目标棋盘坐标
-- @param duration (number) 动画时长（秒），可选
function Piece:start_move_animation(to_x, to_y, duration)
    self.animating = true
    self.anim_progress = 0
    self.anim_duration = duration or 0.25
    self.anim_from_x = self.x
    self.anim_from_y = self.y
    self.anim_to_x = to_x
    self.anim_to_y = to_y
    self.render_offset_x = 0
    self.render_offset_y = 0
end

-- 开始被吃的动画（缩小消失）
function Piece:start_capture_animation(duration)
    self.capturing = true
    self.capture_progress = 0
    self.capture_duration = duration or 0.3
end

-- 检查动画是否完成
function Piece:is_animation_done()
    if self.animating then
        return self.anim_progress >= 1
    end
    if self.capturing then
        return self.capture_progress >= 1
    end
    return true
end

-- ============================================================
-- 克隆棋子（用于规则推演时不修改原状态）
-- ============================================================

function Piece:clone()
    local new_piece = Piece.new({
        type = self.type,
        side = self.side,
        x = self.x,
        y = self.y,
    })
    new_piece.alive = self.alive
    return new_piece
end

-- ============================================================
-- 绘制棋子
-- @param board (Board) 棋盘引用，用于坐标转换
-- ============================================================

function Piece:draw(board)
    -- 被吃动画结束后就不画了
    if not self.alive and not self.capturing then
        return
    end

    -- 计算绘制位置
    local draw_x, draw_y
    if self.animating then
        -- 移动动画中：在起点和终点之间插值
        -- 用 easeOutQuad 缓动（先快后慢）
        local t = self.anim_progress
        local ease = 1 - (1 - t) * (1 - t)  -- easeOutQuad
        draw_x = self.anim_from_x + (self.anim_to_x - self.anim_from_x) * ease
        draw_y = self.anim_from_y + (self.anim_to_y - self.anim_from_y) * ease
    else
        draw_x = self.x
        draw_y = self.y
    end

    -- 棋盘坐标转屏幕坐标
    local sx, sy = board:board_to_screen(draw_x, draw_y)

    -- 棋子半径（占格子的 80% / 2）
    local base_radius = board.cell_size * 0.4
    local radius = base_radius

    -- 透明度
    local alpha = 1

    -- 被吃动画：缩小 + 淡出
    if self.capturing then
        local t = self.capture_progress
        -- 先放大一点再缩小（弹性效果）
        if t < 0.3 then
            radius = base_radius * (1 + t * 0.3)
        else
            radius = base_radius * (1.09 - (t - 0.3) * 1.3)
        end
        alpha = 1 - t

        -- 不能变成负数
        if radius < 1 then radius = 1 end
        if alpha < 0 then alpha = 0 end
    end

    -- 选中时轻微放大（脉动效果）
    local selected_pulse = 0
    if self.selected and not self.capturing then
        selected_pulse = math.sin(love.timer.getTime() * 4) * 1.5
    end
    radius = radius + selected_pulse * 0.1

    -- ========== 棋子阴影（增加纵深感） ==========
    -- 阴影稍微往下偏一点，移动时阴影偏得更多（模拟高度）
    local shadow_offset_y = 3
    local shadow_offset_x = 2
    if self.animating or self.capturing then
        -- 动画中阴影加大，模拟棋子"飞起来"
        shadow_offset_y = 5 + (1 - math.abs(self.anim_progress - 0.5) * 2) * 4
    end

    love.graphics.setColor(0, 0, 0, 0.25 * alpha)
    love.graphics.circle("fill", sx + shadow_offset_x, sy + shadow_offset_y, radius)

    -- ========== 棋子主体 ==========
    -- 棋子底色（木质感觉）
    if self.side == "red" then
        love.graphics.setColor(0.95, 0.9, 0.75, alpha)
    else
        love.graphics.setColor(0.92, 0.85, 0.7, alpha)
    end
    love.graphics.circle("fill", sx, sy, radius)

    -- 棋子边缘（深色描边，立体感）
    love.graphics.setColor(0.5, 0.35, 0.2, alpha)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", sx, sy, radius)
    love.graphics.setLineWidth(1)

    -- 内圈装饰线
    love.graphics.setColor(0.7, 0.5, 0.3, 0.5 * alpha)
    love.graphics.circle("line", sx, sy, radius * 0.88)

    -- ========== 棋子文字 ==========
    local text = self:get_char()
    local font_size = math.floor(radius * 1.3)
    if font_size < 8 then font_size = 8 end
    local font = ResourceManager.get_font("NotoSansSC-Regular.ttc", font_size)
    love.graphics.setFont(font)

    -- 文字颜色
    if self.side == "red" then
        love.graphics.setColor(0.85, 0.15, 0.1, alpha)
    else
        love.graphics.setColor(0.1, 0.1, 0.15, alpha)
    end

    -- 文字居中
    local tw = font:getWidth(text)
    local th = font:getHeight()
    love.graphics.print(text, sx - tw / 2, sy - th / 2)

    -- ========== 选中高亮 ==========
    if self.selected and not self.capturing then
        -- 外圈金色光环
        love.graphics.setColor(1, 0.9, 0.2, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", sx, sy, radius + 3)
        love.graphics.setLineWidth(1)

        -- 轻微放大效果
        love.graphics.setColor(1, 1, 0.5, 0.2)
        love.graphics.circle("fill", sx, sy, radius + 2)
    end

    -- 恢复默认
    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 每帧更新
-- ============================================================

function Piece:update(dt)
    -- 移动动画
    if self.animating then
        self.anim_progress = self.anim_progress + dt / self.anim_duration

        if self.anim_progress >= 1 then
            -- 动画结束
            self.anim_progress = 1
            self.animating = false
            self.render_offset_x = 0
            self.render_offset_y = 0
        end
    end

    -- 被吃动画
    if self.capturing then
        self.capture_progress = self.capture_progress + dt / self.capture_duration
        if self.capture_progress >= 1 then
            self.capture_progress = 1
            self.capturing = false
            self.alive = false  -- 动画结束后真正消失
        end
    end
end

return Piece
