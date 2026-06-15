-- Game 层入口
-- 初始化游戏，注册所有场景
-- 类比: 应用的业务逻辑入口

local Core = require("src.core")

local Game = {}

-- 游戏版本号和名称
Game.version = "5.0.0"
Game.name = "romwe_game"

-- 初始化游戏
-- 由 main.lua 在 love.load 中调用
function Game.init()
    Core.Logger.debug("Game: initializing...")

    -- 注册所有场景
    local BootScene = require("src.game.scenes.boot_scene")
    local MenuScene = require("src.game.scenes.menu_scene")
    local SelectGameScene = require("src.game.scenes.select_game_scene")
    local GameScene = require("src.game.scenes.game_scene")
    local PinballScene = require("src.game.scenes.pinball_scene")
    local SettingsScene = require("src.game.scenes.settings_scene")
    local TestScene = require("src.game.scenes.test_scene")

    Core.SceneManager.register("boot", BootScene)
    Core.SceneManager.register("menu", MenuScene)
    Core.SceneManager.register("select_game", SelectGameScene)
    Core.SceneManager.register("game", GameScene)
    Core.SceneManager.register("pinball", PinballScene)
    Core.SceneManager.register("settings", SettingsScene)
    Core.SceneManager.register("test", TestScene)

    -- 初始化音频
    if Core.AudioManager and Core.AudioManager.init then
        Core.AudioManager.init()
    end

    -- 设置场景过渡时长
    Core.SceneManager.set_transition_duration(0.35)

    -- 启动 boot 场景
    Core.SceneManager.switch("boot")

    Core.Logger.info("Game: initialized " .. Game.name .. " v" .. Game.version)
end

return Game
