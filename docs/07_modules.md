# 关键模块说明（Core 层）

本文档说明 V0 版本 core 层各模块的 API 和设计思路。
Game 层模块在后续版本中逐步补充。

---

## 模块总览

```
src/core/
├── init.lua          # Core 模块入口（统一导出）
├── logger.lua        # 日志系统
├── config.lua        # 配置管理
├── event_bus.lua     # 事件总线
├── input.lua         # 输入管理
├── scene_manager.lua # 场景管理器
├── resource_manager.lua # 资源管理器
├── render_layer.lua  # 渲染分层
└── utils.lua         # 工具函数
```

---

## 1. Logger（日志系统）

**用途**：分级日志输出，替代直接 print。

**类比**：Python 的 logging 模块 / JS 的 console.log/warn/error。

### API

```lua
Logger.trace(message)   -- 最细粒度，调试用
Logger.debug(message)   -- 调试信息
Logger.info(message)    -- 一般信息
Logger.warn(message)    -- 警告
Logger.error(message)   -- 错误
Logger.set_level(level) -- 设置最低输出级别
```

### 日志级别（从低到高）
`trace < debug < info < warn < error`

设置级别后，低于该级别的日志不会输出。
比如设为 `info`，则 trace 和 debug 不输出。

### 设计要点
- 默认级别：debug（开发期）
- 发布版可设为 info 或 warn
- 每条日志带时间戳、级别、模块名
- 错误日志带调用栈（用 debug.traceback）

---

## 2. Config（配置管理）

**用途**：管理游戏配置，有默认值，可持久化到文件。

**类比**：Java 的 properties 文件 / JS 的 config 对象。

### API

```lua
Config.get(key)              -- 获取配置值
Config.set(key, value)       -- 设置配置值（运行时）
Config.load(path)            -- 从文件加载配置
Config.save(path)            -- 保存配置到文件
Config.reset()               -- 重置为默认值
```

### 配置文件格式
使用 Lua table 格式（不是 JSON），因为 Lua 原生支持，不用额外的解析库。

```lua
-- config.lua
return {
    window = {
        width = 1280,
        height = 720,
        fullscreen = false
    },
    audio = {
        music_volume = 0.8,
        sfx_volume = 1.0
    },
    debug = {
        show_fps = true
    }
}
```

### 设计要点
- 有默认值表，读取失败时回退到默认
- 配置项有层级（window.width, audio.music_volume）
- 保存到 LOVE 的存档目录（love.filesystem.getSaveDirectory）
- 配置变更时通过事件总线广播

---

## 3. EventBus（事件总线）

**用途**：模块间解耦通信，发布/订阅模式。

**类比**：Node.js 的 EventEmitter / RxJS Subject / 事件委托。

### API

```lua
EventBus.on(event_name, handler)       -- 订阅事件
EventBus.off(event_name, handler)      -- 取消订阅
EventBus.emit(event_name, ...)         -- 发布事件（可传参数）
EventBus.once(event_name, handler)     -- 只订阅一次
EventBus.clear(event_name)             -- 清除某个事件的所有订阅
```

### 使用示例

```lua
-- 订阅：棋子移动时播放音效
EventBus.on("piece:moved", function(from, to, piece)
    AudioManager.play_sfx("move")
end)

-- 发布：棋子移动后
EventBus.emit("piece:moved", {x=1, y=2}, {x=3, y=4}, red_king)
```

### 设计要点
- 事件名用冒号分隔：`类别:动作`（如 `piece:moved`, `game:start`）
- 一个事件可以有多个订阅者
- emit 时按订阅顺序依次调用
- 注意不要在事件处理中 emit 同一个事件（死循环）
- V0 是同步事件（emit 时立即执行所有 handler），后续可加异步队列

---

## 4. Input（输入系统）

**用途**：统一管理键盘、鼠标输入，支持动作映射。

**类比**：Unity 的 Input System / 游戏手柄映射。

### 为什么需要动作映射

