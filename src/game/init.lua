-- Game 层入口
-- 初始化游戏，注册所有场景
-- 类比: 应用的业务逻辑入口

local Core = require("src.core")

local Game = {}

-- 游戏版本号
Game.version = "0.0.1"
Game.name = "Chinese Chess"

-- 初始化游戏
-- 由 main.lua 在 love.load 中调用
function Game.init()
    Core.Logger.debug("Game: initializing...")

    -- 注册所有场景
    -- V0 只有两个场景：boot 和 test
    -- 后续版本会加 menu, game, settings 等
    local BootScene = require("src.game.scenes.boot_scene")
    local TestScene = require("src.game.scenes.test_scene")

    Core.SceneManager.register("boot", BootScene)
    Core.SceneManager.register("test", TestScene)

    -- 启动 boot 场景
    Core.SceneManager.switch("boot")

    Core.Logger.info("Game: initialized (version " .. Game.version .. ")")
end

return Game
