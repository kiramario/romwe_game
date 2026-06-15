-- 场景名: menu_scene
-- 功能: 中国象棋菜单场景
-- 说明: 象棋游戏的子菜单，包含开始、设置、关于

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local Input = Core.Input
local SceneManager = Core.SceneManager
local ResourceManager = Core.ResourceManager
local Utils = Core.Utils

local Game = require("src.game")
local Button = require("src.game.ui.button")

local MenuScene = {}
MenuScene.__index = MenuScene

function MenuScene.new()
    local self = setmetatable({}, MenuScene)
    self.buttons = {}
    self.message = nil
    self.message_timer = 0

    -- 背景星星
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

function MenuScene:enter(params)
    Logger.debug("MenuScene: enter")

    local w, h = love.graphics.getDimensions()

    -- 背景层
    RenderLayer.add("BACKGROUND", function()
        for i = 0, h, 4 do
            local t = i / h
            local r = 0.03 + t * 0.05
            local g = 0.03 + t * 0.03
            local b = 0.08 + t * 0.07
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", 0, i, w, 4)
        end
        love.graphics.setColor(1, 1, 1, 0.6)
        for _, star in ipairs(self.stars) do
            love.graphics.circle("fill", star.x, star.y, star.size)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- 标题层
    RenderLayer.add("GAME", function()
        local w, h = love.graphics.getDimensions()
        local title_font = ResourceManager.get_font("NotoSansSC-Bold.ttc", 56)
        love.graphics.setFont(title_font)
        love.graphics.setColor(1, 0.85, 0.6, 1)
        local title = "中国象棋"
        local tw = title_font:getWidth(title)
        love.graphics.print(title, (w - tw) / 2, h * 0.18)

        local subtitle_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 20)
        love.graphics.setFont(subtitle_font)
        love.graphics.setColor(0.7, 0.7, 0.8, 1)
        local subtitle = "romwe_game v" .. Game.version
        local sw = subtitle_font:getWidth(subtitle)
        love.graphics.print(subtitle, (w - sw) / 2, h * 0.18 + 72)
        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- UI 层
    RenderLayer.add("UI", function()
        self:draw_buttons()
        self:draw_message()
    end)

    -- 按钮
    self:create_buttons()
    Logger.info("MenuScene: ready")
end

function MenuScene:create_buttons()
    local w, h = love.graphics.getDimensions()
    local bw, bh = 280, 56
    local spacing = 20
    local start_y = h * 0.45
    local cx = w / 2 - bw / 2

    local btn_start = Button.new({
        x = cx, y = start_y, width = bw, height = bh,
        text = "选择游戏", font_size = 22, font_path = "NotoSansSC-Regular.ttc",
        corner_radius = 8,
        on_click = function()
            SceneManager.switch("select_game")
        end,
    })
    table.insert(self.buttons, btn_start)

    local btn_settings = Button.new({
        x = cx, y = start_y + bh + spacing, width = bw, height = bh,
        text = "设置", font_size = 22, font_path = "NotoSansSC-Regular.ttc",
        corner_radius = 8,
        on_click = function()
            SceneManager.push("settings")
        end,
    })
    table.insert(self.buttons, btn_settings)

    local btn_back = Button.new({
        x = cx, y = start_y + (bh + spacing) * 2, width = bw, height = bh,
        text = "返回游戏选择", font_size = 22, font_path = "NotoSansSC-Regular.ttc",
        corner_radius = 8,
        on_click = function()
            SceneManager.switch("select_game")
        end,
    })
    table.insert(self.buttons, btn_back)

    local btn_about = Button.new({
        x = cx, y = start_y + (bh + spacing) * 3, width = bw, height = bh,
        text = "关于", font_size = 22, font_path = "NotoSansSC-Regular.ttc",
        corner_radius = 8,
        on_click = function()
            self:show_message("romwe_game v" .. Game.version .. "\n\n基于 LÖVE2D 引擎的开源游戏合集\n中国象棋 + 弹珠游戏")
        end,
    })
    table.insert(self.buttons, btn_about)
end

function MenuScene:show_message(text, duration)
    self.message = text
    self.message_timer = duration or 3.0
end

function MenuScene:draw_buttons()
    for _, btn in ipairs(self.buttons) do btn:draw() end
end

function MenuScene:draw_message()
    if not self.message or self.message_timer <= 0 then return end
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    local msg_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 18)
    love.graphics.setFont(msg_font)
    local lines = Utils.string_split(self.message, "\n")
    local max_w = 0
    for _, line in ipairs(lines) do
        max_w = math.max(max_w, msg_font:getWidth(line))
    end
    local box_w = max_w + 40
    local box_h = #lines * 28 + 20
    local box_x = (w - box_w) / 2
    local box_y = h * 0.7
    love.graphics.rectangle("fill", box_x, box_y, box_w, box_h, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
    for i, line in ipairs(lines) do
        local lw = msg_font:getWidth(line)
        love.graphics.print(line, (w - lw) / 2, box_y + 10 + (i - 1) * 28)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function MenuScene:update(dt)
    for _, btn in ipairs(self.buttons) do btn:update(dt) end
    if self.message_timer > 0 then self.message_timer = self.message_timer - dt end

    local h = love.graphics.getHeight()
    for _, star in ipairs(self.stars) do
        star.y = star.y + star.speed * dt
        if star.y > h then
            star.y = 0
            star.x = math.random(0, love.graphics.getWidth())
        end
    end

    if Input.is_pressed("cancel") then
        SceneManager.switch("select_game")
    end
    if Input.is_pressed("confirm") then
        SceneManager.switch("game")
    end
end

function MenuScene:draw()
    RenderLayer.draw()
end

function MenuScene:exit()
    Logger.debug("MenuScene: exit")
    self.buttons = {}
    RenderLayer.clear_all()
end

return MenuScene
