-- 模块名: game_state
-- 功能: 游戏状态管理
-- 说明: 管理对局状态——棋子、回合、走棋、吃子、将军、胜负
-- 这是纯逻辑模块，不负责渲染
-- 类比: 游戏状态机 / 业务逻辑层

local Core = require("src.core")
local Logger = Core.Logger
local EventBus = Core.EventBus

local Piece = require("src.game.entities.piece")
local Rules = require("src.game.systems.rules")

local GameState = {}
GameState.__index = GameState

-- ============================================================
-- 游戏状态常量
-- ============================================================

GameState.STATUS = {
    PLAYING = "playing",       -- 对局进行中
    CHECK = "check",           -- 将军（有一方被将军）
    CHECKMATE = "checkmate",   -- 将死（对局结束）
    DRAW = "draw",             -- 和棋
    STALEMATE = "stalemate",   -- 困毙（无子可动但没被将军）
}

-- ============================================================
-- 构造函数
-- ============================================================

function GameState.new()
    local self = setmetatable({}, GameState)

    -- 所有棋子
    self.pieces = {}

    -- 当前回合
    self.current_turn = "red"  -- 红方先行

    -- 游戏状态
    self.status = GameState.STATUS.PLAYING

    -- 被将军的一方（如果 status 是 check 或 checkmate）
    self.checked_side = nil
    self.checking_piece = nil  -- 将军的棋子

    -- 走棋历史（用于悔棋、复盘）
    -- 每个记录: { from_x, from_y, to_x, to_y, moved_piece, captured_piece, turn }
    self.history = {}

    -- 步数计数
    self.move_count = 0

    Logger.debug("GameState: created")

    return self
end

-- ============================================================
-- 初始化标准开局
-- ============================================================

