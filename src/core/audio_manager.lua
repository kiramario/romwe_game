-- 模块名: audio_manager
-- 功能: 音频管理器
-- 说明: 封装音效和背景音乐的加载、播放、音量控制
-- 类比: 音频播放管理器，类似 HTML5 Audio API 的封装
--
-- 支持两种音频:
--   - sound effect (sfx): 短音效，如按钮点击、吃子、将军
--   - music: 背景音乐，循环播放
--
-- 三档音量: master / sfx / music

-- 注意：这个模块属于 core 层，所以直接 require 同级模块
-- 不要 require("src.core")，否则会循环依赖
local Logger = require("src.core.logger")
local Config = require("src.core.config")

local AudioManager = {}

-- ============================================================
-- 内部状态
-- ============================================================

local _sfx_cache = {}      -- 音效缓存 { name: source }
local _music_source = nil  -- 当前背景音乐
local _music_name = nil    -- 当前背景音乐名称

local _master_volume = 1.0
local _sfx_volume = 0.7
local _music_volume = 0.5

local _initialized = false

-- ============================================================
-- 初始化
-- ============================================================

function AudioManager.init()
    if _initialized then return end

    -- 从配置读取音量（如果配置里有）
    local master = Config.get("audio.master_volume")
    local sfx = Config.get("audio.sfx_volume")
    local music = Config.get("audio.music_volume")

    if master ~= nil then _master_volume = master end
    if sfx ~= nil then _sfx_volume = sfx end
    if music ~= nil then _music_volume = music end

    -- 生成默认音效（程序合成，无需外部文件）
    _generate_default_sfx()

    _initialized = true
    Logger.info("AudioManager: initialized")
end

-- ============================================================
-- 生成默认音效（程序合成，作为占位）
-- 真正的游戏应该用外部音频文件
-- ============================================================

function _generate_default_sfx()
    -- 按钮点击: 短促的 click 声
    _sfx_cache["click"] = _generate_tone(880, 0.05, "square", 0.15)

    -- 移动棋子: 低沉的 "咚"
    _sfx_cache["move"] = _generate_tone(220, 0.12, "sine", 0.25)

    -- 吃子: 稍响的 "啪"
    _sfx_cache["capture"] = _generate_tone(165, 0.18, "triangle", 0.35)

    -- 将军: 警示音
    _sfx_cache["check"] = _generate_tone_sequence({440, 660}, 0.12, "square", 0.3)

    -- 游戏结束: 下行音阶
    _sfx_cache["game_over"] = _generate_tone_sequence({523, 392, 330, 262}, 0.15, "triangle", 0.3)

    -- 选择/高亮: 清脆的 "叮"
    _sfx_cache["select"] = _generate_tone(1200, 0.04, "sine", 0.2)

    -- 非法操作: 错误提示
    _sfx_cache["error"] = _generate_tone(150, 0.15, "sawtooth", 0.2)

    Logger.debug("AudioManager: generated default SFX (procedural)")
end

