-- 模块名: save_load
-- 功能: 存档/读档系统
-- 说明: 保存和读取游戏进度、棋谱、设置
-- 类比: 游戏存档系统 / 序列化与反序列化
--
-- 存档格式:
--   - version: 存档版本号
--   - timestamp: 保存时间戳
--   - moves: 走法列表，每一步 {from_x, from_y, to_x, to_y, piece_type, captured_type}
--   - current_turn: 当前回合
--   - status: 游戏状态
--
-- 存档位置: love.filesystem 的 save 目录
--   Windows: %APPDATA%/LOVE/<game_name>/
--   Linux: ~/.local/share/love/<game_name>/
--   macOS: ~/Library/Application Support/LOVE/<game_name>/

local Core = require("src.core")
local Logger = Core.Logger
local Utils = Core.Utils

local GameState = require("src.game.systems.game_state")

local SaveLoad = {}

-- 存档版本
local SAVE_VERSION = 1

-- 最大存档槽位
local MAX_SLOTS = 5

-- ============================================================
-- 内部辅助: 序列化 Lua table 为字符串
-- 简单的序列化，只支持基本类型（number, string, boolean, table）
-- 类比: JSON.stringify
-- ============================================================

local function _serialize(val, indent)
    indent = indent or 0
    local t = type(val)

    if t == "number" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "nil" then
        return "nil"
    elseif t == "table" then
        local lines = {}
        local pad = string.rep("  ", indent)
        local inner_pad = string.rep("  ", indent + 1)

        table.insert(lines, "{")

        -- 检查是否是数组（从 1 开始的连续整数键）
        local is_array = true
        local max_index = 0
        for k, _ in pairs(val) do
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                is_array = false
                break
            end
            if k > max_index then max_index = k end
        end

        if is_array then
            for i = 1, max_index do
                if val[i] ~= nil then
                    table.insert(lines, inner_pad .. _serialize(val[i], indent + 1) .. ",")
                end
            end
        else
            for k, v in pairs(val) do
                local key_str
                if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                    key_str = k
                else
                    key_str = "[" .. _serialize(k) .. "]"
                end
                table.insert(lines, inner_pad .. key_str .. " = " .. _serialize(v, indent + 1) .. ",")
            end
        end

        table.insert(lines, pad .. "}")
        return table.concat(lines, "\n")
    else
        return "nil"  -- 不支持的类型
    end
end

-- ============================================================
-- 内部辅助: 反序列化字符串为 Lua table
-- 用 loadstring / load 执行，注意安全性
-- 类比: JSON.parse
-- ============================================================

local function _deserialize(str)
    -- 在沙箱环境中执行，避免安全问题
    local chunk, err = load("return " .. str, "save_data", "t", {})
    if not chunk then
        return nil, "parse error: " .. tostring(err)
    end

    local ok, result = pcall(chunk)
    if not ok then
        return nil, "runtime error: " .. tostring(result)
    end

    return result
end

-- ============================================================
-- 获取存档文件名
-- ============================================================

local function _slot_filename(slot)
    return string.format("save/slot_%d.save", slot)
end

-- ============================================================
-- 保存游戏
-- @param game_state (GameState) 游戏状态
-- @param slot (number) 存档槽位 1-MAX_SLOTS
-- @return (boolean, string) 是否成功，错误信息
-- ============================================================

