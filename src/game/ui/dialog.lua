-- 模块名: dialog
-- 功能: 通用弹窗 UI 组件
-- 说明: 带标题、内容、按钮的弹窗，可用于提示、确认、菜单等
-- 类比: HTML 的 modal / 对话框控件

local Core = require("src.core")
local Logger = Core.Logger
local ResourceManager = Core.ResourceManager
local Input = Core.Input
local Utils = Core.Utils

local Dialog = {}
Dialog.__index = Dialog

-- ============================================================
-- 构造函数
-- ============================================================

-- 创建弹窗
-- @param options (table) 配置
--   - title: 标题文字
--   - content: 内容文字（支持多行，用 \n 分隔）
--   - buttons: 按钮列表，每个按钮: { text, on_click, is_default, is_cancel }
--   - width, height: 弹窗大小（可选，自动计算）
--   - x, y: 弹窗位置（可选，默认居中）
--   - font_path: 字体路径
--   - close_on_click_outside: 点击外部是否关闭（默认 false）
-- @return (Dialog) 弹窗实例
function Dialog.new(options)
    local self = setmetatable({}, Dialog)

    options = options or {}

    -- 标题
    self.title = options.title or ""

    -- 内容
    self.content = options.content or ""

    -- 按钮
    self.buttons = {}
    if options.buttons then
        for i, btn in ipairs(options.buttons) do
            table.insert(self.buttons, {
                text = btn.text or "按钮" .. i,
                on_click = btn.on_click,
                is_default = btn.is_default or false,
                is_cancel = btn.is_cancel or false,
                hover = false,
            })
        end
    end

    -- 字体
    self.font_path = options.font_path or "NotoSansSC-Regular.ttc"

    -- 尺寸（先设默认，后面会自动计算）
    self.width = options.width or 400
    self.height = options.height or 250

    -- 位置
    self.x = options.x or 0
    self.y = options.y or 0
    self.centered = (options.x == nil and options.y == nil)

    -- 行为
    self.close_on_click_outside = options.close_on_click_outside or false

    -- 状态
    self.visible = true
    self.alpha = 1

    -- 动画
    self.anim_in = true   -- 进入动画
    self.anim_progress = 0
    self.anim_duration = 0.25

    Logger.debug("Dialog: created with title '" .. self.title .. "'")

    return self
end

-- ============================================================
-- 显示/隐藏
-- ============================================================

function Dialog:show()
    self.visible = true
    self.anim_in = true
    self.anim_progress = 0
end

function Dialog:hide()
    self.visible = false
end

-- ============================================================
-- 计算布局
-- ============================================================

function Dialog:_layout()
    local w, h = love.graphics.getDimensions()

    -- 字体大小
    local title_font_size = 24
    local content_font_size = 16
    local button_font_size = 18

    local title_font = ResourceManager.get_font(self.font_path, title_font_size)
    local content_font = ResourceManager.get_font(self.font_path, content_font_size)
    local button_font = ResourceManager.get_font(self.font_path, button_font_size)

    -- 计算内容高度
    local content_lines = Utils.string_split(self.content, "\n")
    local content_height = #content_lines * content_font:getHeight()

    -- 计算按钮尺寸
    local button_width = 120
    local button_height = 40
    local button_spacing = 15

    local buttons_width = #self.buttons * button_width + (#self.buttons - 1) * button_spacing

    -- 计算弹窗总尺寸
    local padding = 30
    local title_height = title_font:getHeight() + 10
    local gap_after_title = 15
    local gap_before_buttons = 25

    self.width = math.max(self.width, buttons_width + padding * 2, 300)
    self.height = padding * 2 + title_height + gap_after_title +
                  content_height + gap_before_buttons + button_height

    -- 计算位置
    if self.centered then
        self.x = (w - self.width) / 2
        self.y = (h - self.height) / 2
    end

    -- 布局按钮
    local total_buttons_width = #self.buttons * button_width + (#self.buttons - 1) * button_spacing
    local button_start_x = self.x + (self.width - total_buttons_width) / 2
    local button_y = self.y + self.height - padding - button_height

    for i, btn in ipairs(self.buttons) do
        btn.x = button_start_x + (i - 1) * (button_width + button_spacing)
        btn.y = button_y
        btn.width = button_width
        btn.height = button_height
        btn.font = button_font
        btn.font_size = button_font_size
    end

    self._layout_done = true
    self._title_font = title_font
    self._content_font = content_font
end

-- ============================================================
-- 更新
-- ============================================================

function Dialog:update(dt)
    if not self.visible then return end

    -- 确保布局已计算
    if not self._layout_done then
        self:_layout()
    end

    -- 进入动画
    if self.anim_in then
        self.anim_progress = self.anim_progress + dt / self.anim_duration
        if self.anim_progress >= 1 then
            self.anim_progress = 1
            self.anim_in = false
        end
        self.alpha = self.anim_progress
    end

    -- 更新按钮悬停状态
    if self.anim_in == false or self.anim_progress >= 0.5 then
        local mx, my = Input.get_mouse_position()

        for _, btn in ipairs(self.buttons) do
            btn.hover = mx >= btn.x and mx <= btn.x + btn.width and
                        my >= btn.y and my <= btn.y + btn.height
        end
    end
end

-- ============================================================
-- 处理点击
-- 返回 true 表示点击被弹窗消费了
-- ============================================================

