-- 模块名: rules
-- 功能: 中国象棋走法规则系统
-- 说明: 校验所有棋子的走法是否合法，计算可走位置
-- 这是纯逻辑模块，不负责渲染，只操作数据
-- 类比: 游戏规则引擎 / 业务逻辑层
--
-- 棋盘坐标系:
--   x: 1-9 (列，从左到右)
--   y: 1-10 (行，从上到下，黑方在上，红方在下)
--
-- 棋子类型: king, advisor, elephant, horse, chariot, cannon, pawn
-- 棋子颜色: red, black

local Core = require("src.core")
local Logger = Core.Logger

local Rules = {}

-- ============================================================
-- 内部工具函数
-- ============================================================

-- 获取指定位置的棋子
-- @param pieces (table) 棋子列表
-- @param x, y (number) 棋盘坐标
-- @return (Piece|nil)
local function get_piece_at(pieces, x, y)
    for _, p in ipairs(pieces) do
        if p.alive and p.x == x and p.y == y then
            return p
        end
    end
    return nil
end

-- 检查坐标是否在棋盘内
local function is_on_board(x, y)
    return x >= 1 and x <= 9 and y >= 1 and y <= 10
end

-- 检查是否在九宫内
-- @param side (string) "red" 或 "black"
local function is_in_fortress(x, y, side)
    if x < 4 or x > 6 then return false end
    if side == "black" then
        return y >= 1 and y <= 3
    else
        return y >= 8 and y <= 10
    end
end

-- 检查是否过河（从某方的视角看）
local function has_crossed_river(y, side)
    if side == "red" then
        return y <= 5  -- 红方棋子往上走，y <= 5 表示过了河
    else
        return y >= 6  -- 黑方棋子往下走，y >= 6 表示过了河
    end
end

-- 统计两个位置之间的棋子数量（用于车和炮的走法）
-- 只能是直线（横或竖）
-- @param x1, y1 (number) 起点
-- @param x2, y2 (number) 终点
-- @param pieces (table) 所有棋子
-- @return (number) 中间棋子数量，如果不是直线返回 -1
local function count_pieces_between(x1, y1, x2, y2, pieces)
    local count = 0

    if x1 == x2 then
        -- 竖线
        local y_start = math.min(y1, y2) + 1
        local y_end = math.max(y1, y2) - 1
        for y = y_start, y_end do
            if get_piece_at(pieces, x1, y) then
                count = count + 1
            end
        end
        return count

    elseif y1 == y2 then
        -- 横线
        local x_start = math.min(x1, x2) + 1
        local x_end = math.max(x1, x2) - 1
        for x = x_start, x_end do
            if get_piece_at(pieces, x, y1) then
                count = count + 1
            end
        end
        return count
    end

    -- 不是直线
    return -1
end

-- ============================================================
-- 各棋子的走法校验
-- ============================================================

-- 将/帅：
--   - 只能在九宫内走
--   - 每次走一格（上下左右）
--   - 将帅不能对面（中间没有棋子遮挡时不能在同一条竖线上）
local function validate_king(piece, to_x, to_y, pieces)
    local x, y = piece.x, piece.y
    local side = piece.side

    -- 1. 必须在九宫内
    if not is_in_fortress(to_x, to_y, side) then
        return false, "将/帅不能出九宫"
    end

    -- 2. 每次只能走一格（横或竖）
    local dx = math.abs(to_x - x)
    local dy = math.abs(to_y - y)
    if (dx == 1 and dy == 0) or (dx == 0 and dy == 1) then
        -- 走法合法，继续检查将帅对面
    else
        return false, "将/帅每次只能走一格（横或竖）"
    end

    -- 3. 目标位置不能有己方棋子
    local target = get_piece_at(pieces, to_x, to_y)
    if target and target.side == side then
        return false, "目标位置有己方棋子"
    end

    -- 4. 检查将帅对面（飞将规则）
    -- 模拟走这一步，然后看将帅是否对面
    -- 先找到对方的将
    local enemy_king = nil
    for _, p in ipairs(pieces) do
        if p.alive and p.type == "king" and p.side ~= side then
            enemy_king = p
            break
        end
    end

    if enemy_king then
        -- 模拟移动后我方将的位置
        local my_king_new_x = to_x
        local my_king_new_y = to_y

        -- 检查是否在同一竖线上
        if my_king_new_x == enemy_king.x then
            -- 检查中间有没有棋子
            -- 注意：如果目标位置就是对方将的位置，那就是飞将吃将，应该允许？
            -- 不对，中国象棋将帅不能直接对面，但可以"飞将"吃对方的将
            -- 实际上：将帅不能对面指的是不能主动走到与对方将帅对面的位置
            -- 但如果能吃掉对方将帅，那当然是可以的（直接获胜）

            -- 如果目标就是对方将的位置，那是吃将，应该允许（胜利条件）
            if to_x == enemy_king.x and to_y == enemy_king.y then
                return true, "飞将吃将！"
            end

            -- 否则检查中间棋子数
            local between = count_pieces_between(
                my_king_new_x, my_king_new_y,
                enemy_king.x, enemy_king.y,
                pieces
            )
            -- 注意：count_pieces_between 不包含起点和终点
            -- 这里要注意：如果我们的将移动了，需要把原位置的将"移除"再数
            -- 简单处理：原位置的将不在中间，因为 y1 和 y2 是两个端点
            -- 但是对方的将也在端点，也不算中间
            -- 所以 count_pieces_between 的结果就是中间棋子数
            if between == 0 then
                -- 中间没有棋子，将帅对面了
                return false, "将帅不能对面"
            end
        end
    end

    return true
