-- 场景名: test_scene
-- 功能: V0 测试场景
-- 说明: 用来验证 V0 版本各个系统是否正常工作
-- 验证内容:
--   1. 场景切换（按 ESC 回到 boot）
--   2. 输入系统（鼠标坐标、键盘按键）
--   3. 渲染分层（BACKGROUND / GAME / EFFECTS / UI / DEBUG）
--   4. 事件总线
--   5. 资源管理（图片加载缓存）
--   6. 配置系统

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local Input = Core.Input
local EventBus = Core.EventBus
local ResourceManager = Core.ResourceManager
local Config = Core.Config
local Utils = Core.Utils

local TestScene = {}

-- ============================================================
-- 场景状态
-- ============================================================

-- 用 self 保存场景状态
-- 类比: class 的成员变量
-- 注意: 因为场景是 table，用冒号调用方法时 self 就是场景本身

function TestScene:enter(params)
    Logger.debug("TestScene: enter")

    -- 初始化场景状态
    self.click_count = 0          -- 鼠标点击次数
    self.space_count = 0          -- 空格按下次数
    self.circle_x = 400           -- 圆的 x 坐标
    self.circle_y = 300           -- 圆的 y 坐标
    self.circle_speed = 200       -- 圆的移动速度（像素/秒）
    self.event_triggered = 0      -- 事件触发次数
    self.test_image_loaded = false  -- 图片是否加载过

    -- ========== 注册事件监听 ==========
    -- 演示 EventBus 的用法

    self._on_mouse_click = function(button, x, y)
        self.click_count = self.click_count + 1
        Logger.debugf("TestScene: mouse click #%d at (%d, %d)", self.click_count, x, y)
        self.event_triggered = self.event_triggered + 1
    end

    EventBus.on("input:mouse_pressed", self._on_mouse_click)

    -- ========== 注册各层绘制函数 ==========
    -- 演示 RenderLayer 分层渲染

    -- Layer 0: BACKGROUND - 背景层
    RenderLayer.add("BACKGROUND", function()
        -- 渐变背景（简单的横条模拟）
        local w, h = love.graphics.getDimensions()

        -- 深蓝紫色渐变背景
        for i = 0, h, 4 do
            local t = i / h
            local r = 0.05 + t * 0.05  -- 0.05 -> 0.10
            local g = 0.05 + t * 0.05  -- 0.05 -> 0.10
            local b = 0.15 + t * 0.10  -- 0.15 -> 0.25
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", 0, i, w, 4)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- Layer 1: GAME - 游戏主体层
    RenderLayer.add("GAME", function()
        local w, h = love.graphics.getDimensions()

        -- 画一个移动的圆
        love.graphics.setColor(0.2, 0.8, 0.4, 1)  -- 绿色
        love.graphics.circle("fill", self.circle_x, self.circle_y, 40)

        -- 画一个棋盘格占位（预示未来的象棋棋盘）
        local board_x = w / 2
        local board_y = h / 2 + 50
        local cell_size = 40

        love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
        for i = 0, 8 do
            for j = 0, 9 do
                local x = board_x - 4.5 * cell_size + i * cell_size
                local y = board_y - 5 * cell_size + j * cell_size
                if (i + j) % 2 == 0 then
                    love.graphics.rectangle("fill", x, y, cell_size, cell_size)
                end
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- Layer 2: EFFECTS - 特效层（V0 简单演示）
    RenderLayer.add("EFFECTS", function()
        local w, h = love.graphics.getDimensions()

        -- 画一些装饰性的粒子（简单的小圆点）
        math.randomseed(os.time())
        love.graphics.setColor(1, 1, 1, 0.3)
        for i = 1, 20 do
            local x = (i * 137) % w
            local y = (i * 89 + love.timer.getTime() * 30) % h
            local size = 2 + (i % 3)
            love.graphics.circle("fill", x, y, size)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- Layer 3: UI - 界面层
    RenderLayer.add("UI", function()
        local w, h = love.graphics.getDimensions()

        -- 标题
        local title_font = love.graphics.newFont(32)
        love.graphics.setFont(title_font)
        love.graphics.setColor(1, 1, 1, 1)
        local title = "V0 测试场景"
        local title_w = title_font:getWidth(title)
        love.graphics.print(title, (w - title_w) / 2, 30)

        -- 信息面板
        love.graphics.setFont(love.graphics.newFont(14))
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 20, 80, 320, 200)
        love.graphics.setColor(1, 1, 1, 1)

        local y = 90
        love.graphics.print("=== 系统测试 ===", 30, y)
        y = y + 22

        -- 鼠标位置
        local mx, my = Input.get_mouse_position()
        love.graphics.print(string.format("鼠标位置: (%d, %d)", mx, my), 30, y)
        y = y + 20

        -- 点击次数
        love.graphics.print(string.format("鼠标点击: %d 次", self.click_count), 30, y)
        y = y + 20

        -- 空格次数
        love.graphics.print(string.format("空格按下: %d 次", self.space_count), 30, y)
        y = y + 20

        -- 事件触发
        love.graphics.print(string.format("事件触发: %d 次", self.event_triggered), 30, y)
        y = y + 20

        -- FPS
        love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 30, y)
        y = y + 20

        -- 资源统计
        local stats = ResourceManager.get_stats()
        love.graphics.print(string.format("已加载资源: %d", stats.total_loaded), 30, y)
        y = y + 20

        -- 提示
        love.graphics.setColor(0.8, 0.8, 0.8, 1)
        love.graphics.print("ESC 返回启动页 | 空格计数 | 鼠标点击测试", 30, y)

        love.graphics.setFont(love.graphics.newFont(12))
    end)

    -- Layer 4: DEBUG - 调试层
    RenderLayer.add("DEBUG", function()
        local w, h = love.graphics.getDimensions()

        -- 显示更多调试信息
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.print("=== DEBUG INFO ===", 10, 10)
        love.graphics.print("Scene: test_scene", 10, 30)
        love.graphics.print("Layers: BG(底) -> GAME -> EFFECTS -> UI -> DEBUG(顶)", 10, 50)
        love.graphics.print("按 F1 隐藏调试层", 10, 70)

        -- 显示渲染层统计
        local counts = RenderLayer.get_draw_counts()
        local y = 100
        love.graphics.print("Draw counts:", 10, y)
        y = y + 18
        for name, count in pairs(counts) do
            love.graphics.print(string.format("  %s: %d", name, count), 10, y)
            y = y + 16
        end

        love.graphics.setColor(1, 1, 1, 1)
    end)

    -- ========== 测试资源加载 ==========
    -- 加载同一张图片两次，验证缓存机制
    Logger.debug("TestScene: testing resource cache...")

    -- 第一次加载
    -- 因为没有实际图片，会用占位图，但缓存机制仍然工作
    local test_img = ResourceManager.get_image("test_image.png")
    self.test_image_loaded = true

    Logger.info("TestScene: ready")
end

-- ============================================================
-- 每帧更新
-- ============================================================

function TestScene:update(dt)
    -- 验证 dt 时间步长（移动是 dt * speed，证明帧率无关）
    -- 圆左右移动
    self.circle_x = self.circle_x + self.circle_speed * dt

    -- 碰到边界反弹
    local w = love.graphics.getWidth()
    if self.circle_x > w - 40 then
        self.circle_x = w - 40
        self.circle_speed = -math.abs(self.circle_speed)
    elseif self.circle_x < 40 then
        self.circle_x = 40
        self.circle_speed = math.abs(self.circle_speed)
    end

    -- 空格计数
    if Input.is_pressed("space") then
        self.space_count = self.space_count + 1
        Logger.debugf("TestScene: space pressed #%d", self.space_count)

        -- 测试 ResourceManager 缓存：每次空格都 get 同一张图
        -- 日志应该显示 cache hit
        ResourceManager.get_image("test_image.png")
    end

    -- ESC 返回 boot 场景
    if Input.is_pressed("cancel") then
        Logger.debug("TestScene: ESC pressed, returning to boot scene")
        Core.SceneManager.switch("boot")
    end
end

-- ============================================================
-- 每帧绘制
-- ============================================================

function TestScene:draw()
    -- 用 RenderLayer 分层绘制
    RenderLayer.draw()
end

-- ============================================================
-- 场景退出
-- ============================================================

function TestScene:exit()
    Logger.debug("TestScene: exit")

    -- 取消事件订阅（重要！防止内存泄漏）
    EventBus.off("input:mouse_pressed", self._on_mouse_click)

    -- 清空所有绘制项
    RenderLayer.clear_all()
end

return TestScene
