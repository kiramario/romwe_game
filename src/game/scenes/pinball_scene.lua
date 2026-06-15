-- 场景名: pinball_scene
-- 功能: 弹珠游戏
-- 说明: V3.0.0 新增 - 简单的物理弹珠游戏
-- 玩法：点击/方向键控制底部挡板，弹珠下落碰撞得分

local Core = require("src.core")
local Logger = Core.Logger
local RenderLayer = Core.RenderLayer
local Input = Core.Input
local SceneManager = Core.SceneManager
local ResourceManager = Core.ResourceManager

local PinballScene = {}
PinballScene.__index = PinballScene

-- 物理常量
local GRAVITY = 500
local BALL_RADIUS = 8
local PADDLE_WIDTH = 100
local PADDLE_HEIGHT = 14
local BALL_SPEED_LIMIT = 800
local PADDLE_SPEED = 500

function PinballScene.new()
    local self = setmetatable({}, PinballScene)

    -- 游戏区域
    self.play_x = 0
    self.play_y = 0
    self.play_w = 0
    self.play_h = 0

    -- 弹珠
    self.balls = {}

    -- 底部挡板
    self.paddle = { x = 0, y = 0, w = PADDLE_WIDTH, h = PADDLE_HEIGHT }

    -- 障碍物（圆形柱子，弹珠碰到反弹）
    self.pegs = {}

    -- 得分
    self.score = 0
    self.high_score = 0
    self.shots = 0
    self.balls_remaining = 5

    -- 游戏状态
    self.game_state = "ready"  -- ready, playing, gameover
    self.message = ""
    self.message_timer = 0

    -- 字体
    self.font = nil
    self.font_big = nil
    self.font_small = nil

    -- 粒子效果
    self.particles = {}

    -- 发射器状态
    self.launch_power = 0
    self.launch_charging = false

    return self
end