function SaveLoad.save_game(game_state, slot)
    slot = slot or 1

    if slot < 1 or slot > MAX_SLOTS then
        return false, "Invalid slot: " .. slot
    end

    -- 收集走法历史
    local moves = {}
    for _, record in ipairs(game_state.history) do
        table.insert(moves, {
            fx = record.from_x,
            fy = record.from_y,
            tx = record.to_x,
            ty = record.to_y,
            pt = record.piece.type,
            ps = record.piece.side,
            ct = record.captured and record.captured.type or nil,
            cs = record.captured and record.captured.side or nil,
        })
    end

    local save_data = {
        version = SAVE_VERSION,
        timestamp = os.time(),
        date_str = os.date("%Y-%m-%d %H:%M:%S"),
        slot = slot,
        current_turn = game_state.current_turn,
        status = game_state.status,
        move_count = #moves,
        moves = moves,
        -- 也保存初始局面（默认开局的话可以不用，但为了兼容性还是存一下）
        initial_board = "default",
    }

    -- 序列化
    local data_str = "return " .. _serialize(save_data)

    -- 确保 save 目录存在
    if not love.filesystem.getInfo("save") then
        local ok = love.filesystem.createDirectory("save")
        if not ok then
            return false, "Failed to create save directory"
        end
    end

    -- 写入文件
    local filename = _slot_filename(slot)
    local ok, err = love.filesystem.write(filename, data_str)

    if ok then
        Logger.infof("SaveLoad: saved game to slot %d (%d moves)", slot, #moves)
        return true
    else
        Logger.errorf("SaveLoad: failed to save to slot %d: %s", slot, err)
        return false, err
    end
end

-- ============================================================
-- 读取存档
-- @param slot (number) 存档槽位
-- @return (table|nil, string) 游戏状态（可直接用于 GameState 初始化），错误信息
-- ============================================================

function SaveLoad.load_game(slot)
    slot = slot or 1

    local filename = _slot_filename(slot)
    local data_str, err = love.filesystem.read(filename)

    if not data_str then
        return nil, "Failed to read save: " .. tostring(err)
    end

    -- 反序列化
    local save_data, parse_err = _deserialize(data_str)

    if not save_data then
        Logger.errorf("SaveLoad: failed to parse save slot %d: %s", slot, parse_err)
        return nil, parse_err
    end

    -- 版本检查
    if save_data.version ~= SAVE_VERSION then
        Logger.warnf("SaveLoad: save version mismatch (got %d, expected %d)",
            save_data.version, SAVE_VERSION)
        -- 简单版本兼容：如果是默认开局且版本 <= SAVE_VERSION，尝试加载
        if save_data.initial_board ~= "default" then
            return nil, "Unsupported save version"
        end
    end

    Logger.infof("SaveLoad: loaded game from slot %d (%d moves, %s turn)",
        slot, save_data.move_count or 0, save_data.current_turn or "red")

    return save_data
end

-- ============================================================
-- 根据存档数据恢复游戏状态
-- @param save_data (table) load_game 返回的数据
-- @return (GameState) 恢复后的游戏状态
-- ============================================================

function SaveLoad.restore_state(save_data)
    local state = GameState.new()
    state:init_default_board()

    -- 逐步重放所有走法
    for i, move in ipairs(save_data.moves or {}) do
        -- 找到棋子
        local piece = state:get_piece_at(move.fx, move.fy)
        if piece then
            local success = state:move(piece, move.tx, move.ty)
            if not success then
                Logger.errorf("SaveLoad: failed to replay move %d", i)
                break
            end
        else
            Logger.errorf("SaveLoad: piece not found at (%d,%d) for move %d",
                move.fx, move.fy, i)
            break
        end
    end

    return state
end

-- ============================================================
-- 获取存档列表
-- @return (table) 存档信息列表，每个元素 {slot, timestamp, date_str, move_count, current_turn, exists}
-- ============================================================

function SaveLoad.list_saves()
    local saves = {}

    for i = 1, MAX_SLOTS do
        local filename = _slot_filename(i)
        local info = love.filesystem.getInfo(filename)

        if info then
            local save_data = SaveLoad.load_game(i)
            if save_data then
                table.insert(saves, {
                    slot = i,
                    exists = true,
                    timestamp = save_data.timestamp,
                    date_str = save_data.date_str,
                    move_count = save_data.move_count or 0,
                    current_turn = save_data.current_turn,
                    status = save_data.status,
                })
            else
                table.insert(saves, {
                    slot = i,
                    exists = false,
                })
            end
        else
            table.insert(saves, {
                slot = i,
                exists = false,
            })
        end
    end

    return saves
end

-- ============================================================
-- 删除存档
-- @param slot (number) 存档槽位
-- @return (boolean, string)
-- ============================================================

function SaveLoad.delete_save(slot)
    slot = slot or 1

    local filename = _slot_filename(slot)
    local info = love.filesystem.getInfo(filename)

    if not info then
        return false, "Save not found"
    end

    local ok, err = love.filesystem.remove(filename)
    if ok then
        Logger.infof("SaveLoad: deleted save slot %d", slot)
        return true
    else
        return false, err
    end
end

-- ============================================================
-- 设置获取/保存（更轻量的配置存储）
-- 用 Config 模块做持久化，这里只是封装一下
-- ============================================================

function SaveLoad.save_settings()
    -- Config 模块已经自己处理持久化了
    Core.Config.save()
end

function SaveLoad.load_settings()
    -- Config 模块自己会加载
    return true
end

-- ============================================================
-- 获取存档目录路径（用于调试）
-- ============================================================

function SaveLoad.get_save_dir()
    return love.filesystem.getSaveDirectory()
end

-- ============================================================
-- 最大槽位数
-- ============================================================

SaveLoad.MAX_SLOTS = MAX_SLOTS

return SaveLoad