不要直接在游戏逻辑里判断按键：
```lua
-- ❌ 坏：硬编码按键
function scene:update(dt)
    if love.keyboard.isDown("space") then
        jump()
    end
end
```

应该用动作映射：
```lua
-- ✅ 好：通过动作名访问
Input:bind("jump", "space")  -- 绑定

function scene:update(dt)
    if Input:is_pressed("jump") then
        jump()
    end
end
```

这样改按键只需要改绑定，不用改每一处游戏逻辑。

### API

```lua
Input:bind(action, key)            -- 绑定动作到按键
Input:unbind(action)               -- 解绑
Input:is_pressed(action)           -- 这一帧是否按下
Input:is_held(action)              -- 是否持续按住
Input:is_released(action)          -- 这一帧是否松开
Input:get_mouse_position()         -- 获取鼠标位置 {x, y}
Input:is_mouse_pressed(button)     -- 鼠标是否按下
```

### 设计要点
- 键盘 + 鼠标都支持
- 动作名 = 语义化的操作（"confirm", "cancel", "jump"）
- 有默认绑定，可通过配置自定义
- 每帧开始时更新输入状态（pressed/held/released）
- V0 只做键鼠，后续可加触屏、手柄

---

## 5. SceneManager（场景管理器）

**用途**：管理游戏场景（屏幕），支持切换、压栈、过渡动画。

**类比**：React Router / iOS 视图控制器 / Android Activity。

### 场景生命周期

每个场景是一个 table，有四个方法：

```lua
local scene = {}

function scene:enter(params)  -- 进入场景时调用
    -- params: 上一个场景传过来的参数
end

function scene:update(dt)     -- 每帧更新
end

function scene:draw()         -- 每帧渲染
end

function scene:exit()         -- 离开场景时调用
end
```

### API

```lua
SceneManager.register(name, scene_class)   -- 注册场景
SceneManager.switch(name, params)          -- 切换场景（旧场景销毁）
SceneManager.push(name, params)            -- 压入场景（旧场景保留）
SceneManager.pop()                         -- 弹出场景，回到上一个
SceneManager.update(dt)                    -- 更新当前场景
SceneManager.draw()                        -- 绘制当前场景
SceneManager.get_current()                 -- 获取当前场景名
```

### 场景栈说明
- `switch`：替换当前场景，旧场景调用 exit 后销毁
- `push/pop`：场景栈，新场景叠在上面，底下的场景暂停但不销毁
- 适用场景：弹窗、暂停菜单（push 暂停菜单，pop 回到游戏）

### 设计要点
- V0 不做过渡动画（V1 再加）
- 场景必须先注册才能切换
- 切换发生在下一帧开始时（避免在 update 中间切场景导致异常）
- 每个场景有独立的生命周期，互不干扰

---

## 6. ResourceManager（资源管理器）

**用途**：加载和缓存图片、音效、字体等资源。

**类比**：Webpack 的资源打包 / Unity 的 AssetDatabase。

### 为什么需要缓存

```lua
-- ❌ 坏：每帧都加载
function scene:draw()
    local img = love.graphics.newImage("player.png")  -- 每帧都从磁盘读！
    love.graphics.draw(img)
end

-- ✅ 好：加载一次，缓存起来
local img = ResourceManager.get_image("player.png")  -- 第一次加载，后面用缓存
function scene:draw()
    love.graphics.draw(img)
end
```

### API

```lua
ResourceManager.get_image(path)       -- 获取图片（自动缓存）
ResourceManager.get_sound(path)       -- 获取音效（自动缓存）
ResourceManager.get_font(path, size)  -- 获取字体（自动缓存）
ResourceManager.unload(path)          -- 卸载单个资源
ResourceManager.unload_all()          -- 卸载所有资源
ResourceManager.get_load_count()      -- 已加载资源数
```

### 设计要点
- 所有资源路径相对于 assets/ 目录
- 图片用 Image 类型缓存
- 字体按路径+字号缓存（不同字号是不同资源）
- 音效分静态音效和流式音乐（短音效静态，背景音乐流式）
- V0 只实现图片和字体缓存，V4 加音效
- 资源加载失败时打 error 日志，返回 nil 或占位图