function GameState:init_default_board()
    self.pieces = {}
    self.current_turn = "red"
    self.status = GameState.STATUS.PLAYING
    self.checked_side = nil
    self.checking_piece = nil
    self.history = {}
    self.move_count = 0

    -- 黑方（上方，y 小的一侧）
    local black_setup = {
        -- 第一排（y=1）
        { type = "chariot",  x = 1, y = 1 },
        { type = "horse",    x = 2, y = 1 },
        { type = "elephant", x = 3, y = 1 },
        { type = "advisor",  x = 4, y = 1 },
        { type = "king",     x = 5, y = 1 },
        { type = "advisor",  x = 6, y = 1 },
        { type = "elephant", x = 7, y = 1 },
        { type = "horse",    x = 8, y = 1 },
        { type = "chariot",  x = 9, y = 1 },
        -- 炮（y=3）
        { type = "cannon",   x = 2, y = 3 },
        { type = "cannon",   x = 8, y = 3 },
        -- 卒（y=4）
        { type = "pawn",     x = 1, y = 4 },
        { type = "pawn",     x = 3, y = 4 },
        { type = "pawn",     x = 5, y = 4 },
        { type = "pawn",     x = 7, y = 4 },
        { type = "pawn",     x = 9, y = 4 },
    }

    -- 红方（下方，y 大的一侧）
    local red_setup = {
        -- 第一排（y=10）
        { type = "chariot",  x = 1, y = 10 },
        { type = "horse",    x = 2, y = 10 },
        { type = "elephant", x = 3, y = 10 },
        { type = "advisor",  x = 4, y = 10 },
        { type = "king",     x = 5, y = 10 },
        { type = "advisor",  x = 6, y = 10 },
        { type = "elephant", x = 7, y = 10 },
        { type = "horse",    x = 8, y = 10 },
        { type = "chariot",  x = 9, y = 10 },
        -- 炮（y=8）
        { type = "cannon",   x = 2, y = 8 },
        { type = "cannon",   x = 8, y = 8 },
        -- 兵（y=7）
        { type = "pawn",     x = 1, y = 7 },
        { type = "pawn",     x = 3, y = 7 },
        { type = "pawn",     x = 5, y = 7 },
        { type = "pawn",     x = 7, y = 7 },
        { type = "pawn",     x = 9, y = 7 },
    }

    for _, p in ipairs(black_setup) do
        table.insert(self.pieces, Piece.new({
            type = p.type,
            side = "black",
            x = p.x,
            y = p.y,
        }))
    end

    for _, p in ipairs(red_setup) do
        table.insert(self.pieces, Piece.new({
            type = p.type,
            side = "red",
            x = p.x,
            y = p.y,
        }))
    end

    Logger.infof("GameState: initialized default board (%d pieces)", #self.pieces)

    -- 发布事件
    EventBus.emit("game:board_ready", self)
end

-- ============================================================
-- 获取指定位置的棋子
-- ============================================================

function GameState:get_piece_at(x, y)
    for _, p in ipairs(self.pieces) do
        if p.alive and p.x == x and p.y == y then
            return p
        end
    end
    return nil
end

-- ============================================================
-- 获取所有存活的棋子
-- ============================================================

function GameState:get_alive_pieces()
    local alive = {}
    for _, p in ipairs(self.pieces) do
        if p.alive then
            table.insert(alive, p)
        end
    end
    return alive
end

-- ============================================================
-- 获取某方的所有棋子
-- ============================================================

function GameState:get_pieces_by_side(side)
    local result = {}
    for _, p in ipairs(self.pieces) do
        if p.alive and p.side == side then
            table.insert(result, p)
        end
    end
    return result
end

-- ============================================================
-- 获取棋子的合法走法（不送将）
-- ============================================================

function GameState:get_legal_moves(piece)
    return Rules.get_legal_moves(self.pieces, piece)
end

-- ============================================================
-- 走一步棋
-- @param piece (Piece) 要移动的棋子
-- @param to_x, to_y (number) 目标位置
-- @return (boolean, string) 是否成功，原因
-- ============================================================

function GameState:move(piece, to_x, to_y)
    -- 1. 检查游戏是否已结束
    if self.status ~= GameState.STATUS.PLAYING and
       self.status ~= GameState.STATUS.CHECK then
        return false, "游戏已结束"
    end

    -- 2. 检查是否轮到这方走
    if piece.side ~= self.current_turn then
        return false, "不是" .. (piece.side == "red" and "红方" or "黑方") .. "回合"
    end

    -- 3. 检查棋子是否存活
    if not piece.alive then
        return false, "棋子已被吃掉"
    end

    -- 4. 校验走法是否符合棋子规则
    local valid, reason = Rules.validate_move(self.pieces, piece, to_x, to_y)
    if not valid then
        return false, reason
    end

    -- 5. 检查是否会送将（走了之后自己被将军）
    if Rules.would_be_in_check(self.pieces, piece, to_x, to_y) then
        return false, "不能送将"
    end

    -- 6. 记录历史
    local from_x, from_y = piece.x, piece.y
    local captured_piece = self:get_piece_at(to_x, to_y)

    -- 7. 执行移动
    if captured_piece then
        captured_piece.alive = false
    end
    piece.x = to_x
    piece.y = to_y

    -- 8. 记录历史
    table.insert(self.history, {
        from_x = from_x,
        from_y = from_y,
        to_x = to_x,
        to_y = to_y,
        piece = piece,
        captured = captured_piece,
        turn = self.current_turn,
        move_num = self.move_count + 1,
    })

    self.move_count = self.move_count + 1

    -- 9. 切换回合
    self.current_turn = (self.current_turn == "red") and "black" or "red"

    -- 10. 检查新的状态
    self:_update_status()

    -- 11. 发布事件
    EventBus.emit("game:move", {
        piece = piece,
        from_x = from_x,
        from_y = from_y,
        to_x = to_x,
        to_y = to_y,
        captured = captured_piece,
        turn = self.current_turn,
        status = self.status,
    })

    if captured_piece then
        EventBus.emit("game:capture", captured_piece)
    end

    Logger.debugf("GameState: %s %s (%d,%d) -> (%d,%d) %s",
        piece.side, piece.type, from_x, from_y, to_x, to_y,
        captured_piece and "(capture)" or "")

    return true
end

-- ============================================================
-- 更新游戏状态（将军/将死等）
-- ============================================================

function GameState:_update_status()
    local next_side = self.current_turn

    -- 检查下一方是否被将军
    local in_check, checking_piece = Rules.is_in_check(self.pieces, next_side)

    if in_check then
        -- 检查是否将死
        if Rules.is_checkmate(self.pieces, next_side) then
            self.status = GameState.STATUS.CHECKMATE
            self.checked_side = next_side
            self.checking_piece = checking_piece
            Logger.infof("GameState: checkmate! %s loses", next_side)
            EventBus.emit("game:checkmate", { loser = next_side })
        else
            self.status = GameState.STATUS.CHECK
            self.checked_side = next_side
            self.checking_piece = checking_piece
            Logger.debugf("GameState: %s is in check", next_side)
            EventBus.emit("game:check", { side = next_side, by = checking_piece })
        end
    else
        -- 没被将军，检查是否困毙
        -- 困毙：无子可动但没被将军
        local has_legal_move = false
        for _, piece in ipairs(self.pieces) do
            if piece.alive and piece.side == next_side then
                local moves = Rules.get_legal_moves(self.pieces, piece)
                if #moves > 0 then
                    has_legal_move = true
                    break
                end
            end
        end

        if not has_legal_move then
            -- 困毙也算输？中国象棋里困毙是输的
            -- 严格来说中国象棋困毙是输棋（和国际象棋不同）
            self.status = GameState.STATUS.CHECKMATE
            self.checked_side = next_side
            Logger.infof("GameState: stalemate (困毙), %s loses", next_side)
            EventBus.emit("game:checkmate", { loser = next_side, reason = "stalemate" })
        else
            self.status = GameState.STATUS.PLAYING
            self.checked_side = nil
            self.checking_piece = nil
        end
    end
end

-- ============================================================
-- 悔棋（回退一步）
-- @return (boolean) 是否成功
-- ============================================================

function GameState:undo()
    if #self.history == 0 then
        return false
    end

    local last_move = table.remove(self.history)

    -- 把棋子移回去
    last_move.piece.x = last_move.from_x
    last_move.piece.y = last_move.from_y

    -- 被吃的棋子复活
    if last_move.captured then
        last_move.captured.alive = true
    end

    -- 回合切换回去
    self.current_turn = last_move.turn
    self.move_count = self.move_count - 1

    -- 重新计算状态
    self:_update_status()

    EventBus.emit("game:undo", last_move)

    return true
end

-- ============================================================
-- 重置游戏
-- ============================================================

function GameState:reset()
    self:init_default_board()
    EventBus.emit("game:reset")
end

-- ============================================================
-- 获取游戏结果（如果已结束）
-- @return (string|nil, string|nil) 胜者，原因
-- ============================================================

function GameState:get_winner()
    if self.status == GameState.STATUS.CHECKMATE then
        -- 被将军的一方输了，对方赢了
        local winner = (self.checked_side == "red") and "black" or "red"
        return winner, "checkmate"
    end
    if self.status == GameState.STATUS.DRAW then
        return nil, "draw"
    end
    return nil, nil
end

-- ============================================================
-- 检查游戏是否结束
-- ============================================================

function GameState:is_game_over()
    return self.status == GameState.STATUS.CHECKMATE or
           self.status == GameState.STATUS.DRAW or
           self.status == GameState.STATUS.STALEMATE
end

return GameState
