-- conf.lua
-- LÖVE2D 配置文件
-- 这个文件在游戏启动时最先加载，在 love.load 之前执行
-- 只能配置，不能写游戏逻辑
-- 类比：网页的 <head> 里的 meta 标签，或者 Java 的 properties 文件

function love.conf(t)
    -- ========== 窗口配置 ==========
    t.identity = "romwe_game"          -- 存档目录名（重要：决定存档位置）
    t.window.title = "romwe_game"       -- 窗口标题（会在 game.init 后更新为带版本号的）
    t.window.width = 1280          -- 窗口宽度（像素）
    t.window.height = 720          -- 窗口高度（像素）
    t.window.resizable = true      -- 允许用户调整窗口大小
    t.window.minwidth = 800        -- 最小宽度
    t.window.minheight = 600       -- 最小高度
    t.window.fullscreen = false    -- 是否全屏启动
    t.window.fullscreentype = "desktop"  -- 全屏类型
    t.window.vsync = 1             -- 垂直同步（1=开启，0=关闭）
    t.window.msaa = 0              -- 多重采样抗锯齿（0=关闭）
    t.window.display = 1           -- 显示在第几个显示器
    t.window.highdpi = false       -- 高 DPI 支持（Retina 屏）

    -- ========== 版本信息 ==========
    t.version = "11.5"             -- LÖVE2D 版本要求
    t.console = false              -- Windows 下是否打开控制台窗口（调试时可设为 true）

    -- ========== 模块开关 ==========
    t.modules.audio = true         -- 音频模块
    t.modules.event = true         -- 事件处理
    t.modules.graphics = true      -- 图形渲染
    t.modules.image = true         -- 图片加载
    t.modules.joystick = false     -- 手柄支持
    t.modules.keyboard = true      -- 键盘输入
    t.modules.math = true          -- 数学函数
    t.modules.mouse = true         -- 鼠标输入
    t.modules.physics = false      -- 物理引擎
    t.modules.sound = true         -- 音效
    t.modules.system = true        -- 系统信息
    t.modules.timer = true         -- 计时器
    t.modules.touch = false        -- 触屏
    t.modules.video = false        -- 视频播放
    t.modules.window = true        -- 窗口管理
    t.modules.thread = true        -- 多线程
    t.modules.filesystem = true    -- 文件系统
end
