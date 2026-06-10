-- 场景名: game_scene
-- 功能: 对局场景
-- 说明: 显示棋盘和棋子的游戏主场景
-- V2 版本：完整棋子 + 走法规则 + 吃子 + 将军判定

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local Input = Core.Input
local SceneManager = Core.SceneManager
local ResourceManager = Core.ResourceManager
local EventBus = Core.EventBus
local Utils = Core.Utils

local Board = require("src.game.entities.board")
local GameState = require("src.game.systems.game_state")
local Rules = require("src.game.systems.rules")

local GameScene = {}
GameScene.__index = GameScene

-- ============================================================
-- 构造函数
-- ============================================================

function GameScene.new()
    local self = setmetatable({}, GameScene)

    -- 棋盘
    self.board = nil

    -- 游戏状态
    self.game_state = nil

    -- 选中的棋子
    self.selected_piece = nil

    -- 可走位置
    self.valid_moves = {}

    -- 消息提示（临时显示）
    self.message = nil
    self.message_timer = 0
    self.message_is_error = false

    -- 最后一步走棋的位置（高亮显示）
    self.last_move = nil

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

    -- 居中
    self.board.x = (w - self.board.width) / 2
    self.board.y = (h - self.board.height) / 2

    -- ========== 初始化游戏状态 ==========
    self.game_state = GameState.new()
    self.game_state:init_default_board()

    -- 注册事件监听
    self:_register_events()

    -- ========== 背景层 ==========
    RenderLayer.add("BACKGROUND", function()
        local w, h = love.graphics.getDimensions()

        -- 深色背景
        love.graphics.setColor(0.05, 0.05, 0.1, 1)
        love.graphics.rectangle("fill", 0, 0, w, h)

        -- 装饰性渐变光晕（增加纵深感）
        -- 顶部亮光
        for i = 0, 100, 3 do
            local alpha = (100 - i) / 100 * 0.2
            love.graphics.setColor(0.4, 0.35, 0.25, alpha)
            love.graphics.rectangle("fill", 0, i, w, 2)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- ========== 游戏层：棋盘 + 棋子 ==========
    RenderLayer.add("GAME", function()
        self.board:draw()
        self:draw_last_move_highlight()
        self:draw_pieces()
        self:draw_valid_moves()
    end)

    -- ========== 特效层：棋盘光晕 ==========
    RenderLayer.add("EFFECTS", function()
        local bx = self.board.x + self.board.width / 2
        local by = self.board.y + self.board.height / 2
        local bw, bh = self.board.width, self.board.height

        -- 外发光（多层半透明矩形叠加模拟光晕）
        love.graphics.setColor(1, 0.9, 0.7, 0.06)
        love.graphics.rectangle("fill",
            bx - bw/2 - 12, by - bh/2 - 12, bw + 24, bh + 24, 16, 16)
        love.graphics.setColor(1, 0.9, 0.7, 0.04)
        love.graphics.rectangle("fill",
            bx - bw/2 - 24, by - bh/2 - 24, bw + 48, bh + 48, 20, 20)

        -- 将军提示闪烁（如果被将军）
        if self.game_state and self.game_state.status == "check" then
            -- 被将军方的九宫格闪烁
            local side = self.game_state.checked_side
            local fortress = self:_get_fortress_rect(side)

            local pulse = 0.5 + 0.5 * math.sin(love.timer.getTime() * 4)
            love.graphics.setColor(1, 0.2, 0.2, 0.15 + pulse * 0.2)
            love.graphics.rectangle("fill",
                fortress.x, fortress.y, fortress.width, fortress.height,
                6, 6)
        end

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
        love.graphics.print("Scene: game_scene (V2)", 10, 10)
        love.graphics.print("Turn: " .. self.game_state.current_turn, 10, 30)
        love.graphics.print("Status: " .. self.game_state.status, 10, 50)

        if bx then
            love.graphics.print(string.format("Board: (%d, %d)", bx, by), 10, 70)
        else
            love.graphics.print("Board: (out of range)", 10, 70)
        end

        love.graphics.print("Pieces alive: " .. tostring(#self.game_state:get_alive_pieces()), 10, 90)
        if self.selected_piece then
            love.graphics.print("Selected: " .. self.selected_piece.type ..
                " (" .. self.selected_piece.side .. ")", 10, 110)
            love.graphics.print("Valid moves: " .. #self.valid_moves, 10, 130)
        end

        love.graphics.print("ESC 返回菜单 | R 重置 | U 悔棋", 10, 150)

        love.graphics.setColor(1, 1, 1, 1)
    end)

    Logger.info("GameScene: ready")
end

-- ============================================================
-- 注册事件监听
-- ============================================================

function GameScene:_register_events()
    -- 走棋事件
    EventBus.on("game:move", function(data)
        Logger.debugf("GameScene: move event - %s %s (%d,%d)->(%d,%d)",
            data.piece.side, data.piece.type,
            data.from_x, data.from_y, data.to_x, data.to_y)

        -- 记录最后一步
        self.last_move = {
            from_x = data.from_x,
            from_y = data.from_y,
            to_x = data.to_x,
            to_y = data.to_y,
        }
    end)

    -- 吃子事件
    EventBus.on("game:capture", function(piece)
        Logger.debugf("GameScene: capture event - %s %s", piece.side, piece.type)
        self:show_message("吃子！", false, 0.8)
    end)

    -- 将军事件
    EventBus.on("game:check", function(data)
        local side_name = data.side == "red" and "红方" or "黑方"
        self:show_message(side_name .. "被将军！", false, 1.5)
    end)

    -- 将死事件
    EventBus.on("game:checkmate", function(data)
        local winner = data.loser == "red" and "黑方" or "红方"
        self:show_message(winner .. "获胜！（" .. (data.reason or "将死") .. "）", false, 5)
    end)
end

-- ============================================================
-- 注销事件监听
-- ============================================================

function GameScene:_unregister_events()
    -- 移除所有 game: 相关的事件监听器
    -- EventBus.clear(name) 会移除该事件的所有监听器
    EventBus.clear("game:move")
    EventBus.clear("game:capture")
    EventBus.clear("game:check")
    EventBus.clear("game:checkmate")
    EventBus.clear("game:undo")
    EventBus.clear("game:reset")
    EventBus.clear("game:board_ready")
end

-- ============================================================
-- 获取九宫格的屏幕矩形（用于将军闪烁效果）
-- ============================================================

function GameScene:_get_fortress_rect(side)
    local fortress
    if side == "black" then
        fortress = { min_x = 4, max_x = 6, min_y = 1, max_y = 3 }
    else
        fortress = { min_x = 4, max_x = 6, min_y = 8, max_y = 10 }
    end

    local x1, y1 = self.board:board_to_screen(fortress.min_x, fortress.min_y)
    local x2, y2 = self.board:board_to_screen(fortress.max_x, fortress.max_y)
    local padding = self.board.cell_size * 0.3

    return {
        x = x1 - padding,
        y = y1 - padding,
        width = x2 - x1 + padding * 2,
        height = y2 - y1 + padding * 2,
    }
end

-- ============================================================
-- 绘制棋子
-- ============================================================

function GameScene:draw_pieces()
    if not self.game_state then return end

    -- 获取所有存活的棋子并绘制
    for _, piece in ipairs(self.game_state.pieces) do
        if piece.alive then
            piece:draw(self.board)
        end
    end
end

-- ============================================================
-- 绘制可走位置提示
-- ============================================================

function GameScene:draw_valid_moves()
    for _, move in ipairs(self.valid_moves) do
        local sx, sy = self.board:board_to_screen(move.x, move.y)
        local radius = self.board.cell_size * 0.18

        -- 目标位置是否有棋子（吃子）
        local target = self.game_state:get_piece_at(move.x, move.y)

        if target then
            -- 吃子：画一个圆环
            love.graphics.setColor(0.95, 0.3, 0.3, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", sx, sy, self.board.cell_size * 0.42)
            love.graphics.setLineWidth(1)
        else
            -- 空位：画半透明圆点
            love.graphics.setColor(0.2, 0.85, 0.4, 0.6)
            love.graphics.circle("fill", sx, sy, radius)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- ============================================================
-- 绘制最后一步高亮
-- ============================================================

function GameScene:draw_last_move_highlight()
    if not self.last_move then return end

    -- 起点和终点都高亮一下
    local positions = {
        { self.last_move.from_x, self.last_move.from_y, 0.2 },
        { self.last_move.to_x,   self.last_move.to_y,   0.35 },
    }

    for _, pos in ipairs(positions) do
        local bx, by, alpha = pos[1], pos[2], pos[3]
        local sx, sy = self.board:board_to_screen(bx, by)
        local size = self.board.cell_size * 0.45

        love.graphics.setColor(1, 0.85, 0.3, alpha)
        love.graphics.rectangle("fill", sx - size, sy - size, size * 2, size * 2, 4, 4)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 显示消息
-- ============================================================

function GameScene:show_message(text, is_error, duration)
    self.message = text
    self.message_is_error = is_error or false
    self.message_timer = duration or 2.0
end

-- ============================================================
-- 绘制 UI
-- ============================================================

function GameScene:draw_ui()
    local w, h = love.graphics.getDimensions()

    -- 顶部：当前回合提示
    local turn_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 22)
    love.graphics.setFont(turn_font)

    local turn_text
    if self.game_state:is_game_over() then
        local winner, reason = self.game_state:get_winner()
        if winner then
            local winner_name = winner == "red" and "红方" or "黑方"
            turn_text = winner_name .. "获胜！"
            love.graphics.setColor(1, 0.9, 0.3, 1)  -- 金色
        else
            turn_text = "和棋"
            love.graphics.setColor(0.7, 0.7, 0.8, 1)
        end
    elseif self.game_state.status == "check" then
        local checked_name = self.game_state.checked_side == "red" and "红方" or "黑方"
        turn_text = "将军！" .. checked_name .. "应将"
        love.graphics.setColor(1, 0.3, 0.3, 1)  -- 红色
    else
        local side_name = self.game_state.current_turn == "red" and "红方" or "黑方"
        turn_text = side_name .. "回合"
        if self.game_state.current_turn == "red" then
            love.graphics.setColor(0.95, 0.3, 0.3, 1)  -- 红色
        else
            love.graphics.setColor(0.3, 0.35, 0.5, 1)  -- 深蓝灰
        end
    end

    local turn_w = turn_font:getWidth(turn_text)
    love.graphics.print(turn_text, (w - turn_w) / 2, 20)

    -- 底部：操作提示
    local hint_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 13)
    love.graphics.setFont(hint_font)
    love.graphics.setColor(0.5, 0.5, 0.6, 1)

    local hint = "点击棋子选中，点击目标位置移动  |  ESC 返回菜单  |  R 重新开始  |  U 悔棋"
    local hint_w = hint_font:getWidth(hint)
    love.graphics.print(hint, (w - hint_w) / 2, h - 30)

    -- 临时消息
    if self.message and self.message_timer > 0 then
        local msg_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 20)
        love.graphics.setFont(msg_font)

        if self.message_is_error then
            love.graphics.setColor(1, 0.4, 0.4, 1)  -- 错误：红色
        else
            love.graphics.setColor(1, 1, 0.6, 1)    -- 普通：黄色
        end

        -- 半透明背景
        local msg_w = msg_font:getWidth(self.message)
        local msg_h = msg_font:getHeight()
        local bg_x = (w - msg_w) / 2 - 20
        local bg_y = h / 2 + 80 - 4
        love.graphics.setColor(0, 0, 0, 0.6)
        love.graphics.rectangle("fill", bg_x, bg_y, msg_w + 40, msg_h + 8, 6, 6)

        if self.message_is_error then
            love.graphics.setColor(1, 0.4, 0.4, 1)
        else
            love.graphics.setColor(1, 1, 0.6, 1)
        end
        love.graphics.print(self.message, (w - msg_w) / 2, h / 2 + 80)
    end

    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 每帧更新
-- ============================================================

function GameScene:update(dt)
    -- 更新消息计时器
    if self.message_timer > 0 then
        self.message_timer = self.message_timer - dt
    end

    -- 处理输入
    self:handle_input()

    -- 快捷键
    if Input.is_pressed("cancel") then
        Logger.debug("GameScene: ESC pressed, returning to menu")
        SceneManager.switch("menu")
    end

    if Input.is_pressed("r") then
        self.game_state:reset()
        self.selected_piece = nil
        self.valid_moves = {}
        self.last_move = nil
        self:show_message("已重新开始", false, 1.0)
    end

    if Input.is_pressed("u") then
        local success = self.game_state:undo()
        if success then
            self.selected_piece = nil
            self.valid_moves = {}
            -- 更新最后一步显示
            if #self.game_state.history > 0 then
                local last = self.game_state.history[#self.game_state.history]
                self.last_move = {
                    from_x = last.from_x,
                    from_y = last.from_y,
                    to_x = last.to_x,
                    to_y = last.to_y,
                }
            else
                self.last_move = nil
            end
            self:show_message("已悔棋", false, 0.8)
        else
            self:show_message("没有可悔的棋", true, 1.0)
        end
    end
end

-- ============================================================
-- 处理输入（点击棋子）
-- ============================================================

function GameScene:handle_input()
    if not Input.is_mouse_pressed(1) then
        return
    end

    local mx, my = Input.get_mouse_position()
    local bx, by = self.board:screen_to_board(mx, my)

    -- 游戏已结束时，点击只显示提示
    if self.game_state:is_game_over() then
        self:show_message("游戏已结束，按 R 重新开始", true, 1.5)
        return
    end

    if not bx then
        -- 点击在棋盘外，取消选中
        if self.selected_piece then
            self.selected_piece:set_selected(false)
            self.selected_piece = nil
            self.valid_moves = {}
            self.board:clear_selected()
        end
        return
    end

    local clicked_piece = self.game_state:get_piece_at(bx, by)

    if self.selected_piece then
        -- 已经选中了棋子
        if clicked_piece and clicked_piece.side == self.game_state.current_turn then
            -- 点击了己方的另一个棋子，切换选中
            self.selected_piece:set_selected(false)
            self.selected_piece = clicked_piece
            clicked_piece:set_selected(true)
            self.board:set_selected(bx, by)
            self.valid_moves = self.game_state:get_legal_moves(clicked_piece)

        elseif clicked_piece and clicked_piece.side ~= self.game_state.current_turn then
            -- 点击了对方棋子，尝试吃子
            self:_try_move(self.selected_piece, bx, by)

        else
            -- 点击了空位，尝试移动
            self:_try_move(self.selected_piece, bx, by)
        end
    else
        -- 没有选中棋子
        if clicked_piece then
            -- 点击了棋子
            if clicked_piece.side == self.game_state.current_turn then
                -- 己方棋子，选中它
                self.selected_piece = clicked_piece
                clicked_piece:set_selected(true)
                self.board:set_selected(bx, by)
                self.valid_moves = self.game_state:get_legal_moves(clicked_piece)
            else
                -- 对方棋子，提示
                local side_name = self.game_state.current_turn == "red" and "红方" or "黑方"
                self:show_message("现在是" .. side_name .. "回合", true, 1.0)
            end
        end
    end
end

-- ============================================================
-- 尝试走一步
-- ============================================================

function GameScene:_try_move(piece, to_x, to_y)
    local success, reason = self.game_state:move(piece, to_x, to_y)

    if success then
        -- 走棋成功，取消选中
        piece:set_selected(false)
        self.selected_piece = nil
        self.valid_moves = {}
        self.board:clear_selected()
    else
        -- 走棋失败，显示原因
        self:show_message(reason, true, 1.5)
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

    -- 注销事件监听
    self:_unregister_events()

    -- 清理
    self.board = nil
    self.game_state = nil
    self.selected_piece = nil
    self.valid_moves = {}
    self.last_move = nil

    RenderLayer.clear_all()
end

return GameScene
