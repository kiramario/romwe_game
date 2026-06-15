-- main.lua
-- 游戏入口文件
-- LÖVE2D 会自动查找并加载这个文件
--
-- 这个文件非常薄，只做三件事：
--   1. 初始化 core 引擎层
--   2. 初始化 game 游戏层
--   3. 把 LÖVE2D 的回调转发给对应模块
--
-- 类比: Web 应用的 app.js / server.js 入口文件
--       Java 的 main 方法

-- 加载 core 引擎层
local Core = require("src.core")

-- 加载 game 游戏层
local Game = require("src.game")

-- ============================================================
-- LÖVE2D 生命周期回调
-- 这些是 LÖVE2D 约定的函数名，游戏运行时会自动调用
-- 类比: React 的生命周期方法 / iOS 的 AppDelegate
-- ============================================================

-- 游戏加载时调用（只调用一次）
-- 类比: componentDidMount / applicationDidFinishLaunching
function love.load()
    -- 初始化 core 引擎
    Core.init()

    -- 初始化 game 游戏层
    Game.init()

    love.window.setTitle("romwe_game v" .. Game.version)
    Core.Logger.info("Game loaded successfully: romwe_game v" .. Game.version)
end

-- 每帧更新逻辑
-- dt = delta time，距上一帧的时间（秒）
-- 类比: requestAnimationFrame 的时间参数
-- 注意：所有移动、动画都要乘以 dt，保证不同帧率下速度一致
function love.update(dt)
    Core.update(dt)
end

-- 每帧渲染画面
-- 类比: render 方法
-- 注意：不要在这里做逻辑计算，只做绘制
function love.draw()
    Core.draw()
end

-- 游戏退出时调用
function love.quit()
    Core.quit()
    -- 返回 false 表示允许退出，返回 true 表示取消退出
    return false
end

-- 窗口大小改变时调用
-- @param w (number) 新宽度
-- @param h (number) 新高度
function love.resize(w, h)
    Core.Logger.debugf("Window resized: %dx%d", w, h)
    -- 发布事件，各模块可以订阅处理
    Core.EventBus.emit("window:resized", w, h)
end

-- 窗口获得/失去焦点时调用
-- @param focus (boolean) 是否获得焦点
function love.focus(focus)
    Core.Logger.debugf("Window focus: %s", tostring(focus))
    Core.EventBus.emit("window:focus", focus)
end

-- ============================================================
-- 输入回调
-- 这些回调由 LÖVE2D 触发，转发给 Input 模块
-- ============================================================

-- 键盘按下
-- @param key (string) 键名
-- @param scancode (string) 扫描码（物理键位）
-- @param isrepeat (boolean) 是否是重复输入（长按）
function love.keypressed(key, scancode, isrepeat)
    Core.Input.keypressed(key, scancode, isrepeat)

    -- ESC 键退出（调试用，正式版可以去掉）
    if key == "escape" then
        -- V0 阶段 ESC 直接退出
        -- 以后有菜单了就改成返回菜单
        love.event.quit()
    end

    -- F1 切换调试层
    if key == "f1" then
        local visible = Core.RenderLayer.toggle_debug()
        Core.Logger.debugf("Debug layer: %s", visible and "on" or "off")
    end
end

-- 键盘松开
function love.keyreleased(key, scancode)
    Core.Input.keyreleased(key, scancode)
end

-- 鼠标按下
-- @param x, y (number) 点击位置
-- @param button (number) 按键编号 (1=左, 2=右, 3=中)
-- @param isTouch (boolean) 是否来自触屏
-- @param presses (number) 点击次数（1=单击，2=双击）
function love.mousepressed(x, y, button, isTouch, presses)
    Core.Input.mousepressed(x, y, button, isTouch)
end

-- 鼠标松开
function love.mousereleased(x, y, button, isTouch, presses)
    Core.Input.mousereleased(x, y, button, isTouch)
end

-- 鼠标移动
function love.mousemoved(x, y, dx, dy, isTouch)
    Core.Input.mousemoved(x, y, dx, dy, isTouch)
end

-- 鼠标滚轮
function love.wheelmoved(x, y)
    -- V0 暂时不用，留个位置
    Core.EventBus.emit("mouse:wheel", x, y)
end

-- ============================================================
-- 错误处理
-- ============================================================

-- 运行时错误回调
-- LÖVE2D 默认会显示一个错误画面，这里可以自定义
function love.errhand(msg)
    -- 打印错误到控制台
    print("FATAL ERROR: " .. tostring(msg))
    print(debug.traceback())

    -- 调用默认错误处理
    -- 可以在这里自定义错误画面
    local default_errhand = function() end
    if type(love.errhand) == "function" then
        -- 防止无限递归
    end
end
