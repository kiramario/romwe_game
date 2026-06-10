-- 模块名: ai
-- 功能: AI 对手
-- 说明: 中国象棋 AI，使用极小化极大算法 + α-β 剪枝
-- 类比: 博弈 AI / 棋类 AI 的标准实现
--
-- 算法说明:
--   极小化极大 (Minimax): 假设双方都走最优步，我方最大化得分，对方最小化得分
--   α-β 剪枝: 剪枝不可能影响结果的分支，大幅提高搜索效率
--   评估函数: 棋子价值 + 位置价值 + 机动性 + 将军威胁
--
-- 难度等级:
--   easy:   深度 1，只看一步，随机一点
--   normal: 深度 2，看两步，比较稳
--   hard:   深度 3，看三步，有一定水平
--   expert: 深度 4，看四步，比较强
--
-- 注意: 这是纯逻辑模块，不依赖渲染

local Core = require("src.core")
local Logger = Core.Logger
local Utils = Core.Utils

local Rules = require("src.game.systems.rules")

local AI = {}

-- ============================================================
-- 棋子基础价值（中国象棋标准分值）
-- ============================================================

local PIECE_VALUE = {
    king      = 10000,  -- 将帅，不能丢
    chariot   = 900,    -- 车
    cannon    = 450,    -- 炮
    horse     = 400,    -- 马
    elephant  = 200,    -- 象
    advisor   = 200,    -- 士
    pawn      = 100,    -- 兵/卒
}

-- 兵过河后的价值加成
local PAWN_CROSSED_BONUS = 100

-- ============================================================
-- 位置价值表（PST - Piece Square Table）
-- 数值越大对红方越有利
-- ============================================================

-- 马的位置价值（中心马比边马好）
local HORSE_PST = {
    { 20,  40,  60,  50,  40,  50,  60,  40,  20},
    { 30,  60,  90,  80,  70,  80,  90,  60,  30},
    { 40,  70, 100,  90,  80,  90, 100,  70,  40},
    { 50,  80, 110, 100,  90, 100, 110,  80,  50},
    { 60,  90, 120, 110, 100, 110, 120,  90,  60},
    { 60,  90, 120, 110, 100, 110, 120,  90,  60},
    { 50,  80, 110, 100,  90, 100, 110,  80,  50},
    { 40,  70, 100,  90,  80,  90, 100,  70,  40},
    { 30,  60,  90,  80,  70,  80,  90,  60,  30},
    { 20,  40,  60,  50,  40,  50,  60,  40,  20},
}

-- 车的位置价值（车在要道上价值高）
local CHARIOT_PST = {
    { 80,  90,  95,  90,  92,  90,  95,  90,  80},
    { 85,  95, 100,  95,  98,  95, 100,  95,  85},
    { 85,  95, 100,  95,  98,  95, 100,  95,  85},
    { 85,  95, 100,  95,  98,  95, 100,  95,  85},
    { 85,  95, 100,  95,  98,  95, 100,  95,  85},
    { 85,  95, 100,  95,  98,  95, 100,  95,  85},
    { 85,  95, 100,  95,  98,  95, 100,  95,  85},
    { 85,  95, 100,  95,  98,  95, 100,  95,  85},
    { 85,  95, 100,  95,  98,  95, 100,  95,  85},
    { 80,  90,  95,  90,  92,  90,  95,  90,  80},
}

-- 炮的位置价值
local CANNON_PST = {
    { 60,  70,  80,  75,  70,  75,  80,  70,  60},
    { 65,  75,  85,  80,  75,  80,  85,  75,  65},
    { 70,  80,  90,  85,  80,  85,  90,  80,  70},
    { 75,  85,  95,  90,  85,  90,  95,  85,  75},
    { 80,  90, 100,  95,  90,  95, 100,  90,  80},
    { 80,  90, 100,  95,  90,  95, 100,  90,  80},
    { 75,  85,  95,  90,  85,  90,  95,  85,  75},
    { 70,  80,  90,  85,  80,  85,  90,  80,  70},
    { 65,  75,  85,  80,  75,  80,  85,  75,  65},
    { 60,  70,  80,  75,  70,  75,  80,  70,  60},
}

-- 兵卒的位置价值（越往前越有威胁）
local PAWN_PST = {
    {  0,   0,   0,   0,   0,   0,   0,   0,   0},
    {  0,   0,   0,   0,   0,   0,   0,   0,   0},
    {  0,   0,   0,   0,   0,   0,   0,   0,   0},
    {  0,   0,   0,   0,   0,   0,   0,   0,   0},
    {  0,   0,   0,   0,   0,   0,   0,   0,   0},
    { 90, 110, 120, 130, 140, 130, 120, 110,  90},  -- 刚过河
    { 80,  90, 100, 110, 120, 110, 100,  90,  80},
    { 70,  80,  90, 100, 110, 100,  90,  80,  70},
    { 60,  70,  80,  90, 100,  90,  80,  70,  60},
    { 50,  60,  70,  80,  90,  80,  70,  60,  50},  -- 底线兵（最没用）
}