end

-- 士/仕：
--   - 只能在九宫内走
--   - 每次走斜线一格
local function validate_advisor(piece, to_x, to_y, pieces)
    local x, y = piece.x, piece.y
    local side = piece.side

    -- 1. 必须在九宫内
    if not is_in_fortress(to_x, to_y, side) then
        return false, "士/仕不能出九宫"
    end

    -- 2. 走斜线一格
    local dx = math.abs(to_x - x)
    local dy = math.abs(to_y - y)
    if dx ~= 1 or dy ~= 1 then
        return false, "士/仕只能走斜线一格"
    end

    -- 3. 目标位置不能有己方棋子
    local target = get_piece_at(pieces, to_x, to_y)
    if target and target.side == side then
        return false, "目标位置有己方棋子"
    end

    return true
end

-- 象/相：
--   - 走田字（斜着走两格）
--   - 不能过河
--   - 塞象眼：田字中心有棋子则不能走
local function validate_elephant(piece, to_x, to_y, pieces)
    local x, y = piece.x, piece.y
    local side = piece.side

    -- 1. 不能过河
    if has_crossed_river(to_y, side) then
        return false, "象/相不能过河"
    end

    -- 2. 走田字（横向两格 + 纵向两格）
    local dx = math.abs(to_x - x)
    local dy = math.abs(to_y - y)
    if dx ~= 2 or dy ~= 2 then
        return false, "象/相走田字"
    end

    -- 3. 塞象眼：田字中心（起点和终点的中点）有棋子
    local eye_x = x + (to_x - x) / 2
    local eye_y = y + (to_y - y) / 2
    if get_piece_at(pieces, eye_x, eye_y) then
        return false, "塞象眼"
    end

    -- 4. 目标位置不能有己方棋子
    local target = get_piece_at(pieces, to_x, to_y)
    if target and target.side == side then
        return false, "目标位置有己方棋子"
    end

    return true
end

-- 马：
--   - 走日字（一横一斜或一竖一斜）
--   - 蹩马腿：马前进方向的紧邻位置有棋子则不能走
local function validate_horse(piece, to_x, to_y, pieces)
    local x, y = piece.x, piece.y
    local side = piece.side

    -- 1. 走日字
    local dx = math.abs(to_x - x)
    local dy = math.abs(to_y - y)
    -- 日字：横向 1 + 纵向 2，或者横向 2 + 纵向 1
    if not ((dx == 1 and dy == 2) or (dx == 2 and dy == 1)) then
        return false, "马走日字"
    end

    -- 2. 蹩马腿
    -- 马腿位置：马往哪个方向跳，那个方向的紧邻格子就是马腿
    -- 比如：向右上(+2, +1)跳，马腿位置是 (+1, 0)
    --       向上右(+1, +2)跳，马腿位置是 (0, +1)
    local leg_x, leg_y
    if dx == 2 then
        -- 横向走两格，马腿在横向中间
        leg_x = x + (to_x - x) / 2
        leg_y = y
    else
        -- 纵向走两格，马腿在纵向中间
        leg_x = x
        leg_y = y + (to_y - y) / 2
    end

    if get_piece_at(pieces, leg_x, leg_y) then
        return false, "蹩马腿"
    end

    -- 3. 目标位置不能有己方棋子
    local target = get_piece_at(pieces, to_x, to_y)
    if target and target.side == side then
        return false, "目标位置有己方棋子"
    end

    return true
end

