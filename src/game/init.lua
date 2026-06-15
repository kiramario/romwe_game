-- Game 层入口
-- 初始化游戏，注册所有场景
-- 类比: 应用的业务逻辑入口

local Core = require("src.core")

local Game = {}

-- 游戏版本号
Game.version = "1.0.0"
Game.name = "Chinese Chess"

-- 初始化游戏
-- 由 main.lua 在 love.load 中调用
function Game.init()
    Core.Logger.debug("Game: initializing...")

    -- 注册所有场景
    -- V1 版本场景
    local BootScene = require("src.game.scenes.boot_scene")
    local MenuScene = require("src.game.scenes.menu_scene")
    local GameScene = require("src.game.scenes.game_scene")
    local TestScene = require("src.game.scenes.test_scene")  -- 保留测试场景用于调试

    Core.SceneManager.register("boot", BootScene)
    Core.SceneManager.register("menu", MenuScene)
    Core.SceneManager.register("game", GameScene)
    Core.SceneManager.register("test", TestScene)

    -- 设置场景过渡时长
    Core.SceneManager.set_transition_duration(0.35)

    -- 启动 boot 场景
    Core.SceneManager.switch("boot")

    Core.Logger.info("Game: initialized (version " .. Game.version .. ")")
end

return Game