-- 注意: 上面的 PST 是红方视角（y=10 是红方底线）
-- 黑方的话，PST 需要翻转

-- ============================================================
-- 辅助函数: 获取位置价值
-- ============================================================

local function _get_pos_value(piece_type, x, y, side)
    local pst

    if piece_type == "horse" then
        pst = HORSE_PST
    elseif piece_type == "chariot" then
        pst = CHARIOT_PST
    elseif piece_type == "cannon" then
        pst = CANNON_PST
    elseif piece_type == "pawn" then
        pst = PAWN_PST
    else
        return 0  -- 其他棋子暂时不用 PST
    end

    if side == "red" then
        return pst[y][x]
    else
        -- 黑方：翻转 y 坐标
        local flipped_y = 11 - y  -- y=1 <-> y=10, y=5 <-> y=6
        return pst[flipped_y][x]
    end
end

-- ============================================================
-- 评估函数
-- 返回正数对红方有利，负数对黑方有利
-- @param pieces (table) 棋子列表
-- @return (number) 评估分数
-- ============================================================

function AI.evaluate(pieces)
    local score = 0

    for _, piece in ipairs(pieces) do
        if piece.alive then
            local base_value = PIECE_VALUE[piece.type] or 0
            local pos_value = _get_pos_value(piece.type, piece.x, piece.y, piece.side)

            -- 兵过河加成
            if piece.type == "pawn" then
                if piece.side == "red" and piece.y <= 5 then
                    base_value = base_value + PAWN_CROSSED_BONUS
                elseif piece.side == "black" and piece.y >= 6 then
                    base_value = base_value + PAWN_CROSSED_BONUS
                end
            end

            local piece_score = base_value + pos_value

            if piece.side == "red" then
                score = score + piece_score
            else
                score = score - piece_score
            end
        end
    end

    -- 机动性加成（可选，暂不加，留个口子）
    -- local mobility = _evaluate_mobility(pieces)
    -- score = score + mobility * 2

    return score
end

-- ============================================================
-- 获取所有合法走法
-- @param pieces (table) 棋子列表
-- @param side (string) 哪一方 "red" 或 "black"
-- @return (table) 走法列表，每个元素 {piece, to_x, to_y, captured}
-- ============================================================

function AI.get_all_moves(pieces, side)
    local moves = {}

    for _, piece in ipairs(pieces) do
        if piece.alive and piece.side == side then
            local valid_moves = Rules.get_legal_moves(pieces, piece)
            for _, m in ipairs(valid_moves) do
                -- 检查这步是否会让己方被将军（非法走法）
                -- Rules.get_legal_moves 已经做了这个检查
                table.insert(moves, {
                    piece = piece,
                    from_x = piece.x,
                    from_y = piece.y,
                    to_x = m.x,
                    to_y = m.y,
                    captured = m.captured,
                })
            end
        end
    end

    return moves
end

-- ============================================================
-- 走一步（用于搜索时推演）
-- 返回撤销这步所需的信息
-- ============================================================

local function _make_move(pieces, move)
    local piece = move.piece
    local old_x = piece.x
    local old_y = piece.y

    -- 找到被吃的棋子
    local captured = nil
    for _, p in ipairs(pieces) do
        if p.alive and p.x == move.to_x and p.y == move.to_y then
            captured = p
            break
        end
    end

    -- 执行移动
    piece.x = move.to_x
    piece.y = move.to_y

    if captured then
        captured.alive = false
    end

    -- 返回撤销信息
    return {
        piece = piece,
        old_x = old_x,
        old_y = old_y,
        captured = captured,
    }
end

-- 撤销一步
local function _undo_move(pieces, info)
    info.piece.x = info.old_x
    info.piece.y = info.old_y

    if info.captured then
        info.captured.alive = true
    end
end

-- ============================================================
-- 极小化极大 + α-β 剪枝
--
-- @param pieces (table) 棋子列表
-- @param depth (number) 剩余搜索深度
-- @param alpha (number) α 值（最大值的下界）
-- @param beta (number) β 值（最小值的上界）
-- @param is_maximizing (boolean) 当前是否是最大化层（红方走棋）
-- @return (number) 评估分数
-- ============================================================

