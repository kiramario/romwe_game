-- 模块名: button
-- 功能: 按钮 UI 组件
-- 说明: 可点击的文字按钮，支持悬停、按下、禁用状态
-- 类比: HTML 的 <button> / Unity 的 Button 组件

local Core = require("src.core")
local Logger = Core.Logger
local EventBus = Core.EventBus
local Input = Core.Input
local ResourceManager = Core.ResourceManager

local Button = {}
Button.__index = Button  -- 用于 metatable 的 __index（类比原型链）

-- ============================================================
-- 按钮状态
-- ============================================================

Button.STATE = {
    NORMAL = "normal",     -- 正常
    HOVER = "hover",       -- 悬停
    PRESSED = "pressed",   -- 按下
    DISABLED = "disabled", -- 禁用
}

-- ============================================================
-- 构造函数
-- ============================================================

-- 创建一个新按钮
-- 类比: new Button() (JS/Java)
-- @param options (table) 配置选项
--   - x, y: 位置（左上角）
--   - width, height: 尺寸
--   - text: 按钮文字
--   - font: 字体（可选，默认 16px）
--   - font_size: 字号（可选，默认 16）
--   - on_click: 点击回调函数
--   - colors: 各状态颜色（可选）
-- @return (Button) 新按钮实例
function Button.new(options)
    local self = setmetatable({}, Button)

    -- 位置和尺寸
    self.x = options.x or 0
    self.y = options.y or 0
    self.width = options.width or 200
    self.height = options.height or 50

    -- 文字
    self.text = options.text or "Button"
    self.font_size = options.font_size or 16
    self.font_path = options.font_path  -- 字体文件路径

    -- 回调
    self.on_click = options.on_click  -- 点击回调

    -- 状态
    self.state = Button.STATE.NORMAL
    self.enabled = true

    -- 颜色配置（各状态）
    -- 格式: { bg = {r,g,b,a}, text = {r,g,b,a}, border = {r,g,b,a} }
    self.colors = options.colors or {
        normal = {
            bg = {0.2, 0.2, 0.3, 1},
            text = {1, 1, 1, 1},
            border = {0.4, 0.4, 0.5, 1},
        },
        hover = {
            bg = {0.3, 0.3, 0.45, 1},
            text = {1, 1, 1, 1},
            border = {0.6, 0.6, 0.7, 1},
        },
        pressed = {
            bg = {0.15, 0.15, 0.25, 1},
            text = {0.9, 0.9, 1, 1},
            border = {0.3, 0.3, 0.4, 1},
        },
        disabled = {
            bg = {0.1, 0.1, 0.15, 1},
            text = {0.5, 0.5, 0.5, 1},
            border = {0.2, 0.2, 0.25, 1},
        },
    }

    -- 圆角半径（0 表示直角）
    self.corner_radius = options.corner_radius or 6

    -- 边框宽度
    self.border_width = options.border_width or 2

    -- 内部边距
    self.padding = options.padding or 10

    -- 加载字体
    if self.font_path then
        self.font = ResourceManager.get_font(self.font_path, self.font_size)
    else
        self.font = ResourceManager.get_font(nil, self.font_size)
    end

    Logger.debugf("Button: created '%s'", self.text)
    return self
end

-- ============================================================
-- 公共方法
-- ============================================================

-- 设置位置
-- @param x, y (number) 新位置
function Button:set_position(x, y)
    self.x = x
    self.y = y
end

-- 设置尺寸
function Button:set_size(width, height)
    self.width = width
    self.height = height
end

-- 设置文字
function Button:set_text(text)
    self.text = text
end

-- 设置是否启用
function Button:set_enabled(enabled)
    self.enabled = enabled
    if not enabled then
        self.state = Button.STATE.DISABLED
    else
        self.state = Button.STATE.NORMAL
    end
end

-- 检查点是否在按钮内
-- @param px, py (number) 点坐标
-- @return (boolean) 是否在按钮内
function Button:contains_point(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
end

-- ============================================================
-- 更新（每帧调用）
-- 处理鼠标悬停、点击检测
-- ============================================================

function Button:update(dt)
    if not self.enabled then
        self.state = Button.STATE.DISABLED
        return
    end

    local mx, my = Input.get_mouse_position()
    local is_inside = self:contains_point(mx, my)

    if is_inside then
        if Input.is_mouse_pressed(1) then
            -- 鼠标刚按下
            self.state = Button.STATE.PRESSED
        elseif Input.is_mouse_held(1) and self.state == Button.STATE.PRESSED then
            -- 保持按下状态
            self.state = Button.STATE.PRESSED
        else
            -- 悬停
            self.state = Button.STATE.HOVER
        end

        -- 检测点击（鼠标在按钮内松开）
        if Input.is_mouse_released(1) and self.state == Button.STATE.PRESSED then
            self:handle_click()
            self.state = Button.STATE.HOVER  -- 松开后回到悬停状态
        end
    else
        -- 鼠标不在按钮内，恢复正常状态
        self.state = Button.STATE.NORMAL
    end
end

-- 处理点击
-- 可以被子类重写，或通过 on_click 回调
function Button:handle_click()
    Logger.debugf("Button: clicked '%s'", self.text)

    if self.on_click then
        -- 用 pcall 保护，防止回调出错
        local success, err = pcall(self.on_click, self)
        if not success then
            Logger.errorf("Button: error in on_click for '%s': %s", self.text, err)
        end
    end

    -- 发布事件
    EventBus.emit("button:clicked", self.text, self)
end

-- ============================================================
-- 绘制
-- ============================================================

function Button:draw()
    local colors = self.colors[self.state] or self.colors.normal

    -- 绘制按钮背景
    love.graphics.setColor(colors.bg)
    if self.corner_radius > 0 then
        -- 圆角矩形
        -- 用 rectangle 的 "round" 模式
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height,
            self.corner_radius, self.corner_radius)
    else
        -- 直角矩形
        love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
    end

    -- 绘制边框
    if self.border_width > 0 then
        love.graphics.setColor(colors.border)
        love.graphics.setLineWidth(self.border_width)
        if self.corner_radius > 0 then
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height,
                self.corner_radius, self.corner_radius)
        else
            love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
        end
        love.graphics.setLineWidth(1)  -- 重置线宽
    end

    -- 绘制文字（居中）
    love.graphics.setColor(colors.text)
    if self.font then
        love.graphics.setFont(self.font)
    end

    local text_w = self.font:getWidth(self.text)
    local text_h = self.font:getHeight()
    local text_x = self.x + (self.width - text_w) / 2
    local text_y = self.y + (self.height - text_h) / 2

    -- 按下状态时文字微微下移，增加按压感
    if self.state == Button.STATE.PRESSED then
        text_y = text_y + 2
    end

    love.graphics.print(self.text, text_x, text_y)

    -- 恢复默认字体和颜色
    love.graphics.setColor(1, 1, 1, 1)
end

return Button
