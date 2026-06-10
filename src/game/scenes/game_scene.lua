-- 场景名: game_scene
-- 功能: 对局场景
-- 说明: 显示棋盘和棋子的游戏主场景
-- V1 版本：棋盘渲染 + 棋子占位（方块代替）+ 基本交互
-- V2 版本：完整棋子 + 走法规则 + 吃子

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local Input = Core.Input
local SceneManager = Core.SceneManager
local ResourceManager = Core.ResourceManager
local EventBus = Core.EventBus
local Utils = Core.Utils

local Board = require("src.game.entities.board")

local GameScene = {}
GameScene.__index = GameScene

-- ============================================================
-- 构造函数
-- ============================================================

function GameScene.new()
    local self = setmetatable({}, GameScene)

    -- 棋盘
    self.board = nil

    -- 棋子占位数据（V1 用彩色方块代替真实棋子）
    -- 数据结构: { x, y, side, type, color }
    -- side: "red" 或 "black"
    -- type: "king", "advisor", "elephant", "horse", "chariot", "cannon", "pawn"
    self.pieces = {}

    -- 选中的棋子
    self.selected_piece = nil

    -- 回合
    self.current_turn = "red"  -- red 或 black

    -- 消息提示
    self.message = nil
    self.message_timer = 0

    return self
end

-- ============================================================
-- 场景进入
-- ============================================================