function Dialog:handle_click(mx, my)
    if not self.visible then return false end
    if self.anim_in and self.anim_progress < 0.5 then return false end

    -- 检查是否点击了按钮
    for _, btn in ipairs(self.buttons) do
        if mx >= btn.x and mx <= btn.x + btn.width and
           my >= btn.y and my <= btn.y + btn.height then
            if btn.on_click then
                btn.on_click(self)
            end
            return true
        end
    end

    -- 检查是否点击在弹窗内
    local inside = mx >= self.x and mx <= self.x + self.width and
                   my >= self.y and my <= self.y + self.height

    if not inside and self.close_on_click_outside then
        self:hide()
        return true
    end

    -- 点击在弹窗内但没点按钮，消费点击
    return inside
end

-- ============================================================
-- 处理按键
-- 返回 true 表示按键被弹窗消费了
-- ============================================================

function Dialog:handle_key(key)
    if not self.visible then return false end

    if key == "return" or key == "kpenter" then
        -- 回车 = 默认按钮
        for _, btn in ipairs(self.buttons) do
            if btn.is_default and btn.on_click then
                btn.on_click(self)
                return true
            end
        end
    end

    if key == "escape" then
        -- ESC = 取消按钮 或 关闭
        for _, btn in ipairs(self.buttons) do
            if btn.is_cancel and btn.on_click then
                btn.on_click(self)
                return true
            end
        end
        if self.close_on_click_outside then
            self:hide()
            return true
        end
    end

    return false
end

-- ============================================================
-- 绘制
-- ============================================================

function Dialog:draw()
    if not self.visible then return end

    if not self._layout_done then
        self:_layout()
    end

    local old_blend = love.graphics.getBlendMode()
    love.graphics.setBlendMode("alpha")

    -- 缩放动画（从中心放大出现）
    local scale = 0.8 + 0.2 * self.anim_progress
    local center_x = self.x + self.width / 2
    local center_y = self.y + self.height / 2

    love.graphics.push()
    love.graphics.translate(center_x, center_y)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-center_x, -center_y)

    -- 背景遮罩（半透明黑色）
    love.graphics.setColor(0, 0, 0, 0.6 * self.alpha)
    local w, h = love.graphics.getDimensions()
    -- 注意：遮罩是全屏的，但在缩放变换里会变形
    -- 所以我们在 push 之前画遮罩？不对，遮罩不应该缩放
    -- 算了，简单起见，遮罩画在外面

    -- 弹窗背景
    love.graphics.setColor(0.12, 0.12, 0.18, 0.95 * self.alpha)
    local corner = 12
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, corner, corner)

    -- 弹窗边框
    love.graphics.setColor(0.3, 0.3, 0.4, self.alpha)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, corner, corner)

    -- 标题
    love.graphics.setFont(self._title_font)
    love.graphics.setColor(1, 1, 1, self.alpha)
    local title_w = self._title_font:getWidth(self.title)
    love.graphics.print(self.title,
        self.x + (self.width - title_w) / 2,
        self.y + 25)

    -- 标题下划线
    love.graphics.setColor(0.4, 0.4, 0.5, 0.5 * self.alpha)
    love.graphics.rectangle("fill",
        self.x + 40, self.y + 55, self.width - 80, 1)

    -- 内容
    love.graphics.setFont(self._content_font)
    love.graphics.setColor(0.85, 0.85, 0.9, self.alpha)

    local content_lines = Utils.string_split(self.content, "\n")
    local content_y = self.y + 75
    for i, line in ipairs(content_lines) do
        local line_w = self._content_font:getWidth(line)
        love.graphics.print(line,
            self.x + (self.width - line_w) / 2,
            content_y + (i - 1) * self._content_font:getHeight())
    end

    -- 按钮
    for _, btn in ipairs(self.buttons) do
        self:_draw_button(btn)
    end

    love.graphics.pop()

    love.graphics.setBlendMode(old_blend)
    love.graphics.setColor(1, 1, 1, 1)
end

-- 绘制单个按钮
function Dialog:_draw_button(btn)
    -- 按钮背景
    local btn_alpha = self.alpha
    if btn.hover then
        love.graphics.setColor(0.3, 0.5, 0.9, btn_alpha)
    elseif btn.is_default then
        love.graphics.setColor(0.2, 0.4, 0.7, btn_alpha)
    else
        love.graphics.setColor(0.2, 0.22, 0.28, btn_alpha)
    end

    love.graphics.rectangle("fill", btn.x, btn.y, btn.width, btn.height, 6, 6)

    -- 按钮边框
    if btn.hover then
        love.graphics.setColor(0.5, 0.7, 1, btn_alpha)
    else
        love.graphics.setColor(0.35, 0.35, 0.45, btn_alpha)
    end
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.width, btn.height, 6, 6)

    -- 按钮文字
    love.graphics.setFont(btn.font)
    love.graphics.setColor(1, 1, 1, btn_alpha)
    local text_w = btn.font:getWidth(btn.text)
    local text_h = btn.font:getHeight()
    love.graphics.print(btn.text,
        btn.x + (btn.width - text_w) / 2,
        btn.y + (btn.height - text_h) / 2)
end

-- ============================================================
-- 绘制遮罩（全屏半透明黑色）
-- 这个应该在 draw 之外调用，避免被缩放影响
-- ============================================================

function Dialog.draw_overlay(alpha)
    alpha = alpha or 0.6
    love.graphics.setColor(0, 0, 0, alpha)
    local w, h = love.graphics.getDimensions()
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

return Dialog