-- 生成一个单音调音效
-- @param freq (number) 频率 Hz
-- @param duration (number) 时长秒
-- @param wave_type (string) 波形: sine, square, triangle, sawtooth (用sine近似)
-- @param volume (number) 音量 0-1
function _generate_tone(freq, duration, wave_type, volume)
    -- Lua 里没有直接生成波形的函数，我们用 SampleData 手动生成
    -- LÖVE2D 11+ 支持 SoundData
    local sample_rate = 44100
    local samples = math.floor(sample_rate * duration)

    local sound_data = love.sound.newSoundData(samples, sample_rate, 16, 1)

    for i = 0, samples - 1 do
        local t = i / sample_rate
        local sample = 0

        if wave_type == "sine" then
            sample = math.sin(2 * math.pi * freq * t)
        elseif wave_type == "square" then
            sample = math.sin(2 * math.pi * freq * t) > 0 and 1 or -1
        elseif wave_type == "triangle" then
            -- 三角波: 2 * |2*(t*f - floor(t*f + 0.5))| - 1
            local phase = (t * freq) % 1
            sample = 2 * math.abs(2 * (phase - 0.5)) - 1
        elseif wave_type == "sawtooth" then
            local phase = (t * freq) % 1
            sample = 2 * phase - 1
        else
            sample = math.sin(2 * math.pi * freq * t)
        end

        -- 包络: 快速起音，缓慢衰减（ADSR 的简化版）
        local envelope = 1.0
        local attack = 0.005  -- 5ms 起音
        local release_start = duration * 0.7  -- 70% 后开始衰减

        if t < attack then
            envelope = t / attack  -- 淡入
        elseif t > release_start then
            envelope = 1 - (t - release_start) / (duration - release_start)  -- 淡出
        end

        sample = sample * volume * envelope

        -- 写入 16-bit 有符号整数
        local int_sample = math.floor(sample * 32767)
        if int_sample > 32767 then int_sample = 32767 end
        if int_sample < -32768 then int_sample = -32768 end
        sound_data:setSample(i, int_sample / 32767)  -- LÖVE2D 用 -1 到 1 的浮点数
    end

    local source = love.audio.newSource(sound_data, "static")
    return source
end

-- 生成一个音调序列（多个音调依次播放）
function _generate_tone_sequence(frequencies, note_duration, wave_type, volume)
    local total_duration = note_duration * #frequencies
    local sample_rate = 44100
    local total_samples = math.floor(sample_rate * total_duration)

    local sound_data = love.sound.newSoundData(total_samples, sample_rate, 16, 1)

    for i = 0, total_samples - 1 do
        local t = i / sample_rate
        local note_index = math.floor(t / note_duration)
        if note_index >= #frequencies then note_index = #frequencies - 1 end

        local freq = frequencies[note_index + 1]  -- Lua 数组从 1 开始
        local note_t = t - note_index * note_duration

        local sample = 0
        if wave_type == "sine" then
            sample = math.sin(2 * math.pi * freq * note_t)
        elseif wave_type == "square" then
            sample = math.sin(2 * math.pi * freq * note_t) > 0 and 1 or -1
        elseif wave_type == "triangle" then
            local phase = (note_t * freq) % 1
            sample = 2 * math.abs(2 * (phase - 0.5)) - 1
        else
            sample = math.sin(2 * math.pi * freq * note_t)
        end

        -- 每个音符独立包络
        local envelope = 1.0
        local attack = 0.005
        local release_start = note_duration * 0.8

        if note_t < attack then
            envelope = note_t / attack
        elseif note_t > release_start then
            envelope = 1 - (note_t - release_start) / (note_duration - release_start)
        end

        sample = sample * volume * envelope

        local int_sample = math.floor(sample * 32767)
        if int_sample > 32767 then int_sample = 32767 end
        if int_sample < -32768 then int_sample = -32768 end
        sound_data:setSample(i, int_sample / 32767)
    end

    local source = love.audio.newSource(sound_data, "static")
    return source
end

-- ============================================================
-- 音效 (SFX)
-- ============================================================

-- 播放音效
-- @param name (string) 音效名称
-- @param volume (number) 可选，单独音量倍率
function AudioManager.play_sfx(name, volume)
    if not _initialized then AudioManager.init() end

    local source = _sfx_cache[name]
    if not source then
        Logger.warnf("AudioManager: SFX '%s' not found", name)
        return
    end

    -- 复制一份，这样可以叠加播放多个相同音效
    local clone = source:clone()
    local vol = _master_volume * _sfx_volume * (volume or 1.0)
    clone:setVolume(vol)
    clone:play()

    Logger.debugf("AudioManager: play sfx '%s' (vol=%.2f)", name, vol)

    return clone
end

-- 注册外部音效文件
-- @param name (string) 音效名称
-- @param path (string) 文件路径
-- @param type (string) "static" (短音效) 或 "stream" (长音频)
function AudioManager.register_sfx(name, path, audio_type)
    audio_type = audio_type or "static"

    local source = love.audio.newSource(path, audio_type)
    _sfx_cache[name] = source

    Logger.infof("AudioManager: registered SFX '%s' from %s", name, path)
