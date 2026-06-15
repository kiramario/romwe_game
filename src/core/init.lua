-- Core 模块入口
-- 统一导出所有 core 模块
-- 类比: Python 的 __init__.py / Java 的 package

local Core = {}

-- 按依赖顺序加载模块
Core.Utils = require("src.core.utils")
Core.Logger = require("src.core.logger")
Core.Config = require("src.core.config")
Core.EventBus = require("src.core.event_bus")
Core.Input = require("src.core.input")
Core.ResourceManager = require("src.core.resource_manager")
Core.RenderLayer = require("src.core.render_layer")
Core.AudioManager = require("src.core.audio_manager")
Core.SceneManager = require("src.core.scene_manager")

-- 初始化所有 core 模块
function Core.init()
    Core.Logger.debug("Core: initializing all modules...")
    Core.Config.init()
    Core.Input.init()
    Core.Logger.info("Core: all modules initialized")
end

-- 每帧更新（由 main.lua 调用，Input.update 已在 main.lua 中调用）
function Core.update(dt)
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
