-- 场景名: select_game_scene
-- 功能: 游戏选择面板
-- 说明: V3.0.0 新增 - 选择要玩的游戏
-- 后期可以在这里添加更多游戏（卡牌、解谜等）

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local Input = Core.Input
local SceneManager = Core.SceneManager
local ResourceManager = Core.ResourceManager

local SelectGameScene = {}
SelectGameScene.__index = SelectGameScene

-- 游戏列表配置
local GAMES = {
    {
        id = "chess",
        name = "中国象棋",
        description = "经典象棋对弈，支持人机对战",
        color = {0.85, 0.2, 0.2},      -- 红色主题
        icon = "象",
    },
    {
        id = "pinball",
        name = "弹珠游戏",
        description = "物理弹珠，休闲小游戏",
        color = {0.2, 0.5, 0.85},     -- 蓝色主题
        icon = "●",
    },
}

function SelectGameScene.new()
    local self = setmetatable({}, SelectGameScene)

    -- 按钮区域
    self.buttons = {}
    self.hover_idx = 0
    self.timer = 0

    -- 字体
    self.font_title = nil
    self.font_game_name = nil
    self.font_game_desc = nil
    self.font_hint = nil

    -- 按钮布局
    self.btn_width = 320
    self.btn_height = 120
    self.btn_spacing = 30

    return self
end

function SelectGameScene:enter(params)
    Logger.debug("SelectGameScene: enter")

    -- 加载中文字体
    self.font_title = ResourceManager.get_font("NotoSansSC-Bold.ttc", 42)
    self.font_game_name = ResourceManager.get_font("NotoSansSC-Bold.ttc", 28)
    self.font_game_desc = ResourceManager.get_font("NotoSansSC-Regular.ttc", 16)
    self.font_hint = ResourceManager.get_font("NotoSansSC-Regular.ttc", 18)

    -- 计算按钮位置
    self:layout_buttons()

    -- 背景层
    RenderLayer.add("BACKGROUND", function()
        local w, h = love.graphics.getDimensions()
        -- 深色渐变
        for i = 0, h, 4 do
            local t = i / h
            local r = 0.03 + t * 0.05
            local g = 0.03 + t * 0.03
            local b = 0.08 + t * 0.07
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", 0, i, w, 4)
        end
    end)

    -- 游戏层：标题和游戏卡片
    RenderLayer.add("GAME", function()
        self:draw_games()
    end)

    -- UI 层：提示
    RenderLayer.add("UI", function()
        local w, h = love.graphics.getDimensions()
        love.graphics.setFont(self.font_hint)
        love.graphics.setColor(0.5, 0.5, 0.6, 1)
        local hint = "↑↓ 选择  |  回车/点击 开始  |  ESC 返回"
        local hw = self.font_hint:getWidth(hint)
        love.graphics.print(hint, (w - hw) / 2, h - 60)
    end)

    -- 注册窗口大小变化事件
    self._resize_handler = function(w, h)
        self:layout_buttons()
    end
    Core.EventBus.on("window:resized", self._resize_handler)

    Logger.info("SelectGameScene: ready")
end

function SelectGameScene:layout_buttons()
    local w, h = love.graphics.getDimensions()
    local total_height = #GAMES * self.btn_height + (#GAMES - 1) * self.btn_spacing
    local start_y = h * 0.35

    self.buttons = {}
    for i, game in ipairs(GAMES) do
        table.insert(self.buttons, {
            x = (w - self.btn_width) / 2,
            y = start_y + (i - 1) * (self.btn_height + self.btn_spacing),
            w = self.btn_width,
            h = self.btn_height,
            game = game,
        })
    end
end

