-- 场景名: settings_scene
-- 功能: 设置场景
-- 说明: 调整音量、难度、显示选项等
-- 类比: 游戏设置界面 / 选项菜单

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local Input = Core.Input
local SceneManager = Core.SceneManager
local ResourceManager = Core.ResourceManager
local EventBus = Core.EventBus
local Config = Core.Config
local AudioManager = Core.AudioManager

local Button = require("src.game.ui.button")

local SettingsScene = {}
SettingsScene.__index = SettingsScene

-- ============================================================
-- 构造函数
-- ============================================================

function SettingsScene.new()
    local self = setmetatable({}, SettingsScene)

    -- 按钮
    self.buttons = {}

    -- 设置项值
    self.master_volume = 1.0
    self.sfx_volume = 0.7
    self.music_volume = 0.5
    self.difficulty = "normal"
    self.show_debug = false
    self.ai_enabled = true  -- 人机对战开关

    -- 选中的设置项（键盘导航用）
    self.selected_index = 1

    return self
end

-- ============================================================
-- 场景进入
-- ============================================================

function SettingsScene:enter(params)
    Logger.debug("SettingsScene: enter")

    -- 从配置加载
    self.master_volume = Config.get("audio.master_volume") or 1.0
    self.sfx_volume = Config.get("audio.sfx_volume") or 0.7
    self.music_volume = Config.get("audio.music_volume") or 0.5
    self.difficulty = Config.get("game.difficulty") or "normal"
    self.show_debug = Config.get("ui.show_debug") or false
    self.ai_enabled = Config.get("game.ai_enabled")
    if self.ai_enabled == nil then self.ai_enabled = true end

    -- 同步音频
    AudioManager.set_master_volume(self.master_volume)
    AudioManager.set_sfx_volume(self.sfx_volume)
    AudioManager.set_music_volume(self.music_volume)

    -- 背景
    RenderLayer.add("BACKGROUND", function()
        local w, h = love.graphics.getDimensions()

        -- 深色背景
        love.graphics.setColor(0.08, 0.08, 0.12, 1)
        love.graphics.rectangle("fill", 0, 0, w, h)

        -- 装饰性渐变（顶部）
        for i = 1, 100 do
            local alpha = (1 - i / 100) * 0.15
            love.graphics.setColor(0.3, 0.4, 0.6, alpha)
            love.graphics.rectangle("fill", 0, i * 2, w, 2)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- UI 层
    RenderLayer.add("UI", function()
        self:draw_ui()
    end)

    -- 调试层
    RenderLayer.add("DEBUG", function()
        if self.show_debug then
            love.graphics.setColor(0, 1, 0, 1)
            love.graphics.print("Scene: settings_scene (V4)", 10, 10)
            love.graphics.print("Master: " .. string.format("%.0f%%", self.master_volume * 100), 10, 30)
            love.graphics.print("SFX: " .. string.format("%.0f%%", self.sfx_volume * 100), 10, 50)
            love.graphics.print("Music: " .. string.format("%.0f%%", self.music_volume * 100), 10, 70)
            love.graphics.print("Difficulty: " .. self.difficulty, 10, 90)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end)

    Logger.info("SettingsScene: ready")
end

-- ============================================================
-- 场景退出
-- ============================================================

function SettingsScene:exit()
    Logger.debug("SettingsScene: exit")

    -- 保存设置
    Config.set("audio.master_volume", self.master_volume)
    Config.set("audio.sfx_volume", self.sfx_volume)
    Config.set("audio.music_volume", self.music_volume)
    Config.set("game.difficulty", self.difficulty)
    Config.set("ui.show_debug", self.show_debug)
    Config.set("game.ai_enabled", self.ai_enabled)
    Config.save()

    RenderLayer.clear()
end

-- ============================================================
-- 每帧更新
-- ============================================================

function SettingsScene:update(dt)
    -- 返回按钮
    if Input.is_pressed("cancel") then
        Logger.debug("SettingsScene: ESC pressed, returning")
        SceneManager.pop()
    end

    -- 处理点击（简化版：用点击检测来模拟按钮）
    if Input.is_mouse_pressed(1) then
        self:_handle_click()
    end

    -- 键盘控制
    if Input.is_pressed("up") then
        self.selected_index = self.selected_index - 1
        if self.selected_index < 1 then self.selected_index = self:_setting_count() end
        AudioManager.play_sfx("select")
    end

    if Input.is_pressed("down") then
        self.selected_index = self.selected_index + 1
        if self.selected_index > self:_setting_count() then self.selected_index = 1 end
        AudioManager.play_sfx("select")
    end

    -- 左右调整
    if Input.is_pressed("left") or Input.is_pressed("right") then
        local delta = Input.is_pressed("right") and 1 or -1
        self:_adjust_setting(self.selected_index, delta)
    end

    -- 保存按钮（回车）
    if Input.is_pressed("confirm") or Input.is_pressed("return") then
        if self.selected_index == self:_setting_count() then
            -- 最后一项是返回
            SceneManager.pop()
        end
    end
end

-- 设置项总数
function SettingsScene:_setting_count()
    return 7  -- 主音量、音效、音乐、难度、AI开关、调试、返回
end

-- ============================================================
-- 处理点击
-- ============================================================

function SettingsScene:_handle_click()
    local mx, my = Input.get_mouse_position()
    local w, h = love.graphics.getDimensions()

    local start_y = 150
    local item_height = 55

    -- 检测每个设置项的点击
    for i = 1, 6 do  -- 前 6 项是设置
        local item_y = start_y + (i - 1) * item_height
        local item_w = 400
        local item_x = (w - item_w) / 2

        if mx >= item_x and mx <= item_x + item_w and
           my >= item_y and my <= item_y + 40 then

            self.selected_index = i

            -- 判断点击在左半边还是右半边
            if mx < item_x + item_w / 2 then
                self:_adjust_setting(i, -1)
            else
                self:_adjust_setting(i, 1)
            end

            return
        end
    end

    -- 返回按钮
    local back_y = start_y + 6 * item_height + 20
    if my >= back_y and my <= back_y + 45 then
        local back_w = 200
        local back_x = (w - back_w) / 2
        if mx >= back_x and mx <= back_x + back_w then
            SceneManager.pop()
            AudioManager.play_sfx("click")
        end
    end
end

-- ============================================================
-- 调整设置项
-- ============================================================

function SettingsScene:_adjust_setting(index, delta)
    if index == 1 then
        -- 主音量
        self.master_volume = math.max(0, math.min(1, self.master_volume + delta * 0.1))
        AudioManager.set_master_volume(self.master_volume)
        AudioManager.play_sfx("click")

    elseif index == 2 then
        -- 音效音量
        self.sfx_volume = math.max(0, math.min(1, self.sfx_volume + delta * 0.1))
        AudioManager.set_sfx_volume(self.sfx_volume)
        AudioManager.play_sfx("click")

    elseif index == 3 then
        -- 音乐音量
        self.music_volume = math.max(0, math.min(1, self.music_volume + delta * 0.1))
        AudioManager.set_music_volume(self.music_volume)
        AudioManager.play_sfx("click")

    elseif index == 4 then
        -- 难度
        local diffs = {"easy", "normal", "hard", "expert"}
        local idx = 1
        for i, d in ipairs(diffs) do
            if d == self.difficulty then idx = i break end
        end
        idx = idx + delta
        if idx < 1 then idx = #diffs end
        if idx > #diffs then idx = 1 end
        self.difficulty = diffs[idx]
        AudioManager.play_sfx("select")

    elseif index == 5 then
        -- AI 开关
        self.ai_enabled = not self.ai_enabled
        AudioManager.play_sfx("click")

    elseif index == 6 then
        -- 调试信息
        self.show_debug = not self.show_debug
        AudioManager.play_sfx("click")
    end
end

-- ============================================================
-- 绘制 UI
-- ============================================================

function SettingsScene:draw_ui()
    local w, h = love.graphics.getDimensions()

    -- 标题
    local title_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 36)
    love.graphics.setFont(title_font)
    love.graphics.setColor(1, 1, 1, 1)
    local title = "游戏设置"
    local title_w = title_font:getWidth(title)
    love.graphics.print(title, (w - title_w) / 2, 80)

    -- 设置项
    local label_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 20)
    local value_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 22)

    local start_y = 150
    local item_height = 55
    local item_w = 400
    local item_x = (w - item_w) / 2

    local settings = {
        {label = "主音量",    value = string.format("%.0f%%", self.master_volume * 100)},
        {label = "音效音量", value = string.format("%.0f%%", self.sfx_volume * 100)},
        {label = "音乐音量", value = string.format("%.0f%%", self.music_volume * 100)},
        {label = "AI 难度",  value = self:_difficulty_name(self.difficulty)},
        {label = "人机对战", value = self.ai_enabled and "开启" or "关闭"},
        {label = "调试信息", value = self.show_debug and "显示" or "隐藏"},
    }

    for i, item in ipairs(settings) do
        local item_y = start_y + (i - 1) * item_height

        -- 选中高亮
        if i == self.selected_index then
            love.graphics.setColor(0.2, 0.4, 0.7, 0.3)
            love.graphics.rectangle("fill", item_x - 10, item_y - 5, item_w + 20, 40, 8, 8)
            love.graphics.setColor(0.4, 0.6, 1.0, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", item_x - 10, item_y - 5, item_w + 20, 40, 8, 8)
            love.graphics.setLineWidth(1)
        end

        -- 标签
        love.graphics.setFont(label_font)
        love.graphics.setColor(0.8, 0.8, 0.85, 1)
        love.graphics.print(item.label, item_x + 10, item_y + 8)

        -- 值（右对齐）
        love.graphics.setFont(value_font)
        love.graphics.setColor(1, 0.95, 0.7, 1)
        local val_w = value_font:getWidth(item.value)
        love.graphics.print(item.value, item_x + item_w - val_w - 10, item_y + 6)

        -- 左右箭头提示
        love.graphics.setColor(0.5, 0.5, 0.6, 1)
        love.graphics.print("<", item_x + item_w - val_w - 35, item_y + 6)
        love.graphics.print(">", item_x + item_w - 10 + 8, item_y + 6)
    end

    -- 返回按钮
    local back_y = start_y + #settings * item_height + 20
    local back_w = 200
    local back_x = (w - back_w) / 2
    local back_h = 45

    local is_back_selected = (self.selected_index == #settings + 1)

    if is_back_selected then
        love.graphics.setColor(0.3, 0.5, 0.9, 1)
    else
        love.graphics.setColor(0.2, 0.25, 0.35, 1)
    end
    love.graphics.rectangle("fill", back_x, back_y, back_w, back_h, 8, 8)

    love.graphics.setColor(0.4, 0.45, 0.55, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", back_x, back_y, back_w, back_h, 8, 8)

    love.graphics.setFont(label_font)
    love.graphics.setColor(1, 1, 1, 1)
    local back_text = "返回"
    local bt_w = label_font:getWidth(back_text)
    love.graphics.print(back_text, back_x + (back_w - bt_w) / 2, back_y + 10)

    -- 操作提示
    local hint_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 14)
    love.graphics.setFont(hint_font)
    love.graphics.setColor(0.5, 0.5, 0.6, 1)
    local hint = "↑↓ 选择  |  ←→ 调整  |  Enter 确认  |  ESC 返回"
    local hint_w = hint_font:getWidth(hint)
    love.graphics.print(hint, (w - hint_w) / 2, h - 30)

    love.graphics.setFont(love.graphics.newFont(12))
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================
-- 难度中文名
-- ============================================================

function SettingsScene:_difficulty_name(diff)
    local names = {
        easy = "简单",
        normal = "普通",
        hard = "困难",
        expert = "专家",
    }
    return names[diff] or diff
end

-- ============================================================
-- 绘制
-- ============================================================

function SettingsScene:draw()
    RenderLayer.draw()
end

return SettingsScene
