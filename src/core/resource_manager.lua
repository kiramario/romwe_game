-- 模块名: resource_manager
-- 功能: 资源管理器
-- 说明: 加载和缓存图片、音效、字体等资源，避免重复加载
-- 类比: Webpack 资源打包 / Unity AssetDatabase / 资源缓存池

local Logger = require("src.core.logger")

local ResourceManager = {}

-- ============================================================
-- 内部状态
-- ============================================================

-- 资源缓存
-- 结构: { path = resource_object }
local _images = {}    -- 图片缓存
local _fonts = {}     -- 字体缓存（按路径+字号索引）
local _sounds = {}    -- 音效缓存（V4 再完善）

-- 资源路径前缀
local IMAGE_PATH = "assets/images/"
local SOUND_PATH = "assets/sounds/"
local FONT_PATH = "assets/fonts/"

-- 统计
local _stats = {
    images_loaded = 0,
    fonts_loaded = 0,
    sounds_loaded = 0,
    cache_hits = 0,
    cache_misses = 0,
}

-- 占位图（加载失败时用）
local _placeholder_image = nil

-- ============================================================
-- 内部函数
-- ============================================================

-- 创建占位图（加载失败时显示）
-- 用程序生成一个灰色方块，不依赖外部资源
local function _create_placeholder()
    if _placeholder_image then
        return _placeholder_image
    end

    -- 用 Canvas 生成一个 64x64 的灰色方块
    -- 类比: 离屏 Canvas / RenderTexture
    local canvas = love.graphics.newCanvas(64, 64)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0.5, 0.5, 0.5, 1)  -- 灰色
    love.graphics.setColor(1, 0, 0, 1)     -- 红色 X
    love.graphics.line(0, 0, 64, 64)
    love.graphics.line(64, 0, 0, 64)
    love.graphics.setCanvas()  -- 恢复默认渲染目标
    love.graphics.setColor(1, 1, 1, 1)  -- 重置颜色

    _placeholder_image = canvas
    return _placeholder_image
end

-- ============================================================
-- 图片资源
-- ============================================================

-- 获取图片（自动缓存）
-- 第一次调用从磁盘加载，后面直接返回缓存
-- 类比: import image from './img.png' （打包后的资源）
-- @param path (string) 图片路径（相对于 assets/images/）
-- @return (Image) LÖVE2D Image 对象，失败返回占位图
function ResourceManager.get_image(path)
    -- 检查缓存
    if _images[path] then
        _stats.cache_hits = _stats.cache_hits + 1
        Logger.debugf("ResourceManager: image cache hit: %s", path)
        return _images[path]
    end

    _stats.cache_misses = _stats.cache_misses + 1

    -- 加载图片
    local full_path = IMAGE_PATH .. path
    Logger.debugf("ResourceManager: loading image: %s", full_path)

    local success, result = pcall(function()
        return love.graphics.newImage(full_path)
    end)

    if success and result then
        _images[path] = result
        _stats.images_loaded = _stats.images_loaded + 1
        Logger.infof("ResourceManager: image loaded: %s", path)
        return result
    else
        Logger.warnf("ResourceManager: failed to load image: %s", full_path)
        return _create_placeholder()
    end
end

-- 检查图片是否已加载
-- @param path (string) 图片路径
-- @return (boolean) 是否已加载
function ResourceManager.has_image(path)
    return _images[path] ~= nil
end

-- 卸载单张图片
-- @param path (string) 图片路径
function ResourceManager.unload_image(path)
    if _images[path] then
        _images[path] = nil
        Logger.debugf("ResourceManager: unloaded image: %s", path)
    end
end

-- ============================================================
-- 字体资源
-- ============================================================

-- 获取字体（自动缓存）
-- 字体按 "路径_字号" 作为缓存键，因为不同字号是不同的资源
-- @param path (string) 字体路径（相对于 assets/fonts/），nil 则用默认字体
-- @param size (number) 字号（像素）
-- @return (Font) LÖVE2D Font 对象
function ResourceManager.get_font(path, size)
    size = size or 16

    -- 缓存键：路径_字号
    local cache_key
    if path then
        cache_key = path .. "_" .. tostring(size)
    else
        cache_key = "default_" .. tostring(size)
    end

    -- 检查缓存
    if _fonts[cache_key] then
        _stats.cache_hits = _stats.cache_hits + 1
        return _fonts[cache_key]
    end

    _stats.cache_misses = _stats.cache_misses + 1

    -- 加载字体
    Logger.debugf("ResourceManager: loading font: %s (size %d)", path or "default", size)

    local font
    if path then
        local full_path = FONT_PATH .. path
        local success, result = pcall(function()
            return love.graphics.newFont(full_path, size)
        end)
        if success and result then
            font = result
        else
            Logger.warnf("ResourceManager: failed to load font: %s", full_path)
            -- 失败则用默认字体
            font = love.graphics.newFont(size)
        end
    else
        -- 使用 LÖVE2D 默认字体
        font = love.graphics.newFont(size)
    end

    _fonts[cache_key] = font
    _stats.fonts_loaded = _stats.fonts_loaded + 1
    return font