function SelectGameScene:update(dt)
    self.timer = self.timer + dt

    -- 键盘导航
    if Input.is_pressed("up") then
        self.hover_idx = math.max(1, self.hover_idx - 1)
    elseif Input.is_pressed("down") then
        self.hover_idx = math.min(#GAMES, self.hover_idx + 1)
    end

    -- 确认选择
    if Input.is_pressed("confirm") then
        if self.hover_idx == 0 then self.hover_idx = 1 end
        self:start_game(self.hover_idx)
        return
    end

    -- ESC 返回 boot 场景
    if Input.is_pressed("cancel") then
        SceneManager.switch("boot")
        return
    end

    -- 鼠标悬停检测
    local mx, my = Input.get_mouse_position()
    self.hover_idx = 0
    for i, btn in ipairs(self.buttons) do
        if mx >= btn.x and mx <= btn.x + btn.w and
           my >= btn.y and my <= btn.y + btn.h then
            self.hover_idx = i
        end
    end

    -- 鼠标点击
    if Input.is_mouse_pressed(1) then
        for i, btn in ipairs(self.buttons) do
            local mx, my = Input.get_mouse_position()
            if mx >= btn.x and mx <= btn.x + btn.w and
               my >= btn.y and my <= btn.y + btn.h then
                self:start_game(i)
                return
            end
        end
    end
end

function SelectGameScene:start_game(idx)
    local game = GAMES[idx]
    if not game then return end

    Logger.infof("SelectGameScene: starting game '%s'", game.id)
    if game.id == "chess" then
        SceneManager.switch("game")
    elseif game.id == "pinball" then
        SceneManager.switch("pinball")
    end
end

function SelectGameScene:draw_games()
    local w, h = love.graphics.getDimensions()

    -- 标题
    love.graphics.setFont(self.font_title)
    love.graphics.setColor(1, 0.85, 0.6, 1)
    local title = "选择游戏"
    local tw = self.font_title:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, h * 0.15)

    -- 绘制游戏卡片
    for i, btn in ipairs(self.buttons) do
        local game = btn.game
        local is_hover = (self.hover_idx == i)

        -- 卡片背景
        local scale = is_hover and 1.04 or 1.0
        local cx = btn.x + btn.w / 2
        local cy = btn.y + btn.h / 2
        local bw = btn.w * scale
        local bh = btn.h * scale
        local bx = cx - bw / 2
        local by = cy - bh / 2

        -- 阴影
        love.graphics.setColor(0, 0, 0, is_hover and 0.4 or 0.2)
        love.graphics.rectangle("fill", bx + 4, by + 6, bw, bh, 12, 12)

        -- 卡片背景
        local bg_r = game.color[1] * 0.15
        local bg_g = game.color[2] * 0.15
        local bg_b = game.color[3] * 0.15
        love.graphics.setColor(bg_r, bg_g, bg_b, 1)
        love.graphics.rectangle("fill", bx, by, bw, bh, 12, 12)

        -- 边框
        local border_alpha = is_hover and 0.9 or 0.4
        love.graphics.setColor(game.color[1], game.color[2], game.color[3], border_alpha)
        love.graphics.setLineWidth(is_hover and 3 or 1.5)
        love.graphics.rectangle("line", bx, by, bw, bh, 12, 12)
        love.graphics.setLineWidth(1)

        -- 游戏图标（大圆圈）
        local icon_cx = bx + 60
        local icon_cy = cy
        love.graphics.setColor(game.color[1], game.color[2], game.color[3], is_hover and 0.3 or 0.2)
        love.graphics.circle("fill", icon_cx, icon_cy, 30)
        love.graphics.setColor(game.color[1], game.color[2], game.color[3], 0.8)
        love.graphics.circle("line", icon_cx, icon_cy, 30, 30)
        love.graphics.setFont(self.font_game_name)
        love.graphics.setColor(1, 1, 1, 1)
        local icon_text = game.icon
        local iw = self.font_game_name:getWidth(icon_text)
        love.graphics.print(icon_text, icon_cx - iw/2, icon_cy - 14)

        -- 游戏名称
        love.graphics.setFont(self.font_game_name)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(game.name, bx + 110, by + 20)

        -- 游戏描述
        love.graphics.setFont(self.font_game_desc)
        love.graphics.setColor(0.7, 0.7, 0.8, 1)
        love.graphics.print(game.description, bx + 110, by + 60)

        love.graphics.setColor(1, 1, 1, 1)
    end
end

function SelectGameScene:draw()
    RenderLayer.draw()
end

function SelectGameScene:exit()
    Logger.debug("SelectGameScene: exit")
    RenderLayer.clear_all()
    if self._resize_handler then
        Core.EventBus.off("window:resized", self._resize_handler)
    end
end

return SelectGameScene
