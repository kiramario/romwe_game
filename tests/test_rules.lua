-- 规则测试脚本
-- 直接用 LÖVE2D 运行，验证所有走法规则

function love.load()
    print("========== 象棋规则单元测试 ==========\n")

    local Piece = require("src.game.entities.piece")
    local Rules = require("src.game.systems.rules")
    local GameState = require("src.game.systems.game_state")

    local pass_count = 0
    local fail_count = 0

    local function test(name, condition, detail)
        if condition then
            pass_count = pass_count + 1
            print("  ✅ PASS: " .. name)
        else
            fail_count = fail_count + 1
            print("  ❌ FAIL: " .. name)
            if detail then
                print("     " .. tostring(detail))
            end
        end
    end

    -- ===== 测试 1: 车的走法 =====
    print("\n--- 车的走法 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        -- 找一个红方车 (1,10)
        local chariot = state:get_piece_at(1, 10)
        test("红方车初始位置存在", chariot ~= nil and chariot.type == "chariot")

        -- 初始位置车不能动（被马和兵挡住了）
        local moves = Rules.get_legal_moves(state.pieces, chariot)
        test("初始位置车没有可走步", #moves == 0, "实际有 " .. #moves .. " 步")
    end

    -- ===== 测试 2: 马的走法 =====
    print("\n--- 马的走法 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        -- 红方马 (2,10)
        local horse = state:get_piece_at(2, 10)
        test("红方马初始位置存在", horse ~= nil and horse.type == "horse")

        local moves = Rules.get_legal_moves(state.pieces, horse)
        -- 初始位置马应该有 2 步可走 (进一 和 进三)
        -- 即 (1,8) 和 (3,8) — 不对，马走日
        -- 从 (2,10) 出发，不被蹩腿的日字格：
        -- (1,8)? 不对，马走日=横1竖2或横2竖1
        -- (2,10) 往上走：(1,8)不对，应该是 (1,9) 和 (3,9)? 不，日字是 2+1
        -- 正确：(2,10) -> (1,8) 是横1竖2，对，日字
        -- (2,10) -> (3,8) 也是
        -- 但是 (3,10) 是象，不蹩马腿
        -- 蹩马腿的位置是前进方向紧邻的格
        -- 往上走两格的话，马腿在 (2,9)，位置是空的，可以走
        -- 所以应该有 2 步可走
        test("初始位置马有 2 步可走", #moves == 2, "实际有 " .. #moves .. " 步")
    end

    -- ===== 测试 3: 象的走法 =====
    print("\n--- 象的走法 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        local elephant = state:get_piece_at(3, 10)
        test("红方象初始位置存在", elephant ~= nil and elephant.type == "elephant")

        local moves = Rules.get_legal_moves(state.pieces, elephant)
        -- 象走田，从 (3,10) 可以走到 (1,8) 和 (5,8)
        -- 检查 (5,8) 位置有没有兵？兵在 y=7
        -- 象眼位置是 (4,9)，是空的，可以走
        -- 所以应该有 2 步
        test("初始位置象有 2 步可走", #moves == 2, "实际有 " .. #moves .. " 步")
    end

    -- ===== 测试 4: 士的走法 =====
    print("\n--- 士的走法 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        local advisor = state:get_piece_at(4, 10)
        test("红方士初始位置存在", advisor ~= nil and advisor.type == "advisor")

        local moves = Rules.get_legal_moves(state.pieces, advisor)
        -- 士在 (4,10)，只能走斜线到 (5,9)
        -- 九宫内：x 4-6, y 8-10
        -- (4,10) 走斜线：(5,9) 和 (3,9)? 不对，(3,9) 不在九宫内
        -- 九宫内从 (4,10) 斜着走一格是 (5,9)
        -- 等等，4->5 是 x+1, 10->9 是 y-1，斜走一格，对
        -- 只有 1 步
        test("初始位置士有 1 步可走", #moves == 1, "实际有 " .. #moves .. " 步")
    end

    -- ===== 测试 5: 将的走法 =====
    print("\n--- 将/帅的走法 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        local king = state:get_piece_at(5, 10)
        test("红方帅初始位置存在", king ~= nil and king.type == "king")

        local moves = Rules.get_legal_moves(state.pieces, king)
        -- 帅在 (5,10)，九宫内
        -- 可以走的方向：上 (5,9)、左 (4,10)、右 (6,10)
        -- 但左右都被士挡住了
        -- 所以只能往上走 1 步
        test("初始位置帅有 1 步可走", #moves == 1, "实际有 " .. #moves .. " 步")
    end

    -- ===== 测试 6: 炮的走法 =====
    print("\n--- 炮的走法 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        local cannon = state:get_piece_at(2, 8)
        test("红方炮初始位置存在", cannon ~= nil and cannon.type == "cannon")

        local moves = Rules.get_legal_moves(state.pieces, cannon)
        -- 炮在 (2,8)，初始位置
        -- 横向：左右都能走（横线没有棋子阻挡，除了自己方的）
        -- 左边到 (1,8)，右边... 中间有没有棋子？(3,8)? 没有
        -- 实际上炮在第二排，左右都可以走
        -- 竖向：往下是 (2,9)(2,10)，被马挡住了？(2,10)是马
        -- 炮不吃子时不能越子，所以往下只能到 (2,9)
        -- 往上：可以一直走到 y=1 吗？兵在 y=7，(2,7) 是兵
        -- 炮不吃子时不能越子，所以往上到 (2,7) 前面，也就是 (2,7) 有兵挡住
        -- 不对，炮不吃子的走法和车一样，不能越子
        -- (2,8) 往上：(2,7) 是兵，所以只能走到 (2,7)？不，不能走到有棋子的位置
        -- 炮不走吃的话，终点必须是空的，中间不能有子
        -- 所以从 (2,8) 往上走，被 (2,7) 的兵挡住了，一步也不能往上走
        -- 往下走：(2,9) 是空，(2,10) 是马，所以能走到 (2,9)

        -- 横向：左边 (1,8) 空，右边：(3,8)空, (4,8)空... 直到 (8,8)是另一个炮
        -- 所以横向能走很多步

        -- 简单验证：应该大于 1 步
        test("初始位置炮有可走步", #moves > 0, "实际有 " .. #moves .. " 步")
    end

    -- ===== 测试 7: 兵的走法 =====
    print("\n--- 兵/卒的走法 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        local pawn = state:get_piece_at(1, 7)
        test("红方兵初始位置存在", pawn ~= nil and pawn.type == "pawn")

        local moves = Rules.get_legal_moves(state.pieces, pawn)
        -- 兵没过河，只能前进 1 步
        -- 从 (1,7) 往前（y减小）到 (1,6)
        test("初始位置兵有 1 步可走", #moves == 1, "实际有 " .. #moves .. " 步")

        -- 验证兵不能横走（没过河）
        local can_move_side = false
        for _, m in ipairs(moves) do
            if m.x ~= pawn.x then
                can_move_side = true
            end
        end
        test("没过河的兵不能横走", not can_move_side)
    end

    -- ===== 测试 8: 兵过河后可以横走 =====
    print("\n--- 兵过河后 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        -- 手动把一个兵移过河（放到黑方境内）
        local pawn = state:get_piece_at(1, 7)
        pawn.x = 1
        pawn.y = 4  -- 放到黑方卒的下面一格？不，y=4 是黑方卒的位置
        -- 先把黑方卒移除
        local enemy_pawn = state:get_piece_at(1, 4)
        if enemy_pawn then
            enemy_pawn.alive = false
        end
        pawn.y = 4  -- 红方兵到 y=4，已经过河了（河在 y=5 和 y=6 之间）

        local moves = Rules.get_legal_moves(state.pieces, pawn)
        -- 过河的兵可以前进和左右走，共 3 个方向
        -- 从 (1,4)：上 (1,3)，右 (2,4) — 左边出界了
        -- 所以 2 步
        test("过河兵在边线有 2 步可走", #moves == 2, "实际有 " .. #moves .. " 步")

        -- 放到中间位置
        pawn.x = 5
        pawn.y = 4
        moves = Rules.get_legal_moves(state.pieces, pawn)
        -- 从 (5,4)：上 (5,3)，左 (4,4)，右 (6,4) — 3 步
        test("过河兵在中间有 3 步可走", #moves == 3, "实际有 " .. #moves .. " 步")

        -- 验证兵不能后退
        local can_back = false
        for _, m in ipairs(moves) do
            if m.y > pawn.y then  -- 红方兵y增大是后退
                can_back = true
            end
        end
        test("过河兵也不能后退", not can_back)
    end

    -- ===== 测试 9: 蹩马腿 =====
    print("\n--- 蹩马腿 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        -- 红方马在 (2,10)，往上走的马腿位置是 (2,9)
        -- 在 (2,9) 放一个棋子蹩马腿
        local horse = state:get_piece_at(2, 10)
        local moves_before = Rules.get_legal_moves(state.pieces, horse)

        -- 在马腿位置放个棋子（用一个兵挪过去）
        local pawn = state:get_piece_at(3, 7)
        pawn.x = 2
        pawn.y = 9

        local moves_after = Rules.get_legal_moves(state.pieces, horse)
        -- 蹩马腿后，向上跳的两个方向都被蹩了吗？
        -- 马在 (2,10)，马腿在 (2,9) — 这是纵向的马腿
        -- 影响的是纵向走两格的跳法：(1,8) 和 (3,8)
        -- 不对，(2,10) 到 (1,8) 是横1竖2，马腿在纵向也就是 (2,9)
        -- (2,10) 到 (3,8) 也是横1竖2，马腿同样是 (2,9)
        -- 所以蹩了之后应该 0 步可走？不对，马还有其他走法吗？
        -- 在初始位置马只能往上跳，往下是边界
        -- 所以蹩马腿后应该是 0 步
        test("蹩马腿后马走不了", #moves_after == 0,
            "蹩之前 " .. #moves_before .. " 步，蹩之后 " .. #moves_after .. " 步")
    end

    -- ===== 测试 10: 塞象眼 =====
    print("\n--- 塞象眼 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        local elephant = state:get_piece_at(3, 10)
        local moves_before = Rules.get_legal_moves(state.pieces, elephant)

        -- 象走田，从 (3,10) 到 (5,8)，象眼在 (4,9)
        -- 在象眼位置放个棋子
        local pawn = state:get_piece_at(3, 7)
        pawn.x = 4
        pawn.y = 9

        local moves_after = Rules.get_legal_moves(state.pieces, elephant)
        -- 塞象眼后，(5,8) 不能走了
        -- 还剩 (1,8) 可以走
        test("塞象眼后少了一步", #moves_after == 1,
            "塞之前 " .. #moves_before .. " 步，塞之后 " .. #moves_after .. " 步")
    end

    -- ===== 测试 11: 炮吃子 =====
    print("\n--- 炮吃子（隔山打牛） ---")
    do
        local state = GameState.new()
        state:init_default_board()

        local cannon = state:get_piece_at(2, 8)
        -- 炮初始位置能不能吃到对方的子？
        -- 炮在 (2,8)，黑方炮在 (2,3)，中间有兵在 (2,7) 和卒在 (2,4)
        -- 炮吃子需要恰好一个炮架
        -- 竖线上有：兵(2,7)、卒(2,4)、黑炮(2,3)、黑马(2,2)、黑车(2,1)
        -- 从 (2,8) 到 (2,4) 中间有几个子？(2,7)是兵，(2,6)(2,5)空
        -- 中间有 1 个子（兵），那可以吃卒吗？
        -- 等一下，(2,8) -> (2,4)，中间经过的是 y=7,6,5
        -- y=7 有兵，y=6,5 空
        -- 中间棋子数 = 1，正好是一个炮架
        -- 但终点是 (2,4) 卒，属于吃子情况
        -- 规则：吃子时必须恰好隔一个棋子
        -- 所以是可以的？不对，等一下...
        -- 炮在 (2,8)，卒在 (2,4)
        -- 中间的棋子：y=7 (红兵), y=6 (空), y=5 (空)
        -- 中间有 1 个棋子，正好可以炮打

        local can_capture_pawn = false
        local moves = Rules.get_valid_moves(state.pieces, cannon)
        for _, m in ipairs(moves) do
            if m.x == 2 and m.y == 4 then
                can_capture_pawn = true
            end
        end

        -- 等等，初始状态下 (2,4) 是黑方卒
        -- 炮从 (2,8) 打过去，中间有 (2,7) 红兵
        -- 中间恰好 1 个子，应该可以吃
        test("炮可以隔一个子吃卒", can_capture_pawn,
            "检查 (2,4) 是否在可走位置中")
    end

    -- ===== 测试 12: 将帅不能对面 =====
    print("\n--- 将帅对面 ---")
    do
        -- 创建一个极简棋盘，只有两个将
        local state = GameState.new()
        state.pieces = {}

        local red_king = Piece.new({ type = "king", side = "red", x = 5, y = 10 })
        local black_king = Piece.new({ type = "king", side = "black", x = 5, y = 1 })
        table.insert(state.pieces, red_king)
        table.insert(state.pieces, black_king)

        -- 红方将不能往前走到 (5,9)，因为会将帅对面
        local moves = Rules.get_legal_moves(state.pieces, red_king)
        local can_move_up = false
        for _, m in ipairs(moves) do
            if m.x == 5 and m.y == 9 then
                can_move_up = true
            end
        end
        test("将帅对面时不能往前走", not can_move_up,
            "检查 (5,9) 是否在可走位置中")
    end

    -- ===== 测试 13: 将军检测 =====
    print("\n--- 将军检测 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        -- 初始状态不应该被将军
        local in_check = Rules.is_in_check(state.pieces, "red")
        test("初始状态红方不被将军", not in_check)

        in_check = Rules.is_in_check(state.pieces, "black")
        test("初始状态黑方不被将军", not in_check)
    end

    -- ===== 测试 14: 走一步试试 =====
    print("\n--- 实际走棋 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        -- 红方马二进三 (2,10) -> (3,8)
        local horse = state:get_piece_at(2, 10)
        local success, reason = state:move(horse, 3, 8)
        test("红方马二进三成功", success, reason)

        -- 回合应该切换到黑方
        test("回合切换到黑方", state.current_turn == "black")

        -- 再走一步红方的，应该失败
        local success2, reason2 = state:move(horse, 4, 6)
        test("不是己方回合不能走", not success2, reason2)
    end

    -- ===== 测试 15: 悔棋 =====
    print("\n--- 悔棋 ---")
    do
        local state = GameState.new()
        state:init_default_board()

        -- 走一步
        local pawn = state:get_piece_at(1, 7)
        state:move(pawn, 1, 6)

        -- 悔棋
        local undo_success = state:undo()
        test("悔棋成功", undo_success)
        test("悔棋后回到红方回合", state.current_turn == "red")

        -- 兵应该回到原位
        local pawn2 = state:get_piece_at(1, 7)
        test("兵回到原位", pawn2 ~= nil)
    end

    -- ===== 汇总 =====
    print("\n========== 测试结果 ==========")
    print("通过: " .. pass_count)
    print("失败: " .. fail_count)
    print("总计: " .. (pass_count + fail_count))

    if fail_count == 0 then
        print("\n🎉 所有测试通过！")
    end

    love.event.quit(fail_count > 0 and 1 or 0)
end