function AI.minimax(pieces, depth, alpha, beta, is_maximizing)
    -- 达到深度上限，评估局面
    if depth == 0 then
        return AI.evaluate(pieces)
    end

    local side = is_maximizing and "red" or "black"
    local moves = AI.get_all_moves(pieces, side)

    -- 没有合法走法 = 将死或困毙
    if #moves == 0 then
        if Rules.is_in_check(pieces, side) then
            -- 将死，分数很大（或很小）
            if is_maximizing then
                return -99999 - depth  -- 红方被将死，很差
            else
                return 99999 + depth   -- 黑方被将死，很好
            end
        else
            -- 困毙，和棋
            return 0
        end
    end

    if is_maximizing then
        -- 最大化层（红方）
        local max_eval = -math.huge

        for _, move in ipairs(moves) do
            local info = _make_move(pieces, move)
            local eval = AI.minimax(pieces, depth - 1, alpha, beta, false)
            _undo_move(pieces, info)

            if eval > max_eval then
                max_eval = eval
            end
            alpha = math.max(alpha, eval)
            if beta <= alpha then
                break  -- β 剪枝
            end
        end

        return max_eval
    else
        -- 最小化层（黑方）
        local min_eval = math.huge

        for _, move in ipairs(moves) do
            local info = _make_move(pieces, move)
            local eval = AI.minimax(pieces, depth - 1, alpha, beta, true)
            _undo_move(pieces, info)

            if eval < min_eval then
                min_eval = eval
            end
            beta = math.min(beta, eval)
            if beta <= alpha then
                break  -- α 剪枝
            end
        end

        return min_eval
    end
end

-- ============================================================
-- 找最佳走法
--
-- @param pieces (table) 棋子列表
-- @param side (string) 哪一方走棋
-- @param difficulty (string) 难度
-- @return (table) 最佳走法 {piece, from_x, from_y, to_x, to_y, captured}
-- ============================================================

function AI.find_best_move(pieces, side, difficulty)
    difficulty = difficulty or "normal"

    -- 根据难度决定搜索深度
    local depth
    if difficulty == "easy" then
        depth = 1
    elseif difficulty == "hard" then
        depth = 3
    elseif difficulty == "expert" then
        depth = 4
    else
        depth = 2  -- normal
    end

    local moves = AI.get_all_moves(pieces, side)

    if #moves == 0 then
        return nil  -- 无子可走
    end

    -- 简单难度加一点随机性，不要每次都一样
    if difficulty == "easy" then
        -- 30% 概率走随机步
        if math.random() < 0.3 then
            local idx = math.random(1, #moves)
            Logger.debugf("AI: easy mode random move")
            return moves[idx]
        end
    end

    local is_maximizing = (side == "red")
    local best_score = is_maximizing and -math.huge or math.huge
    local best_moves = {}  -- 收集所有得分相同的最佳走法，随机选一个

    -- 走法排序（吃子的优先搜索，可以提高剪枝效率）
    table.sort(moves, function(a, b)
        local a_capture = a.captured and PIECE_VALUE[a.captured.type] or 0
        local b_capture = b.captured and PIECE_VALUE[b.captured.type] or 0
        return a_capture > b_capture
    end)

    for _, move in ipairs(moves) do
        local info = _make_move(pieces, move)
        local score = AI.minimax(pieces, depth - 1, -math.huge, math.huge, not is_maximizing)
        _undo_move(pieces, info)

        if is_maximizing then
            if score > best_score then
                best_score = score
                best_moves = {move}
            elseif score == best_score then
                table.insert(best_moves, move)
            end
        else
            if score < best_score then
                best_score = score
                best_moves = {move}
            elseif score == best_score then
                table.insert(best_moves, move)
            end
        end
    end

    -- 从最佳走法中随机选一个，增加变化
    local best_move = best_moves[math.random(1, #best_moves)]

    Logger.debugf("AI: found best move for %s (depth=%d), score=%.0f, %d best moves",
        side, depth, best_score, #best_moves)

    if best_move then
        Logger.debugf("AI: move %s from (%d,%d) to (%d,%d)",
            best_move.piece.type,
            best_move.from_x, best_move.from_y,
            best_move.to_x, best_move.to_y)
    end

    return best_move, best_score
end

-- ============================================================
-- 难度列表
-- ============================================================

AI.DIFFICULTIES = {
    {id = "easy",   name = "简单", desc = "适合新手入门"},
    {id = "normal", name = "普通", desc = "有一定挑战"},
    {id = "hard",   name = "困难", desc = "需要认真思考"},
    {id = "expert", name = "专家", desc = "水平很高"},
}

return AI
