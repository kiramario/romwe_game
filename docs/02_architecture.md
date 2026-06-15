# 整体架构设计

## 核心原则：两层架构

```
┌─────────────────────────────────────┐
│           Game Layer (游戏层)        │
│  中国象棋 / 弹珠 / 卡牌 ... (可替换)  │
├─────────────────────────────────────┤
│            Core Layer (引擎层)       │
│  场景管理 / 输入 / 渲染 / 资源 / 日志  │
└─────────────────────────────────────┘
```

**黄金法则**：Core 层永远不依赖 Game 层。Game 层调用 Core 层，反之不行。

类比：Core 是 Spring/Express/Django 框架，Game 是你写的业务代码。

## 架构分层详解

### Layer 1: Core Layer（通用 2D 引擎层）

**职责**：提供所有 2D 游戏都需要的基础能力。

| 模块 | 职责 | 类比 |
|------|------|------|
| `logger` | 分级日志、格式化输出 | Python logging / JS console |
| `config` | 配置管理、默认值、持久化 | Java properties / JS config |
| `event_bus` | 发布/订阅事件系统 | Node.js EventEmitter / RxJS |
| `input` | 统一输入抽象（键鼠/触屏）、按键映射 | Unity Input System |
| `scene_manager` | 场景切换、场景栈、过渡动画 | React Router / iOS ViewController |
| `resource_manager` | 图片/音效/字体缓存与加载 | Webpack 资产打包 |
| `render_layer` | 分层渲染、z-order 管理 | Photoshop 图层 / CSS z-index |
| `utils` | 数学、表操作、字符串工具函数 | lodash / Python stdlib |
| `tween` (V2+) | 补间动画 | CSS transition / GSAP |
| `particle` (V3+) | 粒子系统 | Unity Particle System |
| `camera` (V3+) | 2D 摄像机、视口、震动 | 2D Camera |

### Layer 2: Game Layer（游戏业务层）

**职责**：具体游戏的逻辑和内容。对中国象棋来说：

| 模块 | 职责 |
|------|------|
| `scenes/` | 各个场景（主菜单、对局、设置、关于） |
| `entities/` | 游戏实体（棋子、棋盘、特效） |
| `systems/` | 游戏系统（走法校验、AI、胜负判定） |
| `ui/` | 游戏内 UI 组件（按钮、面板、HUD） |

## 核心设计模式

### 1. 场景模式 (Scene Pattern)

每个场景是一个独立的"屏幕"，有统一的生命周期：

```
enter(params) → update(dt) → draw() → exit()
```

- `enter`：场景被激活时调用（类似 React 的 componentDidMount）
- `update`：每帧更新逻辑，dt 是距上一帧的秒数（类似游戏循环的 update）
- `draw`：每帧渲染（类似游戏循环的 render）
- `exit`：场景离开时调用（类似 componentWillUnmount）

**SceneManager** 管理场景栈，支持：
- `switch(scene_name)`：切换场景（旧场景销毁）
- `push(scene_name)`：压入场景（旧场景保留在栈下，比如弹窗）
- `pop()`：弹出场景，回到上一个

### 2. 事件总线 (Event Bus)

模块之间通过事件通信，不直接引用：

```lua
-- 订阅
EventBus.on("piece:moved", function(from, to)
    -- 处理移动
end)

-- 发布
EventBus.emit("piece:moved", {x=1, y=2}, {x=3, y=4})
```

好处：模块松耦合，容易增删功能，容易调试。

### 3. 渲染分层 (Render Layers)

按固定顺序绘制，避免 z-index 混乱：

```
Layer 0: Background  (远景背景，视差)
Layer 1: Game        (主要游戏对象)
Layer 2: Effects     (粒子、光影、特效)
Layer 3: UI          (HUD、按钮、菜单)
Layer 4: Debug       (调试信息、FPS、碰撞盒)
```

每个对象注册到对应的 layer，渲染时按 layer 顺序绘制。

### 4. 资源管理 (Resource Cache)

所有资源通过 ResourceManager 加载，自动缓存：

```lua
-- 第一次调用：加载 + 缓存
local img = ResourceManager.get_image("pieces/red_king.png")

-- 第二次调用：直接返回缓存
local img2 = ResourceManager.get_image("pieces/red_king.png")
```

避免重复加载导致的性能问题。

## 数据流

```
输入 → Input 层 → 事件/直接调用 → 游戏逻辑 → 状态变化 → 渲染
↑                                                         ↓
└────────────── EventBus 广播状态变化通知各模块 ────────────┘
```

## 为什么不选 ECS（实体组件系统）

ECS 是很多游戏引擎的标配，但我们 V0 不做：
1. **过度设计**：中国象棋只有几十个棋子，用不上 ECS 的性能优势
2. **增加复杂度**：你刚学 Lua，ECS 的思维模式需要额外学习成本
3. **可后续引入**：如果以后做弹珠游戏有大量实体，再引入 ECS 也不迟

当前架构是"面向对象式的模块化设计"，足够清晰，足够用。

## 扩展到其他游戏的方式

做弹珠游戏时：
1. `src/core/` 完全不动
2. `src/game/` 整个替换为弹珠游戏的代码
3. 资源目录 `assets/` 替换
4. `main.lua` 和 `conf.lua` 基本不动

就像换了个网站，但服务器框架还是同一个。

---
*文档版本: V0.1 | 最后更新: 2026-06-10*