function GameScene:enter(params)
    Logger.debug("GameScene: enter")

    local w, h = love.graphics.getDimensions()

    -- ========== 创建棋盘 ==========
    self.board = Board.new({
        cell_size = 60,
        padding = 30,
    })

    -- 让棋盘居中显示
    self.board.x = (w - self.board.width) / 2
    self.board.y = (h - self.board.height) / 2

    -- ========== 初始化棋子（占位，V1 用彩色方块） ==========
    self:init_pieces()

    -- ========== 背景层 ==========
    RenderLayer.add("BACKGROUND", function()
        -- 深色背景
        local w, h = love.graphics.getDimensions()
        love.graphics.setColor(0.05, 0.05, 0.1, 1)
        love.graphics.rectangle("fill", 0, 0, w, h)

        -- 装饰性渐变（增加纵深感）
        -- 顶部亮光
        local gradient = {
            {0.1, 0.1, 0.15, 0.5},
            {0.05, 0.05, 0.1, 0},
        }
        -- 简单模拟：画几条横线
        for i = 0, 100, 4 do
            local alpha = (100 - i) / 100 * 0.3
            love.graphics.setColor(0.3, 0.25, 0.2, alpha)
            love.graphics.rectangle("fill", 0, i, w, 2)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- ========== 游戏层：棋盘 + 棋子 ==========
    RenderLayer.add("GAME", function()
        self.board:draw()
        self:draw_pieces()
    end)

    -- ========== 特效层 ==========
    -- V1 暂时空着，留位置
    RenderLayer.add("EFFECTS", function()
        -- 棋盘周围的光晕
        local bx, by = self.board.x + self.board.width / 2,
                       self.board.y + self.board.height / 2
        local bw, bh = self.board.width, self.board.height

        -- 简单的外发光（用几个半透明矩形叠加）
        love.graphics.setColor(1, 0.9, 0.7, 0.05)
        love.graphics.rectangle("fill",
            bx - bw/2 - 10, by - bh/2 - 10, bw + 20, bh + 20, 15, 15)
        love.graphics.setColor(1, 0.9, 0.7, 0.03)
        love.graphics.rectangle("fill",
            bx - bw/2 - 20, by - bh/2 - 20, bw + 40, bh + 40, 20, 20)

        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- ========== UI 层 ==========
    RenderLayer.add("UI", function()
        self:draw_ui()
    end)

    -- ========== 调试层 ==========
    RenderLayer.add("DEBUG", function()
        local mx, my = Input.get_mouse_position()
        local bx, by = self.board:screen_to_board(mx, my)

        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print("Scene: game_scene", 10, 10)
        love.graphics.print("Turn: " .. self.current_turn, 10, 30)
        love.graphics.print(string.format("Mouse: (%d, %d)", mx, my), 10, 50)

        if bx then
            love.graphics.print(string.format("Board: (%d, %d)", bx, by), 10, 70)
        else
            love.graphics.print("Board: (out of range)", 10, 70)
        end

        love.graphics.print("Pieces: " .. tostring(#self.pieces), 10, 90)
        love.graphics.print("ESC 返回主菜单 | 空格 重置棋盘", 10, 110)

        love.graphics.setColor(1, 1, 1, 1)
    end)

    Logger.info("GameScene: ready")
end

-- ============================================================
-- 初始化棋子（占位）
-- V1 只用不同颜色的方块代表不同棋子
-- ============================================================

function GameScene:init_pieces()
    self.pieces = {}

    -- 棋子初始布局
    -- 黑方（上方，y=1, y=2, y=3, y=4）
    local black_pieces = {
        -- 第一排（y=1）：车、马、象、士、将、士、象、马、车
        {type = "chariot",  x = 1, y = 1},
        {type = "horse",    x = 2, y = 1},
        {type = "elephant", x = 3, y = 1},
        {type = "advisor",  x = 4, y = 1},
        {type = "king",     x = 5, y = 1},
        {type = "advisor",  x = 6, y = 1},
        {type = "elephant", x = 7, y = 1},
        {type = "horse",    x = 8, y = 1},
        {type = "chariot",  x = 9, y = 1},
        -- 第二排（y=3）：炮
        {type = "cannon",   x = 2, y = 3},
        {type = "cannon",   x = 8, y = 3},
        -- 第三排（y=4）：卒
        {type = "pawn",     x = 1, y = 4},
        {type = "pawn",     x = 3, y = 4},
        {type = "pawn",     x = 5, y = 4},
        {type = "pawn",     x = 7, y = 4},
        {type = "pawn",     x = 9, y = 4},
    }

    -- 红方（下方，y=10, y=9, y=8, y=7）
    local red_pieces = {
        -- 第一排（y=10）：车、马、相、士、帅、士、相、马、车
        {type = "chariot",  x = 1, y = 10},
        {type = "horse",    x = 2, y = 10},
        {type = "elephant", x = 3, y = 10},
        {type = "advisor",  x = 4, y = 10},
        {type = "king",     x = 5, y = 10},
        {type = "advisor",  x = 6, y = 10},
        {type = "elephant", x = 7, y = 10},
        {type = "horse",    x = 8, y = 10},
        {type = "chariot",  x = 9, y = 10},
        -- 第二排（y=8）：炮
        {type = "cannon",   x = 2, y = 8},
        {type = "cannon",   x = 8, y = 8},
        -- 第三排（y=7）：兵
        {type = "pawn",     x = 1, y = 7},
        {type = "pawn",     x = 3, y = 7},
        {type = "pawn",     x = 5, y = 7},
        {type = "pawn",     x = 7, y = 7},
        {type = "pawn",     x = 9, y = 7},
    }

    -- 添加棋子
    for _, p in ipairs(black_pieces) do
        table.insert(self.pieces, {
            x = p.x,
            y = p.y,
            side = "black",
            type = p.type,
        })
    end

    for _, p in ipairs(red_pieces) do
        table.insert(self.pieces, {
            x = p.x,
            y = p.y,
            side = "red",
            type = p.type,
        })
    end

    Logger.infof("GameScene: initialized %d pieces", #self.pieces)
end

-- ============================================================
-- 绘制棋子（V1 用彩色方块 + 文字占位）
-- ============================================================

function GameScene:draw_pieces()
    for _, piece in ipairs(self.pieces) do
        local sx, sy = self.board:board_to_screen(piece.x, piece.y)
        local size = self.board.cell_size * 0.8 / 2  -- 半径

        -- 棋子颜色（V1 用简单颜色区分）
        local base_color
        if piece.side == "red" then
            base_color = {0.9, 0.2, 0.2, 1}  -- 红色
        else
            base_color = {0.15, 0.15, 0.2, 1}  -- 深灰黑色
        end

        -- 判断是否选中
        local is_selected = self.selected_piece and
                            self.selected_piece.x == piece.x and
                            self.selected_piece.y == piece.y

        -- 选中的棋子画一个高亮外圈
        if is_selected then
            love.graphics.setColor(1, 1, 0.3, 1)
            love.graphics.circle("fill", sx, sy, size + 4)
        end

        -- 棋子主体（圆形，模拟真实棋子）
        love.graphics.setColor(base_color)
        love.graphics.circle("fill", sx, sy, size)

        -- 棋子边框
        love.graphics.setColor(0.9, 0.8, 0.6, 1)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", sx, sy, size)
        love.graphics.setLineWidth(1)

        -- 棋子文字（V1 用类型缩写）
        -- 用简单的字母代替，V2 再用中文
        local abbrev = {
            king = "K",
            advisor = "A",
            elephant = "E",
            horse = "H",
            chariot = "R",  -- Rook
            cannon = "C",
            pawn = "P",
        }

        local text = abbrev[piece.type] or "?"
        local font = ResourceManager.get_font(nil, math.floor(size * 1.2))
        love.graphics.setFont(font)

        -- 文字颜色
        if piece.side == "red" then
            love.graphics.setColor(1, 0.9, 0.9, 1)
        else
            love.graphics.setColor(0.8, 0.8, 0.9, 1)
        end

        local tw = font:getWidth(text)
        local th = font:getHeight()
        love.graphics.print(text, sx - tw/2, sy - th/2)

        love.graphics.setFont(love.graphics.newFont(12))
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- ============================================================
-- 获取指定位置的棋子
-- ============================================================

function GameScene:get_piece_at(bx, by)
    for _, piece in ipairs(self.pieces) do
        if piece.x == bx and piece.y == by then
            return piece
        end
    end
    return nil
end

-- ============================================================
-- 绘制 UI
-- ============================================================

function GameScene:draw_ui()
    local w, h = love.graphics.getDimensions()

    -- 顶部：当前回合提示
    local title_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 24)
    love.graphics.setFont(title_font)

    local turn_text
    if self.current_turn == "red" then
        love.graphics.setColor(0.95, 0.3, 0.3, 1)
        turn_text = "红方回合"
    else
        love.graphics.setColor(0.3, 0.3, 0.5, 1)
        turn_text = "黑方回合"
    end

    local turn_w = title_font:getWidth(turn_text)
    love.graphics.print(turn_text, (w - turn_w) / 2, 20)

    -- 底部：操作提示
    local hint_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 14)
    love.graphics.setFont(hint_font)
    love.graphics.setColor(0.5, 0.5, 0.6, 1)

    local hint = "V1 演示版 — 点击棋子选中，再点击目标位置移动（暂不校验规则）"
    local hint_w = hint_font:getWidth(hint)
    love.graphics.print(hint, (w - hint_w) / 2, h - 40)

    -- 消息提示
    if self.message and self.message_timer > 0 then
        local msg_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 18)
        love.graphics.setFont(msg_font)
        love.graphics.setColor(1, 1, 0.5, 1)

        local msg_w = msg_font:getWidth(self.message)
        love.graphics.print(self.message, (w - msg_w) / 2, h / 2 + 100)
    end

    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 显示消息
-- ============================================================

function GameScene:show_message(text, duration)
    self.message = text
    self.message_timer = duration or 1.5
end

-- ============================================================
-- 每帧更新
-- ============================================================

function GameScene:update(dt)
    -- 更新棋盘
    self.board:update(dt)

    -- 更新消息计时器
    if self.message_timer > 0 then
        self.message_timer = self.message_timer - dt
    end

    -- 处理输入
    self:handle_input()

    -- ESC 返回菜单
    if Input.is_pressed("cancel") then
        Logger.debug("GameScene: ESC pressed, returning to menu")
        SceneManager.switch("menu")
    end

    -- 空格重置
    if Input.is_pressed("space") then
        self:init_pieces()
        self.selected_piece = nil
        self.current_turn = "red"
        self:show_message("棋盘已重置")
    end
end

-- ============================================================
-- 处理输入（点击棋子）
-- V1 简单实现：点击选中，再点击移动（不校验规则）
-- ============================================================

function GameScene:handle_input()
    if not Input.is_mouse_pressed(1) then
        return
    end

    local mx, my = Input.get_mouse_position()
    local bx, by = self.board:screen_to_board(mx, my)

    if not bx then
        -- 点击在棋盘外，取消选中
        if self.selected_piece then
            self.selected_piece = nil
            self.board:clear_selected()
        end
        return
    end

    local clicked_piece = self:get_piece_at(bx, by)

    if self.selected_piece then
        -- 已经选中了棋子
        if clicked_piece and clicked_piece.side == self.current_turn then
            -- 点击了己方的另一个棋子，切换选中
            self.selected_piece = clicked_piece
            self.board:set_selected(bx, by)
            self:show_message("已选中" .. (clicked_piece.type))
        elseif clicked_piece and clicked_piece.side ~= self.current_turn then
            -- 点击了对方棋子，吃子（V1 不校验规则）
            self:move_piece(self.selected_piece, bx, by, true)
        else
            -- 点击了空位，移动（V1 不校验规则）
            self:move_piece(self.selected_piece, bx, by, false)
        end
    else
        -- 没有选中棋子
        if clicked_piece then
            -- 点击了棋子，选中它
            -- V1 只允许选中当前回合方的棋子
            if clicked_piece.side == self.current_turn then
                self.selected_piece = clicked_piece
                self.board:set_selected(bx, by)
                self:show_message("已选中" .. (clicked_piece.type))
            else
                self:show_message("现在是" .. (self.current_turn == "red" and "红方" or "黑方") .. "回合")
            end
        end
    end
end

-- ============================================================
-- 移动棋子
-- V1 不校验规则，直接移动
-- ============================================================

function GameScene:move_piece(piece, to_x, to_y, is_capture)
    Logger.debugf("GameScene: move %s from (%d,%d) to (%d,%d) %s",
        piece.type, piece.x, piece.y, to_x, to_y,
        is_capture and "(capture)" or "")

    -- 如果是吃子，移除对方棋子
    if is_capture then
        for i, p in ipairs(self.pieces) do
            if p.x == to_x and p.y == to_y then
                table.remove(self.pieces, i)
                break
            end
        end
    end

    -- 移动棋子
    piece.x = to_x
    piece.y = to_y

    -- 取消选中
    self.selected_piece = nil
    self.board:clear_selected()

    -- 切换回合
    self.current_turn = (self.current_turn == "red") and "black" or "red"

    if is_capture then
        self:show_message("吃子！", 1.0)
    end
end

-- ============================================================
-- 绘制
-- ============================================================

function GameScene:draw()
    RenderLayer.draw()
end

-- ============================================================
-- 场景退出
-- ============================================================

function GameScene:exit()
    Logger.debug("GameScene: exit")

    self.board = nil
    self.pieces = {}
    self.selected_piece = nil

    RenderLayer.clear_all()
end

return GameScene