function PinballScene:enter(params)
    Logger.debug("PinballScene: enter")

    -- 加载中文字体（解决中文乱码）
    self.font = ResourceManager.get_font("NotoSansSC-Regular.ttc", 20)
    self.font_big = ResourceManager.get_font("NotoSansSC-Bold.ttc", 36)
    self.font_small = ResourceManager.get_font("NotoSansSC-Regular.ttc", 14)

    self:init_layout()
    self:init_pegs()
    self:reset_game()

    -- 背景层
    RenderLayer.add("BACKGROUND", function()
        local w, h = love.graphics.getDimensions()
        love.graphics.setColor(0.05, 0.08, 0.15, 1)
        love.graphics.rectangle("fill", 0, 0, w, h)

        -- 游戏区域边框
        love.graphics.setColor(0.3, 0.35, 0.5, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", self.play_x, self.play_y, self.play_w, self.play_h, 8, 8)
        love.graphics.setLineWidth(1)
    end)

    -- 游戏层
    RenderLayer.add("GAME", function()
        self:draw_pegs()
        self:draw_score_zones()
        self:draw_balls()
        self:draw_particles()
        self:draw_paddle()
    end)

    -- UI 层
    RenderLayer.add("UI", function()
        self:draw_ui()
    end)

    -- 窗口 resize
    self._resize_handler = function(w, h)
        self:init_layout()
    end
    Core.EventBus.on("window:resized", self._resize_handler)

    Logger.info("PinballScene: ready")
end

function PinballScene:init_layout()
    local w, h = love.graphics.getDimensions()
    self.play_x = 40
    self.play_y = 80
    self.play_w = w - 80
    self.play_h = h - 160

    self.paddle.x = self.play_x + (self.play_w - self.paddle.w) / 2
    self.paddle.y = self.play_y + self.play_h - 40
end

function PinballScene:init_pegs()
    self.pegs = {}
    local rows = 6
    local cols = 9
    local peg_radius = 10
    local spacing_x = self.play_w / (cols + 1)
    local spacing_y = (self.play_h - 200) / (rows + 1)
    local start_y = self.play_y + 100

    for row = 1, rows do
        local offset_x = (row % 2 == 0) and (spacing_x / 2) or 0
        local cols_this_row = (row % 2 == 0) and cols - 1 or cols
        for col = 0, cols_this_row - 1 do
            local x = self.play_x + spacing_x + offset_x + col * spacing_x
            local y = start_y + row * spacing_y
            -- 根据位置给不同分值
            local value = (row <= 2) and 100 or ((row <= 4) and 50 or 20)
            table.insert(self.pegs, {
                x = x, y = y, r = peg_radius,
                value = value,
                color = (value == 100) and {1, 0.8, 0.2} or ((value == 50) and {0.3, 0.8, 1} or {0.5, 0.8, 0.3}),
                hit_timer = 0,
            })
        end
    end
end

function PinballScene:reset_game()
    self.score = 0
    self.shots = 0
    self.balls_remaining = 5
    self.balls = {}
    self.particles = {}
    self.game_state = "ready"
    self.message = "按 空格 发射弹珠"
    self.message_timer = 0
end

function PinballScene:launch_ball()
    if self.balls_remaining <= 0 then return end

    local power = math.min(self.launch_power, 1)
    local base_speed = 200 + power * 300

    -- 从顶部中央发射
    local ball = {
        x = self.play_x + self.play_w / 2 + math.random(-30, 30),
        y = self.play_y + 30,
        vx = math.random(-80, 80),
        vy = base_speed,
        r = BALL_RADIUS,
        alive = true,
    }
    table.insert(self.balls, ball)
    self.shots = self.shots + 1
    self.balls_remaining = self.balls_remaining - 1
    self.game_state = "playing"
    self.launch_power = 0
    self.launch_charging = false

    Logger.debugf("PinballScene: ball launched, power=%.2f, remaining=%d", power, self.balls_remaining)
end

function PinballScene:update(dt)
    -- 消息计时器
    if self.message_timer > 0 then
        self.message_timer = self.message_timer - dt
    end

    -- 充能发射
    if self.game_state ~= "gameover" then
        if Input.is_held("space") or Input.is_key_pressed("space") then
            if not self.launch_charging and self.balls_remaining > 0 then
                self.launch_charging = true
                self.launch_power = 0
            end
        end
        if self.launch_charging then
            self.launch_power = math.min(1, self.launch_power + dt * 1.5)
        end
    end

    -- 空格发射
    if Input.is_released("space") and self.launch_charging then
        self:launch_ball()
    end

    -- R 重新开始
    if Input.is_pressed("restart") then
        self:reset_game()
    end

    -- ESC 返回
    if Input.is_pressed("cancel") then
        SceneManager.switch("select_game")
        return
    end

    -- 挡板控制（方向键或WASD）
    local paddle_speed = PADDLE_SPEED * dt
    if Input.is_held("left") or Input.is_key_held("a") then
        self.paddle.x = self.paddle.x - paddle_speed
    end
    if Input.is_held("right") or Input.is_key_held("d") then
        self.paddle.x = self.paddle.x + paddle_speed
    end

    -- 鼠标控制挡板
    if Input.is_mouse_held(1) then
        local mx = Input.get_mouse_x()
        self.paddle.x = mx - self.paddle.w / 2
    end

    -- 挡板边界
    self.paddle.x = math.max(self.play_x, math.min(self.play_x + self.play_w - self.paddle.w, self.paddle.x))

    -- 更新弹珠
    self:update_balls(dt)

    -- 更新粒子
    self:update_particles(dt)

    -- 更新 peg 击中动画
    for _, peg in ipairs(self.pegs) do
        if peg.hit_timer > 0 then
            peg.hit_timer = peg.hit_timer - dt
        end
    end

    -- 检查游戏结束
    if self.game_state == "playing" and #self.balls == 0 and self.balls_remaining <= 0 then
        self.game_state = "gameover"
        if self.score > self.high_score then
            self.high_score = self.score
        end
        self.message = "游戏结束！得分: " .. self.score .. "  |  R 重新开始"
        self.message_timer = 999
    end
end

function PinballScene:update_balls(dt)
    for i = #self.balls, 1, -1 do
        local ball = self.balls[i]

        -- 重力
        ball.vy = ball.vy + GRAVITY * dt

        -- 速度限制
        local speed = math.sqrt(ball.vx^2 + ball.vy^2)
        if speed > BALL_SPEED_LIMIT then
            ball.vx = ball.vx / speed * BALL_SPEED_LIMIT
            ball.vy = ball.vy / speed * BALL_SPEED_LIMIT
        end

        -- 位置更新
        ball.x = ball.x + ball.vx * dt
        ball.y = ball.y + ball.vy * dt

        -- 墙壁碰撞
        if ball.x - ball.r < self.play_x then
            ball.x = self.play_x + ball.r
            ball.vx = -ball.vx * 0.8
        end
        if ball.x + ball.r > self.play_x + self.play_w then
            ball.x = self.play_x + self.play_w - ball.r
            ball.vx = -ball.vx * 0.8
        end
        if ball.y - ball.r < self.play_y then
            ball.y = self.play_y + ball.r
            ball.vy = -ball.vy * 0.8
        end

        -- 挡板碰撞
        if ball.vy > 0 and
           ball.y + ball.r >= self.paddle.y and
           ball.y - ball.r <= self.paddle.y + self.paddle.h and
           ball.x >= self.paddle.x and
           ball.x <= self.paddle.x + self.paddle.w then
            ball.y = self.paddle.y - ball.r
            -- 根据击中位置改变反弹角度
            local hit_pos = (ball.x - self.paddle.x) / self.paddle.w - 0.5
            ball.vx = hit_pos * 400 + ball.vx * 0.3
            ball.vy = -math.abs(ball.vy) * 0.9
            self:add_particles(ball.x, ball.y, {1, 1, 1}, 5)
        end

        -- Peg 碰撞
        for _, peg in ipairs(self.pegs) do
            local dx = ball.x - peg.x
            local dy = ball.y - peg.y
            local dist = math.sqrt(dx*dx + dy*dy)
            local min_dist = ball.r + peg.r
            if dist < min_dist then
                -- 反弹
                local nx = dx / dist
                local ny = dy / dist
                ball.x = peg.x + nx * min_dist
                ball.y = peg.y + ny * min_dist

                -- 反射速度
                local dot = ball.vx * nx + ball.vy * ny
                ball.vx = ball.vx - 2 * dot * nx
                ball.vy = ball.vy - 2 * dot * ny
                ball.vx = ball.vx * 0.9
                ball.vy = ball.vy * 0.9

                -- 加分
                self.score = self.score + peg.value
                peg.hit_timer = 0.2
                self:add_particles(peg.x, peg.y, peg.color, 8)
            end
        end

        -- 掉出底部
        if ball.y - ball.r > self.play_y + self.play_h then
            table.remove(self.balls, i)
            self:add_particles(ball.x, self.play_y + self.play_h, {1, 0.3, 0.3}, 10)
        end
    end
end

function PinballScene:add_particles(x, y, color, count)
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = math.random(50, 200)
        table.insert(self.particles, {
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed - 50,
            life = 0.5 + math.random() * 0.3,
            max_life = 0.8,
            color = color,
            r = 2 + math.random() * 2,
        })
    end
end

function PinballScene:update_particles(dt)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + GRAVITY * 0.5 * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(self.particles, i)
        end
    end
end

function PinballScene:draw_pegs()
    for _, peg in ipairs(self.pegs) do
        local scale = 1
        if peg.hit_timer > 0 then
            scale = 1 + (peg.hit_timer / 0.2) * 0.5
        end
        local r = peg.r * scale

        -- 发光效果
        if peg.hit_timer > 0 then
            love.graphics.setColor(peg.color[1], peg.color[2], peg.color[3], 0.3)
            love.graphics.circle("fill", peg.x, peg.y, r * 1.8)
        end

        -- peg 本体
        love.graphics.setColor(peg.color[1], peg.color[2], peg.color[3], 1)
        love.graphics.circle("fill", peg.x, peg.y, r)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.circle("fill", peg.x - r*0.3, peg.y - r*0.3, r * 0.3)
    end
end

function PinballScene:draw_score_zones()
    -- 底部得分区
    local zone_count = 5
    local zone_w = self.play_w / zone_count
    local zone_y = self.play_y + self.play_h - 20
    local zone_colors = {{1,0.2,0.2}, {1,0.6,0.2}, {0.2,0.8,0.2}, {0.2,0.6,1}, {0.8,0.2,1}}
    local zone_values = {500, 100, 50, 100, 500}

    love.graphics.setFont(self.font_small)
    for i = 0, zone_count - 1 do
        local zx = self.play_x + i * zone_w
        love.graphics.setColor(zone_colors[i+1][1], zone_colors[i+1][2], zone_colors[i+1][3], 0.3)
        love.graphics.rectangle("fill", zx, zone_y, zone_w, 20)
        love.graphics.setColor(zone_colors[i+1][1], zone_colors[i+1][2], zone_colors[i+1][3], 0.8)
        love.graphics.rectangle("line", zx, zone_y, zone_w, 20)
        local txt = tostring(zone_values[i+1])
        local tw = self.font_small:getWidth(txt)
        love.graphics.print(txt, zx + zone_w/2 - tw/2, zone_y + 2)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PinballScene:draw_balls()
    for _, ball in ipairs(self.balls) do
        -- 弹珠阴影
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.circle("fill", ball.x + 2, ball.y + 2, ball.r)
        -- 弹珠本体
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.circle("fill", ball.x, ball.y, ball.r)
        -- 高光
        love.graphics.setColor(0.8, 0.9, 1, 0.6)
        love.graphics.circle("fill", ball.x - ball.r*0.3, ball.y - ball.r*0.3, ball.r * 0.4)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PinballScene:draw_particles()
    for _, p in ipairs(self.particles) do
        local alpha = p.life / p.max_life
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.circle("fill", p.x, p.y, p.r)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function PinballScene:draw_paddle()
    -- 充能条
    if self.launch_charging then
        local bar_w = 20
        local bar_h = self.play_h - 60
        local bar_x = self.play_x + self.play_w + 10
        local bar_y = self.play_y + 10
        love.graphics.setColor(0.2, 0.2, 0.2, 0.5)
        love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 4, 4)
        love.graphics.setColor(0.2, 0.8, 0.3, 0.8)
        love.graphics.rectangle("fill", bar_x, bar_y + bar_h * (1 - self.launch_power), bar_w, bar_h * self.launch_power, 4, 4)
    end

    -- 挡板
    love.graphics.setColor(0.9, 0.7, 0.2, 1)
    love.graphics.rectangle("fill", self.paddle.x, self.paddle.y, self.paddle.w, self.paddle.h, 6, 6)
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.rectangle("fill", self.paddle.x + 4, self.paddle.y + 2, self.paddle.w - 8, 4, 3, 3)
    love.graphics.setColor(1, 1, 1, 1)