end

-- ============================================================
-- 背景音乐
-- ============================================================

-- 播放背景音乐
-- @param name (string) 音乐名称（需先 register_music）或文件路径
-- @param loop (boolean) 是否循环，默认 true
function AudioManager.play_music(name, loop)
    if not _initialized then AudioManager.init() end

    if loop == nil then loop = true end

    -- 如果已经在播放这首，就不重新开始
    if _music_name == name and _music_source and _music_source:isPlaying() then
        return
    end

    -- 停止当前音乐
    if _music_source then
        _music_source:stop()
        _music_source = nil
    end

    local source = _sfx_cache[name]  -- 复用缓存结构
    if not source then
        -- 尝试从文件加载
        if love.filesystem.getInfo(name) then
            source = love.audio.newSource(name, "stream")
            _sfx_cache[name] = source
        else
            Logger.warnf("AudioManager: music '%s' not found", name)
            return
        end
    end

    -- 克隆一份用于播放
    _music_source = source:clone()
    _music_source:setLooping(loop)
    _music_source:setVolume(_master_volume * _music_volume)
    _music_source:play()
    _music_name = name

    Logger.infof("AudioManager: play music '%s'", name)
end

-- 停止背景音乐
function AudioManager.stop_music()
    if _music_source then
        _music_source:stop()
        _music_source = nil
        _music_name = nil
    end
end

-- 暂停背景音乐
function AudioManager.pause_music()
    if _music_source and _music_source:isPlaying() then
        _music_source:pause()
    end
end

-- 恢复背景音乐
function AudioManager.resume_music()
    if _music_source and not _music_source:isPlaying() then
        _music_source:play()
    end
end

-- ============================================================
-- 音量控制
-- ============================================================

-- 设置主音量
function AudioManager.set_master_volume(vol)
    _master_volume = math.max(0, math.min(1, vol))
    _update_all_volumes()
    Config.set("audio.master_volume", _master_volume)
    Logger.debugf("AudioManager: master volume = %.2f", _master_volume)
end

-- 设置音效音量
function AudioManager.set_sfx_volume(vol)
    _sfx_volume = math.max(0, math.min(1, vol))
    Config.set("audio.sfx_volume", _sfx_volume)
    Logger.debugf("AudioManager: sfx volume = %.2f", _sfx_volume)
end

-- 设置音乐音量
function AudioManager.set_music_volume(vol)
    _music_volume = math.max(0, math.min(1, vol))
    _update_all_volumes()
    Config.set("audio.music_volume", _music_volume)
    Logger.debugf("AudioManager: music volume = %.2f", _music_volume)
end

-- 获取音量
function AudioManager.get_master_volume() return _master_volume end
function AudioManager.get_sfx_volume() return _sfx_volume end
function AudioManager.get_music_volume() return _music_volume end

-- 更新所有正在播放的音量
function _update_all_volumes()
    -- 更新背景音乐
    if _music_source then
        _music_source:setVolume(_master_volume * _music_volume)
    end
    -- 注意: 已播放的音效不会变音量（因为是短音效）
    -- 新播放的音效会用新音量
end

-- ============================================================
-- 静音切换
-- ============================================================

local _muted = false
local _prev_master_volume = 1.0

function AudioManager.toggle_mute()
    if _muted then
        _master_volume = _prev_master_volume
        _muted = false
        if _music_source then _music_source:play() end
    else
        _prev_master_volume = _master_volume
        _master_volume = 0
        _muted = true
        if _music_source then _music_source:pause() end
    end
    _update_all_volumes()
    return not _muted
end

function AudioManager.is_muted()
    return _muted
end

-- ============================================================
-- 列出所有可用音效
-- ============================================================

function AudioManager.list_sfx()
    local names = {}
    for name, _ in pairs(_sfx_cache) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

return AudioManager
