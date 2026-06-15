-- 场景名: boot_scene
-- 功能: 启动/加载场景
-- 说明: 游戏启动时显示的第一个画面，可以放 logo、加载资源
-- 类比: 应用的启动页 / Splash Screen

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer

local BootScene = {}

-- 场景进入
-- @param params (table) 上一个场景传来的参数
function BootScene:enter(params)
    Logger.debug("BootScene: enter")

    -- 预加载中文字体（解决中文乱码）
    _title_font = ResourceManager.get_font("NotoSansSC-Bold.ttc", 56)
    _subtitle_font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 28)

    -- 注册各层的绘制函数
    -- 演示 RenderLayer 的用法

    -- 背景层：深色背景
    RenderLayer.add("BACKGROUND", function()
        love.graphics.setColor(0.1, 0.1, 0.15, 1)  -- 深蓝灰
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end)

    -- 游戏层：标题文字
    RenderLayer.add("GAME", function()
        local w, h = love.graphics.getDimensions()

        -- 大标题
        love.graphics.setColor(1, 1, 1, 1)
        local title_font = love.graphics.newFont(48)
        love.graphics.setFont(title_font)
        local title = "romwe_game"
        local title_w = title_font:getWidth(title)
        love.graphics.print(title, (w - title_w) / 2, h / 2 - 80)

        -- 副标题
        local subtitle_font = love.graphics.newFont(24)
        love.graphics.setFont(subtitle_font)
        local subtitle = "中国象棋 - V0.0.1"
        local subtitle_w = subtitle_font:getWidth(subtitle)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.print(subtitle, (w - subtitle_w) / 2, h / 2 - 20)

        -- 提示文字
        local hint_font = love.graphics.newFont(16)
        love.graphics.setFont(hint_font)
        local hint = "按 空格键 进入测试场景"
        local hint_w = hint_font:getWidth(hint)
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.print(hint, (w - hint_w) / 2, h / 2 + 60)

        -- 恢复默认字体
        love.graphics.setFont(love.graphics.newFont(12))
    end)

    -- UI 层：版本号
    RenderLayer.add("UI", function()
        local w, h = love.graphics.getDimensions()
        love.graphics.setColor(0.4, 0.4, 0.4, 1)
        love.graphics.print("v0.0.1 - Boot Scene", 10, h - 24)
    end)

    -- 调试层：FPS 和信息
    RenderLayer.add("DEBUG", function()
        love.graphics.setColor(0, 1, 0, 1)  -- 绿色
        love.graphics.print("DEBUG MODE", 10, 10)
        love.graphics.print("FPS: " .. tostring(love.timer.getFPS()), 10, 30)
        love.graphics.print("Layers: BACKGROUND, GAME, UI, DEBUG", 10, 50)
        love.graphics.print("按 F1 切换调试层显示", 10, 70)
    end)

    -- 加载完成
    Logger.info("BootScene: ready")
end

-- 每帧更新
-- @param dt (number) 距上一帧的时间（秒）
function BootScene:update(dt)
    -- 检测空格键，跳转到测试场景
    if Core.Input.is_pressed("space") then
        Logger.debug("BootScene: space pressed, switching to test scene")
        Core.SceneManager.switch("test")
    end
end

-- 每帧绘制
-- 注意：因为我们用了 RenderLayer，这里只需要调用 RenderLayer.draw()
-- 场景自己也可以在 draw 里直接画，但推荐用 RenderLayer 管理层级
function BootScene:draw()
    RenderLayer.draw()
end

-- 场景退出
function BootScene:exit()
    Logger.debug("BootScene: exit")
    -- 清空所有绘制项（防止内存泄漏）
    RenderLayer.clear_all()
end

return BootScene