-- 车/車：
--   - 横竖直走，格数不限
--   - 不能越子（中间有棋子挡住就不能过去）
local function validate_chariot(piece, to_x, to_y, pieces)
    local x, y = piece.x, piece.y
    local side = piece.side

    -- 1. 必须走直线（横或竖）
    if x ~= to_x and y ~= to_y then
        return false, "车只能走直线"
    end

    -- 2. 不能原地不动
    if x == to_x and y == to_y then
        return false, "不能原地不动"
    end

    -- 3. 中间不能有棋子
    local between = count_pieces_between(x, y, to_x, to_y, pieces)
    if between > 0 then
        return false, "车不能越子"
    end

    -- 4. 目标位置不能有己方棋子
    local target = get_piece_at(pieces, to_x, to_y)
    if target and target.side == side then
        return false, "目标位置有己方棋子"
    end

    return true
end

-- 炮/砲：
--   - 走法同车（横竖直走，格数不限，不能越子）
--   - 吃子必须隔一个棋子（炮架）
--   - 不吃子时不能吃子，中间也不能有棋子
local function validate_cannon(piece, to_x, to_y, pieces)
    local x, y = piece.x, piece.y
    local side = piece.side

    -- 1. 必须走直线
    if x ~= to_x and y ~= to_y then
        return false, "炮只能走直线"
    end

    -- 2. 不能原地不动
    if x == to_x and y == to_y then
        return false, "不能原地不动"
    end

    -- 3. 检查目标位置
    local target = get_piece_at(pieces, to_x, to_y)
    local between = count_pieces_between(x, y, to_x, to_y, pieces)

    if target then
        -- 吃子的情况
        if target.side == side then
            return false, "目标位置有己方棋子"
        end
        -- 吃子必须恰好隔一个棋子（炮架）
        if between ~= 1 then
            return false, "炮吃子需要隔一个棋子"
        end
        return true
    else
        -- 不吃子的情况：中间不能有棋子
        if between > 0 then
            return false, "炮不吃子时不能越子"
        end
        return true
    end
end

-- 兵/卒：
--   - 每次前进一格
--   - 不能后退
--   - 过河后可以横走
local function validate_pawn(piece, to_x, to_y, pieces)
    local x, y = piece.x, piece.y
    local side = piece.side

    -- 1. 只能走一格
    local dx = math.abs(to_x - x)
    local dy = math.abs(to_y - y)

    -- 总移动距离必须是 1 格（横或竖）
    if (dx + dy) ~= 1 then
        return false, "兵/卒每次只能走一格"
    end

    -- 2. 不能后退
    if side == "red" then
        -- 红方兵往上走（y 减小），不能往下走
        if to_y > y then
            return false, "兵不能后退"
        end
    else
        -- 黑方卒往下走（y 增大），不能往上走
        if to_y < y then
            return false, "卒不能后退"
        end
    end

    -- 3. 过河前不能横走
    -- 如果是横向移动，检查是否已过河
    if dx == 1 then
        if not has_crossed_river(y, side) then
            return false, "兵/卒过河前不能横走"
        end
    end

    -- 4. 目标位置不能有己方棋子
    local target = get_piece_at(pieces, to_x, to_y)
    if target and target.side == side then
        return false, "目标位置有己方棋子"
    end

    return true
end

-- ============================================================
-- 公开 API：校验一步棋
-- ============================================================

-- 校验走法是否合法
-- @param pieces (table) 所有棋子列表
-- @param piece (Piece) 要移动的棋子
-- @param to_x, to_y (number) 目标位置
-- @return (boolean, string) 是否合法，以及原因
function Rules.validate_move(pieces, piece, to_x, to_y)
    -- 1. 基本检查：坐标在棋盘内
    if not is_on_board(to_x, to_y) then
        return false, "目标位置超出棋盘"
    end

    -- 2. 不能原地不动
    if piece.x == to_x and piece.y == to_y then
        return false, "不能原地不动"
    end

    -- 3. 根据棋子类型调用对应校验
    local valid, reason
    if piece.type == "king" then
        valid, reason = validate_king(piece, to_x, to_y, pieces)
    elseif piece.type == "advisor" then
        valid, reason = validate_advisor(piece, to_x, to_y, pieces)
    elseif piece.type == "elephant" then
        valid, reason = validate_elephant(piece, to_x, to_y, pieces)
    elseif piece.type == "horse" then
        valid, reason = validate_horse(piece, to_x, to_y, pieces)
    elseif piece.type == "chariot" then
        valid, reason = validate_chariot(piece, to_x, to_y, pieces)
    elseif piece.type == "cannon" then
        valid, reason = validate_cannon(piece, to_x, to_y, pieces)
    elseif piece.type == "pawn" then
        valid, reason = validate_pawn(piece, to_x, to_y, pieces)
    else
        return false, "未知棋子类型: " .. tostring(piece.type)
    end

    return valid, reason or ""
end

-- ============================================================
-- 公开 API：获取一个棋子的所有可走位置
-- ============================================================