end

function PinballScene:draw_ui()
    local w = love.graphics.getDimensions()
    love.graphics.setFont(self.font)

    -- 标题
    love.graphics.setColor(1, 0.85, 0.6, 1)
    love.graphics.setFont(self.font_big)
    local title = "弹珠游戏"
    local tw = self.font_big:getWidth(title)
    love.graphics.print(title, (love.graphics.getWidth() - tw) / 2, 15)

    -- 分数信息
    love.graphics.setFont(self.font)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("得分: " .. self.score, self.play_x, 50)
    love.graphics.print("剩余弹珠: " .. self.balls_remaining, self.play_x + 200, 50)
    love.graphics.print("最高分: " .. self.high_score, self.play_x + 400, 50)

    -- 操作提示
    love.graphics.setColor(0.5, 0.5, 0.6, 1)
    love.graphics.setFont(self.font_small)
    love.graphics.print("←→ 移动挡板 | 鼠标控制 | 空格按住充能发射 | R 重新开始 | ESC 返回", self.play_x, love.graphics.getHeight() - 30)

    -- 消息
    if self.message_timer > 0 or self.game_state ~= "playing" then
        love.graphics.setFont(self.font_big)
        love.graphics.setColor(1, 1, 1, 0.9)
        local mw = self.font_big:getWidth(self.message)
        love.graphics.print(self.message, (love.graphics.getWidth() - mw) / 2, love.graphics.getHeight() / 2 - 20)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PinballScene:draw()
    RenderLayer.draw()
end

function PinballScene:exit()
    Logger.debug("PinballScene: exit")
    RenderLayer.clear_all()
    if self._resize_handler then
        Core.EventBus.off("window:resized", self._resize_handler)
    end
end

return PinballScene
