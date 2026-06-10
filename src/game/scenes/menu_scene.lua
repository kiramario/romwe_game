-- 场景名: menu_scene
-- 功能: 主菜单场景
-- 说明: 游戏启动后显示的主菜单，包含开始游戏、设置、关于等选项
-- 类比: 游戏的主菜单界面

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local Input = Core.Input
local SceneManager = Core.SceneManager
local ResourceManager = Core.ResourceManager
local AudioManager = Core.AudioManager

local Button = require("src.game.ui.button")

local MenuScene = {}
MenuScene.__index = MenuScene

-- ============================================================
-- 构造函数
-- ============================================================

function MenuScene.new()
    local self = setmetatable({}, MenuScene)

    -- 按钮列表
    self.buttons = {}

    -- 消息提示（临时显示）
    self.message = nil
    self.message_timer = 0

    -- 背景星星（装饰）
    self.stars = {}
    for i = 1, 50 do
        table.insert(self.stars, {
            x = math.random(0, 1280),
            y = math.random(0, 720),
            size = math.random(1, 3),
            speed = math.random(5, 20),
            alpha = math.random(30, 80) / 100,
        })
    end

    return self
end

-- ============================================================
-- 场景进入
-- ============================================================

function MenuScene:enter(params)
    Logger.debug("MenuScene: enter")

    local w, h = love.graphics.getDimensions()

    -- ========== 背景层 ==========
    RenderLayer.add("BACKGROUND", function()
        -- 深色渐变背景
        for i = 0, h, 4 do
            local t = i / h
            local r = 0.03 + t * 0.05
            local g = 0.03 + t * 0.03
            local b = 0.08 + t * 0.07
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", 0, i, w, 4)
        end

        -- 装饰性星星
        love.graphics.setColor(1, 1, 1, 0.6)
        for _, star in ipairs(self.stars) do
            love.graphics.circle("fill", star.x, star.y, star.size)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- ========== 游戏层：标题 ==========
    RenderLayer.add("GAME", function()
        local w, h = love.graphics.getDimensions()

        -- 游戏标题
        local title_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 64)
        love.graphics.setFont(title_font)
        love.graphics.setColor(1, 0.85, 0.6, 1)  -- 金色

        local title = "中国象棋"
        local title_w = title_font:getWidth(title)
        love.graphics.print(title, (w - title_w) / 2, h * 0.18)

        -- 副标题
        local subtitle_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 20)
        love.graphics.setFont(subtitle_font)
        love.graphics.setColor(0.7, 0.7, 0.8, 1)

        local subtitle = "Chinese Chess"
        local subtitle_w = subtitle_font:getWidth(subtitle)
        love.graphics.print(subtitle, (w - subtitle_w) / 2, h * 0.18 + 80)

        love.graphics.setFont(love.graphics.newFont(12))
        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- ========== UI 层：按钮 ==========
    -- 注意：按钮是在 update 里更新状态，draw 里绘制
    -- 我们用 RenderLayer 的 UI 层来画按钮

    RenderLayer.add("UI", function()
        self:draw_buttons()
        self:draw_message()
    end)

    -- ========== 调试层 ==========
    RenderLayer.add("DEBUG", function()
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print("Scene: menu_scene", 10, 10)
        love.graphics.print("Buttons: " .. tostring(#self.buttons), 10, 30)
        love.graphics.print("按 ENTER 开始游戏 | ESC 退出", 10, 50)
        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- ========== 创建按钮 ==========
    self:create_buttons()

    Logger.info("MenuScene: ready")
end

-- ============================================================
-- 创建按钮
-- ============================================================

function MenuScene:create_buttons()
    local w, h = love.graphics.getDimensions()

    -- 按钮配置
    local button_width = 280
    local button_height = 56
    local button_spacing = 20
    local start_y = h * 0.45
    local center_x = w / 2 - button_width / 2

    -- 1. 开始游戏按钮
    local btn_start = Button.new({
        x = center_x,
        y = start_y,
        width = button_width,
        height = button_height,
        text = "开始游戏",
        font_size = 22,
        font_path = "NotoSansSC-Regular.ttc",
        corner_radius = 8,
        on_click = function()
            Logger.debug("MenuScene: 开始游戏 按钮被点击")
            AudioManager.play_sfx("click")
            SceneManager.switch("game")
        end,
    })
    table.insert(self.buttons, btn_start)

    -- 2. 设置按钮
    local btn_settings = Button.new({
        x = center_x,
        y = start_y + button_height + button_spacing,
        width = button_width,
        height = button_height,
        text = "设置",
        font_size = 22,
        font_path = "NotoSansSC-Regular.ttc",
        corner_radius = 8,
        on_click = function()
            Logger.debug("MenuScene: 设置 按钮被点击")
            AudioManager.play_sfx("click")
            SceneManager.push("settings")
        end,
    })
    table.insert(self.buttons, btn_settings)

    -- 3. 关于按钮
    local btn_about = Button.new({
        x = center_x,
        y = start_y + (button_height + button_spacing) * 2,
        width = button_width,
        height = button_height,
        text = "关于",
        font_size = 22,
        font_path = "NotoSansSC-Regular.ttc",
        corner_radius = 8,
        on_click = function()
            AudioManager.play_sfx("click")
            self:show_message("中国象棋 v4.0.0\nTrillion Games 出品\n\n独立游戏开发项目\n基于 LÖVE2D 引擎")
        end,
    })
    table.insert(self.buttons, btn_about)
end

-- ============================================================
-- 显示提示消息
-- ============================================================

function MenuScene:show_message(text, duration)
    self.message = text
    self.message_timer = duration or 2.0  -- 默认显示 2 秒
end

-- ============================================================
-- 绘制按钮
-- ============================================================

function MenuScene:draw_buttons()
    for _, btn in ipairs(self.buttons) do
        btn:draw()
    end
end

-- ============================================================
-- 绘制消息
-- ============================================================

function MenuScene:draw_message()
    if not self.message or self.message_timer <= 0 then
        return
    end

    local w, h = love.graphics.getDimensions()

    -- 半透明背景
    love.graphics.setColor(0, 0, 0, 0.7)
    local msg_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 18)
    love.graphics.setFont(msg_font)

    -- 计算消息框大小（支持多行）
    local lines = Utils.string_split(self.message, "\n")
    local max_w = 0
    for _, line in ipairs(lines) do
        local lw = msg_font:getWidth(line)
        if lw > max_w then max_w = lw end
    end

    local box_w = max_w + 40
    local box_h = #lines * 28 + 20
    local box_x = (w - box_w) / 2
    local box_y = h * 0.7

    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 8, 8)

    -- 消息文字
    love.graphics.setColor(1, 1, 1, 1)
    for i, line in ipairs(lines) do
        local line_w = msg_font:getWidth(line)
        love.graphics.print(line, (w - line_w) / 2, box_y + 10 + (i - 1) * 28)
    end

    love.graphics.setFont(love.graphics.newFont(12))
end

-- ============================================================
-- 每帧更新
-- ============================================================

function MenuScene:update(dt)
    -- 更新按钮
    for _, btn in ipairs(self.buttons) do
        btn:update(dt)
    end

    -- 更新消息计时器
    if self.message_timer > 0 then
        self.message_timer = self.message_timer - dt
    end

    -- 更新星星（缓慢下移，营造纵深感）
    local h = love.graphics.getHeight()
    for _, star in ipairs(self.stars) do
        star.y = star.y + star.speed * dt
        if star.y > h then
            star.y = 0
            star.x = math.random(0, love.graphics.getWidth())
        end
    end

    -- 键盘快捷键
    if Input.is_pressed("confirm") then
        -- 回车 = 开始游戏
        SceneManager.switch("game")
    end
end

-- ============================================================
-- 每帧绘制
-- ============================================================

function MenuScene:draw()
    RenderLayer.draw()
end

-- ============================================================
-- 场景退出
-- ============================================================

function MenuScene:exit()
    Logger.debug("MenuScene: exit")

    -- 清空按钮
    self.buttons = {}

    -- 清空绘制层
    RenderLayer.clear_all()
end

return MenuScene
