# 代码规范

## 为什么要有规范

- 你刚学 Lua，规范帮助你写出一致、可读的代码
- 未来的你回来改代码时，能快速理解
- 如果以后加其他人协作，有统一标准
- 规范 = 减少决策疲劳

---

## 命名规范

| 类型 | 规范 | 示例 | 类比 |
|------|------|------|------|
| 变量 | snake_case | `player_health` | Python |
| 函数 | snake_case | `get_piece_at()` | Python |
| 局部变量 | snake_case | `local x = 10` | - |
| 模块/类 | PascalCase | `SceneManager` | Java / C# |
| 常量 | UPPER_SNAKE_CASE | `MAX_HEALTH = 100` | C / Java |
| 私有成员 | _ 前缀 + snake_case | `self._internal_state` | Python (约定) |
| 文件名 | snake_case | `scene_manager.lua` | Python |
| 场景文件 | `xxx_scene.lua` | `menu_scene.lua` | - |

**强制要求**：所有变量都用 `local` 声明，除非真的需要全局。
（Lua 默认全局，很容易污染命名空间。类比 JS 不用 let/const 声明变量。）

---

## 代码风格

### 缩进
- 4 个空格，不用 tab
- 统一使用空格，避免不同编辑器显示不一致

### 每行最大长度
- 建议 100 字符以内
- 太长的函数调用或表达式可以换行

### 空行
- 函数之间空一行
- 逻辑块之间空一行
- 文件末尾留一个空行

### 注释
- **单行注释**：`-- 这是注释`，后面跟一个空格
- **多行注释**：`--[[ 这是多行注释 ]]`（少用，尽量用多个单行）
- **文件顶部注释**：每个文件开头说明用途
- **函数注释**：每个公开函数说明参数、返回值、用途

### 函数注释模板
```lua
-- 函数功能描述
-- @param x (number) 参数 x 的说明
-- @param y (number) 参数 y 的说明
-- @return (table) 返回值说明
function something(x, y)
end
```

---

## Lua 特有规范（重要！）

### 1. 永远用 local function 语法糖

```lua
-- ✅ 好：local function 语法糖（自动处理闭包自引用问题）
local function my_func()
    -- 可以安全地在函数内引用 my_func
end

-- ❌ 避免：赋值式函数声明
local my_func = function()
    -- 这里 my_func 可能是 nil！（闭包自引用 bug）
end
```

> 类比：JS 中 `const f = () => { f() }` 是可以的，但 Lua 中不行。
> 因为 Lua 的 `local x = expr` 中，x 在 expr 求值完成后才进入作用域。

### 2. 表的数组部分从 1 开始

```lua
local arr = {"a", "b", "c"}
print(arr[1])  -- ✅ "a"
print(arr[0])  -- ❌ nil（不是第一个元素）
print(#arr)    -- 3（数组长度）
```

> 类比：不像 JS/Python/Java 从 0 开始，Lua 数组从 1 开始。
> 象棋棋盘坐标也用 1-based 会比较自然。

### 3. 只有 nil 和 false 是 falsy

```lua
if 0 then print("yes") end     -- ✅ 打印 yes！0 是 truthy
if "" then print("yes") end    -- ✅ 打印 yes！空字符串是 truthy
if {} then print("yes") end    -- ✅ 打印 yes！空表是 truthy
```

> 类比：和 JS/Python 很不一样。只有 nil 和 false 才是假值。
> 判断"是否存在"用 `if x == nil then`，判断"是否为真"用 `if x then`。

### 4. 字符串拼接用 .. 不是 +

```lua
local name = "张三"
local msg = "你好, " .. name  -- ✅
local msg2 = "你好, " + name  -- ❌ 会报错（尝试转数字相加）
```

### 5. 冒号 vs 点号

```lua
-- 定义：冒号自动带 self 参数
function obj:method(arg)
    print(self.value)  -- self 可用
end

-- 等价于
function obj.method(self, arg)
    print(self.value)
end

-- 调用：冒号自动把对象作为第一个参数传入
obj:method("hello")   -- ✅ self = obj
obj.method(obj, "hello")  -- 等价，但麻烦
```

> 类比：类似 JS 的 `this` 或 Python 的 `self`。
> 记住：定义和调用都用 `:`，就不用操心 self 了。

### 6. 模块模式

每个文件都是一个模块，末尾 return 一个 table：

```lua
-- my_module.lua
local MyModule = {}  -- 模块表

local function private_helper()  -- 私有函数
    -- ...
end

function MyModule.public_func()  -- 公开函数
    -- ...
end

return MyModule  -- 导出
```

使用时：
```lua
local MyModule = require("src.core.my_module")
MyModule.public_func()
```

> 类比：类似 Node.js 的 `module.exports` 或 Python 的模块。
> 注意：`require` 用点号分隔路径，不是斜杠。

### 7. 表遍历

```lua
-- 遍历数组（按顺序）
for i, v in ipairs(arr) do
    -- i 是索引（从 1 开始），v 是值
end

-- 遍历所有键值对（不保证顺序）
for k, v in pairs(tbl) do
    -- k 是键，v 是值
end
```

> 类比：`ipairs` ≈ JS 的 `forEach`（数组用），`pairs` ≈ `for...in`（对象用）。
> 重要：`pairs` 遍历的顺序不保证，不要依赖顺序！

---

## 模块依赖规范

### Core 层规范
- Core 模块之间可以互相引用（比如 event_bus 可以用 logger）
- Core 模块 **绝对不能** require game 层的任何东西
- Core 模块尽量通过事件通信，减少直接依赖

### Game 层规范
- Game 层可以自由引用 core 层
- Game 层内部，scenes 可以引用 entities 和 systems
- entities 不要引用 scenes（场景比实体高一层）
- systems 是纯逻辑，可以被 scenes 和 entities 调用

### 依赖图
```
scenes → entities → systems
   ↓         ↓         ↓
   └─────────┴─────────┴──→ core
```

---

## 性能规范（初期不用太纠结，但要知道）

1. **不要在 love.update/draw 里创建新 table**：会触发 GC，造成卡顿
2. **资源缓存**：图片、音效只加载一次，存在 ResourceManager 里
3. **尽量用局部变量**：Lua 访问局部变量比全局快
4. **字符串拼接少用 .. 在循环里**：大量拼接用 table.concat

初期 V0-V2 不用太在意性能，先跑通再说。V5 再优化。

---

## 文件模板

### 新模块模板
```lua
-- 模块名: xxx
-- 功能: 模块功能描述
-- 作者: Trillion Games
-- 版本: v0.1

local ModuleName = {}

-- 私有变量
local _private_var = 0

-- 私有函数
local function _private_func()
end

-- 公开函数
function ModuleName.public_func()
end

return ModuleName
```

### 新场景模板
```lua
-- 场景名: xxx_scene
-- 功能: 场景功能描述

local scene = {}

function scene:enter(params)
    -- 场景进入时调用
    -- params: 上一个场景传来的参数
end

function scene:update(dt)
    -- 每帧更新
    -- dt: 距上一帧的时间（秒）
end

function scene:draw()
    -- 每帧渲染
end

function scene:exit()
    -- 场景离开时调用
end

return scene
```

---
*文档版本: V0.1 | 最后更新: 2026-06-10*