---

## 7. RenderLayer（渲染分层）

**用途**：按层级有序渲染，避免 z-index 混乱。

**类比**：Photoshop 图层 / CSS z-index 组。

### 层级定义（从下到上）

```
Layer 0: BACKGROUND  -- 背景、远景
Layer 1: GAME        -- 游戏主体（棋盘、棋子）
Layer 2: EFFECTS     -- 特效、粒子、光影
Layer 3: UI          -- 界面元素、HUD
Layer 4: DEBUG       -- 调试信息、FPS、碰撞盒
```

### API

```lua
RenderLayer.add(layer_name, draw_func)   -- 添加绘制函数到某层
RenderLayer.remove(layer_name, id)       -- 移除绘制函数
RenderLayer.clear(layer_name)            -- 清空某层
RenderLayer.draw()                       -- 按层级顺序绘制所有
RenderLayer.set_visible(layer, visible)  -- 显示/隐藏某层（调试用）
```

### 使用方式

```lua
-- 在场景的 enter 中注册
RenderLayer.add("GAME", function()
    self:draw_board()
end)

RenderLayer.add("UI", function()
    self:draw_hud()
end)

-- 在 love.draw 中调用
RenderLayer.draw()
```

### 设计要点
- V0 用简单的分层绘制函数列表
- 每层内按添加顺序绘制
- 同层内的顺序由添加顺序决定（先加的先画，在下面）
- 调试层默认隐藏，按快捷键切换显示
- 后续可加每图层的 shader 效果（比如全屏模糊、颜色校正）

---

## 8. Utils（工具函数）

**用途**：各种通用工具函数，不构成独立模块。

**类比**：lodash / Python stdlib 中的工具函数。

### 包含内容

#### 数学工具
- `clamp(value, min, max)`：限制值在范围内
- `lerp(a, b, t)`：线性插值
- `distance(x1, y1, x2, y2)`：两点距离
- `random(min, max)`：随机数（封装 love.math.random）

#### 表工具
- `deep_copy(tbl)`：深拷贝 table
- `shallow_copy(tbl)`：浅拷贝
- `table_merge(tbl1, tbl2)`：合并两个表
- `table_length(tbl)`：计算表的键数（pairs 方式）

#### 字符串工具
- `string_starts_with(str, prefix)`：字符串前缀判断
- `string_ends_with(str, suffix)`：字符串后缀判断
- `string_split(str, delimiter)`：字符串分割

#### 颜色工具
- 常用颜色常量（WHITE, BLACK, RED, BLUE 等）
- 颜色格式转换

### 设计要点
- 纯函数，无副作用
- 常用的、多个模块都会用到的函数才放进来
- 不要什么都往 utils 里塞，功能明确的应该单独做模块

---

## 模块依赖关系

```
         ┌──────────┐
         │  utils   │
         └────┬─────┘
              │
    ┌─────────┼─────────┐
    ▼         ▼         ▼
┌──────┐ ┌────────┐ ┌────────┐
│logger│ │ config │ │  ...   │
└───┬──┘ └───┬────┘ └────────┘
    │        │
    ▼        ▼
┌───────────────────┐     ┌──────────────┐
│   event_bus       │     │  input       │
└─────────┬─────────┘     └──────┬───────┘
          │                       │
          ▼                       ▼
┌───────────────────────────────────────┐
│           scene_manager               │
└──────────────────┬────────────────────┘
                   │
                   ▼
        ┌────────────────────┐
        │  resource_manager  │
        │  render_layer      │
        └────────────────────┘
```

说明：
- utils 是最底层，谁都可以用
- logger 和 config 是基础设施，被很多模块依赖
- event_bus 用于模块间通信
- scene_manager 是游戏流程的核心调度者
- resource_manager 和 render_layer 是渲染相关

---
*文档版本: V0.1 | 最后更新: 2026-06-10*