-- 获取棋子的所有合法走法
-- @param pieces (table) 所有棋子
-- @param piece (Piece) 要计算的棋子
-- @return (table) { {x, y, reason}, ... } 所有合法目标位置
function Rules.get_valid_moves(pieces, piece)
    local moves = {}

    -- 遍历棋盘上所有位置，检查是否合法
    -- 9x10 = 90 个位置，对性能完全没压力
    for x = 1, 9 do
        for y = 1, 10 do
            local valid, reason = Rules.validate_move(pieces, piece, x, y)
            if valid then
                table.insert(moves, { x = x, y = y, reason = reason })
            end
        end
    end

    return moves
end

-- ============================================================
-- 公开 API：检查某方是否被将军
-- ============================================================

-- 检查指定方是否被将军
-- @param pieces (table) 所有棋子
-- @param side (string) "red" 或 "black"，即被检查的一方
-- @return (boolean, Piece|nil) 是否被将军，以及将军的棋子
function Rules.is_in_check(pieces, side)
    -- 找到被检查方的将
    local king = nil
    for _, p in ipairs(pieces) do
        if p.alive and p.type == "king" and p.side == side then
            king = p
            break
        end
    end

    if not king then
        -- 没有将？那已经输了...
        return true, nil
    end

    -- 检查对方每个棋子是否能吃到将
    for _, p in ipairs(pieces) do
        if p.alive and p.side ~= side then
            local valid, reason = Rules.validate_move(pieces, p, king.x, king.y)
            if valid then
                return true, p
            end
        end
    end

    return false, nil
end

-- ============================================================
-- 公开 API：检查某方是否将死（输了）
-- ============================================================

-- 检查指定方是否被将死
-- @param pieces (table) 所有棋子
-- @param side (string) "red" 或 "black"
-- @return (boolean) 是否被将死
function Rules.is_checkmate(pieces, side)
    -- 首先得被将军
    if not Rules.is_in_check(pieces, side) then
        return false
    end

    -- 检查这方所有棋子的所有走法
    -- 只要有任何一步能解除将军，就没被将死
    for _, piece in ipairs(pieces) do
        if piece.alive and piece.side == side then
            local moves = Rules.get_valid_moves(pieces, piece)
            for _, move in ipairs(moves) do
                -- 模拟走这一步，看是否还被将军
                local simulated = Rules.simulate_move(pieces, piece, move.x, move.y)
                if not Rules.is_in_check(simulated, side) then
                    -- 有办法解将
                    return false
                end
            end
        end
    end

    -- 所有走法都不能解将，被将死了
    return true
end

-- ============================================================
-- 公开 API：模拟走一步（用于推演，不修改原数据）
-- ============================================================

-- 模拟走一步棋，返回新的棋子列表（不修改原数据）
-- @param pieces (table) 原始棋子列表
-- @param piece (Piece) 要移动的棋子
-- @param to_x, to_y (number) 目标位置
-- @return (table) 新的棋子列表（每个棋子都是克隆的）
function Rules.simulate_move(pieces, piece, to_x, to_y)
    local new_pieces = {}

    for _, p in ipairs(pieces) do
        local cloned = p:clone()

        if cloned.x == piece.x and cloned.y == piece.y then
            -- 这是要移动的棋子
            cloned.x = to_x
            cloned.y = to_y
        elseif cloned.x == to_x and cloned.y == to_y then
            -- 这是被吃掉的棋子
            cloned.alive = false
        end

        table.insert(new_pieces, cloned)
    end

    return new_pieces
end

-- ============================================================
-- 公开 API：检查一步棋是否会导致自己被将军（禁手）
-- ============================================================

-- 检查走这步后自己是否会被将军
-- 用于防止"送将"——不能走一步让自己被将军
-- @param pieces (table) 所有棋子
-- @param piece (Piece) 要移动的棋子
-- @param to_x, to_y (number) 目标位置
-- @return (boolean) 是否会被将军
function Rules.would_be_in_check(pieces, piece, to_x, to_y)
    local simulated = Rules.simulate_move(pieces, piece, to_x, to_y)
    return Rules.is_in_check(simulated, piece.side)
end

-- ============================================================
-- 公开 API：获取合法且不送将的走法
-- ============================================================

-- 获取棋子所有真正合法的走法（排除送将的走法）
-- 这是实际对局中应该使用的函数
-- @param pieces (table) 所有棋子
-- @param piece (Piece) 棋子
-- @return (table) 合法走法列表
function Rules.get_legal_moves(pieces, piece)
    local all_moves = Rules.get_valid_moves(pieces, piece)
    local legal_moves = {}

    for _, move in ipairs(all_moves) do
        if not Rules.would_be_in_check(pieces, piece, move.x, move.y) then
            table.insert(legal_moves, move)
        end
    end

    return legal_moves
end

Logger.info("Rules: module loaded")

return Rules
