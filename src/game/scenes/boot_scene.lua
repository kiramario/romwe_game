-- 场景名: boot_scene
-- 功能: 启动/加载场景
-- 说明: 游戏启动时显示的第一个画面，加载中文字体后显示欢迎界面
-- 类比: 应用的启动页 / Splash Screen

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local ResourceManager = Core.ResourceManager

-- 通过 Game 模块获取版本号
local Game = require("src.game")

local BootScene = {}

-- 中文字体（在 enter 时预加载）
local _title_font = nil
local _subtitle_font = nil
local _hint_font = nil
local _small_font = nil

-- 场景进入
function BootScene:enter(params)
    Logger.debug("BootScene: enter")

    -- 预加载中文字体（解决中文乱码问题）
    _title_font = ResourceManager.get_font("NotoSansSC-Bold.ttc", 56)
    _subtitle_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 28)
    _hint_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 20)
    _small_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 14)

    -- 注册各层的绘制函数

    -- 背景层：深色背景
    RenderLayer.add("BACKGROUND", function()
        love.graphics.setColor(0.1, 0.1, 0.15, 1)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end)

    -- 游戏层：标题文字
    RenderLayer.add("GAME", function()
        local w, h = love.graphics.getDimensions()

        -- 大标题
        love.graphics.setColor(1, 0.85, 0.6, 1)
        love.graphics.setFont(_title_font)
        local title = "romwe_game"
        local title_w = _title_font:getWidth(title)
        love.graphics.print(title, (w - title_w) / 2, h / 2 - 100)

        -- 副标题（版本号）
        love.graphics.setFont(_subtitle_font)
        love.graphics.setColor(0.8, 0.8, 0.9, 1)
        local subtitle = "版本 v" .. Game.version
        local subtitle_w = _subtitle_font:getWidth(subtitle)
        love.graphics.print(subtitle, (w - subtitle_w) / 2, h / 2 - 20)

        -- 提示文字
        love.graphics.setFont(_hint_font)
        love.graphics.setColor(0.5, 0.5, 0.6, 1)
        local hint = "按 空格键 或 回车键 进入游戏"
        local hint_w = _hint_font:getWidth(hint)
        love.graphics.print(hint, (w - hint_w) / 2, h / 2 + 60)
    end)

    -- UI 层：版本号
    RenderLayer.add("UI", function()
        local w, h = love.graphics.getDimensions()
        love.graphics.setFont(_small_font)
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        love.graphics.print("romwe_game v" .. Game.version .. " - 启动场景", 10, h - 24)
    end)

    -- 调试层：FPS 和信息
    RenderLayer.add("DEBUG", function()
        love.graphics.setFont(_small_font)
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print("调试模式", 10, 10)
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 30)
        love.graphics.print("渲染层: BACKGROUND, GAME, UI, EFFECTS, DEBUG", 10, 50)
        love.graphics.print("按 F1 切换调试层显示", 10, 70)
    end)

    Logger.info("BootScene: ready - romwe_game v" .. Game.version)
end

-- 每帧更新
function BootScene:update(dt)
    -- 检测按键，跳转到菜单场景（不是 test 场景，v1 之后从 boot 进入 menu）
    if Core.Input.is_pressed("space") or Core.Input.is_pressed("confirm") then
        Logger.debug("BootScene: key pressed, switching to menu scene")
        Core.SceneManager.switch("select_game")
    end
end

-- 每帧绘制
function BootScene:draw()
    RenderLayer.draw()
end

-- 场景退出
function BootScene:exit()
    Logger.debug("BootScene: exit")
    RenderLayer.clear_all()
end

return BootScene
