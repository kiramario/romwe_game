-- main.lua
-- 游戏入口文件
-- LÖVE2D 会自动查找并加载这个文件
--
-- 这个文件非常薄，只做三件事：
--   1. 初始化 core 引擎层
--   2. 初始化 game 游戏层
--   3. 把 LÖVE2D 的回调转发给对应模块

-- 加载 core 引擎层
local Core = require("src.core")

-- 加载 game 游戏层
local Game = require("src.game")

-- ============================================================
-- LÖVE2D 生命周期回调
-- ============================================================

-- 游戏加载时调用（只调用一次）
function love.load()
    -- 初始化 core 引擎
    Core.init()

    -- 初始化 game 游戏层
    Game.init()

    -- 设置窗口标题（包含版本号）
    love.window.setTitle("romwe_game v" .. Game.version)

    Core.Logger.info("Game loaded successfully: romwe_game v" .. Game.version)
end

-- 每帧更新逻辑
function love.update(dt)
    Core.Input.update(dt)
    Core.SceneManager.update(dt)
    Core.Input.end_frame()
end

-- 每帧渲染画面
function love.draw()
    Core.draw()
end

-- 游戏退出时调用
function love.quit()
    Core.quit()
    return false
end

-- 窗口大小改变时调用
function love.resize(w, h)
    Core.Logger.debugf("Window resized: %dx%d", w, h)
    Core.EventBus.emit("window:resized", w, h)
end

-- 窗口获得/失去焦点时调用
function love.focus(focus)
    Core.Logger.debugf("Window focus: %s", tostring(focus))
    Core.EventBus.emit("window:focus", focus)
end

-- ============================================================
-- 输入回调 - 转发给 Input 模块
-- 注意：ESC 退出逻辑改由场景自己处理（暂停菜单 / 返回菜单等）
-- ============================================================

function love.keypressed(key, scancode, isrepeat)
    Core.Input.keypressed(key, scancode, isrepeat)

    -- F1 切换调试层
    if key == "f1" then
        local visible = Core.RenderLayer.toggle_debug()
        Core.Logger.debugf("Debug layer: %s", visible and "on" or "off")
    end
end

function love.keyreleased(key, scancode)
    Core.Input.keyreleased(key, scancode)
end

function love.mousepressed(x, y, button, isTouch, presses)
    Core.Input.mousepressed(x, y, button, isTouch)
end

function love.mousereleased(x, y, button, isTouch, presses)
    Core.Input.mousereleased(x, y, button, isTouch)
end

function love.mousemoved(x, y, dx, dy, isTouch)
    Core.Input.mousemoved(x, y, dx, dy, isTouch)
end

function love.wheelmoved(x, y)
    Core.EventBus.emit("mouse:wheel", x, y)
end

-- ============================================================
-- 错误处理
-- ============================================================

function love.errhand(msg)
    print("FATAL ERROR: " .. tostring(msg))
    print(debug.traceback())

    -- 显示错误画面
    love.graphics.setBackgroundColor(0.1, 0.05, 0.05)
    love.graphics.setColor(1, 0.3, 0.3)
    local err_font
    pcall(function()
        err_font = love.graphics.newFont("assets/fonts/NotoSansSC-Regular.ttc", 18)
    end)
    if not err_font then
        err_font = love.graphics.newFont(18)
    end
    love.graphics.setFont(err_font)
    love.graphics.printf("游戏出错了:\n\n" .. tostring(msg) .. "\n\n" .. debug.traceback(),
        50, 50, love.graphics.getWidth() - 100)
end