end

-- 检查字体是否已加载
function ResourceManager.has_font(path, size)
    local cache_key
    if path then
        cache_key = path .. "_" .. tostring(size)
    else
        cache_key = "default_" .. tostring(size)
    end
    return _fonts[cache_key] ~= nil
end

-- 卸载字体
function ResourceManager.unload_font(path, size)
    local cache_key
    if path then
        cache_key = path .. "_" .. tostring(size)
    else
        cache_key = "default_" .. tostring(size)
    end
    if _fonts[cache_key] then
        _fonts[cache_key] = nil
        Logger.debugf("ResourceManager: unloaded font: %s", cache_key)
    end
end

-- ============================================================
-- 音效资源（V4 完善，V0 先占坑）
-- ============================================================

-- 获取音效（自动缓存）
-- V0 先占位，V4 再完善
-- @param path (string) 音效路径
-- @param type (string) "static" (短音效) 或 "stream" (长音乐)
-- @return (Source) LÖVE2D Source 对象
function ResourceManager.get_sound(path, stype)
    stype = stype or "static"

    local cache_key = path .. "_" .. stype

    if _sounds[cache_key] then
        _stats.cache_hits = _stats.cache_hits + 1
        return _sounds[cache_key]
    end

    _stats.cache_misses = _stats.cache_misses + 1

    local full_path = SOUND_PATH .. path
    Logger.debugf("ResourceManager: loading sound: %s", full_path)

    local success, result = pcall(function()
        return love.audio.newSource(full_path, stype)
    end)

    if success and result then
        _sounds[cache_key] = result
        _stats.sounds_loaded = _stats.sounds_loaded + 1
        return result
    else
        Logger.warnf("ResourceManager: failed to load sound: %s", full_path)
        return nil
    end
end

-- ============================================================
-- 批量加载 / 卸载
-- ============================================================

-- 预加载一组资源
-- 用于场景切换时的加载画面
-- @param resources (table) { images = {...}, fonts = {...}, sounds = {...} }
function ResourceManager.preload(resources)
    local count = 0
    local total = 0

    if resources.images then
        total = total + #resources.images
        for _, path in ipairs(resources.images) do
            ResourceManager.get_image(path)
            count = count + 1
        end
    end

    if resources.fonts then
        for _, font_info in ipairs(resources.fonts) do
            ResourceManager.get_font(font_info.path, font_info.size)
            count = count + 1
            total = total + 1
        end
    end

    if resources.sounds then
        total = total + #resources.sounds
        for _, path in ipairs(resources.sounds) do
            ResourceManager.get_sound(path)
            count = count + 1
        end
    end

    Logger.infof("ResourceManager: preloaded %d/%d resources", count, total)
    return count, total
end

-- 卸载所有资源
-- 场景切换或游戏退出时调用
function ResourceManager.unload_all()
    local count = _stats.images_loaded + _stats.fonts_loaded + _stats.sounds_loaded

    _images = {}
    _fonts = {}
    _sounds = {}
    _stats.images_loaded = 0
    _stats.fonts_loaded = 0
    _stats.sounds_loaded = 0

    Logger.infof("ResourceManager: unloaded all resources (%d)", count)
end

-- 按组卸载（比如卸载某个场景的所有资源）
-- @param group (table) 资源列表，格式同 preload
function ResourceManager.unload_group(group)
    if group.images then
        for _, path in ipairs(group.images) do
            ResourceManager.unload_image(path)
        end
    end
    -- 字体和音效类似...
end

-- ============================================================
-- 统计与调试
-- ============================================================

-- 获取资源统计
-- @return (table) 统计信息
function ResourceManager.get_stats()
    return {
        images_loaded = _stats.images_loaded,
        fonts_loaded = _stats.fonts_loaded,
        sounds_loaded = _stats.sounds_loaded,
        cache_hits = _stats.cache_hits,
        cache_misses = _stats.cache_misses,
        total_loaded = _stats.images_loaded + _stats.fonts_loaded + _stats.sounds_loaded,
    }
end

-- 获取所有已加载图片列表（调试用）
-- @return (table) 图片路径数组
function ResourceManager.get_loaded_images()
    local list = {}
    for path, _ in pairs(_images) do
        table.insert(list, path)
    end
    return list
end

return ResourceManager
