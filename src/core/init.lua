-- Core 模块入口
-- 统一导出所有 core 模块
-- 类比: Python 的 __init__.py / Java 的 package
--
-- 用法: local Core = require("src.core")
--       Core.Logger.info("hello")
--       Core.SceneManager.switch("menu")

local Core = {}

-- 按依赖顺序加载模块
-- 注意: 加载顺序很重要，被依赖的要先加载

-- 最底层 - 工具函数
Core.Utils = require("src.core.utils")

-- 基础设施
Core.Logger = require("src.core.logger")
Core.Config = require("src.core.config")
Core.EventBus = require("src.core.event_bus")

-- 输入系统
Core.Input = require("src.core.input")

-- 资源管理
Core.ResourceManager = require("src.core.resource_manager")

-- 渲染系统
Core.RenderLayer = require("src.core.render_layer")

-- 音频系统
Core.AudioManager = require("src.core.audio_manager")

-- 场景管理（依赖上面的很多模块）
Core.SceneManager = require("src.core.scene_manager")

-- 初始化所有 core 模块
-- 由 main.lua 在游戏启动时调用
function Core.init()
    Core.Logger.debug("Core: initializing all modules...")

    -- 按顺序初始化
    Core.Config.init()
    Core.Input.init()

    Core.Logger.info("Core: all modules initialized")
end

-- 每帧更新
function Core.update(dt)
    Core.Input.update(dt)
    Core.SceneManager.update(dt)
end

-- 每帧绘制
function Core.draw()
    Core.SceneManager.draw()
end

-- 退出时清理
function Core.quit()
    Core.Logger.info("Core: shutting down...")
    Core.Config.save()
    Core.ResourceManager.unload_all()
    Core.EventBus.clear_all()
    Core.Logger.info("Core: shutdown complete")
end

return Core
