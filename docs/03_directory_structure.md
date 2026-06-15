# 仓库目录设计

## 完整目录树

```
love2DGame_brich/
│
├── main.lua                  # 【入口】LÖVE2D 启动入口，非常薄，只做初始化
├── conf.lua                  # 【配置】LÖVE2D 窗口配置，在 love.load 之前执行
├── README.md                 # 项目说明（给人看的）
├── .gitignore                # Git 忽略规则
│
├── src/                      # 【源代码】所有 Lua 代码
│   │
│   ├── core/                 # 🔧 Core 层：通用 2D 引擎（可复用）
│   │   ├── init.lua          # Core 模块入口，统一导出所有 core 模块
│   │   ├── logger.lua        # 日志系统（分级、格式化）
│   │   ├── config.lua        # 配置管理（默认值 + 用户配置 + 持久化）
│   │   ├── event_bus.lua     # 事件总线（发布/订阅）
│   │   ├── input.lua         # 输入管理（键鼠、动作映射）
│   │   ├── scene_manager.lua # 场景管理器（切换、栈、过渡）
│   │   ├── resource_manager.lua  # 资源管理器（图片、音效、字体缓存）
│   │   ├── render_layer.lua  # 渲染分层（多层有序绘制）
│   │   └── utils.lua         # 工具函数（数学、表、字符串）
│   │
│   └── game/                 # 🎮 Game 层：具体游戏（中国象棋）
│       ├── init.lua          # Game 模块入口
│       ├── scenes/           # 场景
│       │   ├── boot_scene.lua     # 启动场景（加载画面）
│       │   ├── menu_scene.lua     # 主菜单场景（V1 加入）
│       │   ├── game_scene.lua     # 对局场景（V2 加入）
│       │   └── settings_scene.lua # 设置场景（V3 加入）
│       ├── entities/         # 游戏实体
│       │   ├── board.lua          # 棋盘（V2 加入）
│       │   └── piece.lua          # 棋子（V2 加入）
│       ├── systems/          # 游戏系统
│       │   ├── rules.lua          # 走法规则（V2 加入）
│       │   ├── ai.lua             # AI 对手（V4 加入）
│       │   └── game_state.lua     # 游戏状态管理（V2 加入）
│       └── ui/               # UI 组件
│           ├── button.lua         # 按钮（V1 加入）
│           └── panel.lua          # 面板（V3 加入）
│
├── assets/                   # 📦 资源文件
│   ├── images/               # 图片
│   │   └── pieces/           # 棋子图片（V2 加入）
│   ├── sounds/               # 音效（V4 加入）
│   └── fonts/                # 字体（V1 加入）
│
├── docs/                     # 📚 项目文档
│   ├── 00_vision.md              # 项目愿景
│   ├── 01_dev_methodology.md     # 开发方式选型
│   ├── 02_architecture.md        # 整体架构
│   ├── 03_directory_structure.md # 本文件：目录设计
│   ├── 04_roadmap.md             # 版本路线图
│   ├── 05_code_style.md          # 代码规范
│   ├── 06_doc_style.md           # 文档规范
│   ├── 07_modules.md             # 关键模块 API 说明
│   ├── 08_deployment.md          # 发布路径
│   └── 09_risks.md               # 风险与替代方案
│
├── tests/                    # 🧪 测试
│   ├── core/                 # Core 层单元测试
│   └── game/                 # Game 层单元测试
│
├── tools/                    # 🔧 工具脚本
│   ├── build.sh              # 构建脚本（打包 .love）
│   ├── release_steam.sh      # Steam 发布脚本（V5 加入）
│   └── release_apk.sh        # APK 打包脚本（V5 加入）
│
└── build/                    # 构建输出（Git 忽略）
    ├── *.love                # LÖVE2D 游戏包
    └── releases/             # 发布版本
```

## 目录命名规范

- 目录名：全小写 + 下划线（snake_case）
- 文件名：全小写 + 下划线（snake_case）
- 模块入口文件：`init.lua`（类似 Python 的 `__init__.py`）
- 场景文件后缀：`_scene.lua`
- 实体文件后缀：直接叫名字（`piece.lua`，不用加 `_entity`）

## 核心文件职责

### main.lua
- 极薄的入口层
- 只做三件事：初始化 core、初始化 game、启动第一个场景
- 不包含任何游戏逻辑

### conf.lua
- LÖVE2D 配置文件，在游戏启动时最先加载
- 设置窗口大小、标题、是否垂直同步等
- 只能配置，不能写游戏逻辑

### src/core/init.lua
- 统一导出所有 core 模块
- 类似 Java 的 package 或 Python 的 __init__.py
- Game 层通过 `require("src.core")` 引入所有 core 功能

### src/game/init.lua
- 游戏层入口
- 注册所有场景、初始化游戏特定配置
- 由 main.lua 调用

## 为什么这样设计

### 1. Core 和 Game 严格分离
- `src/core/` 和 `src/game/` 是平级目录，视觉上就提醒你它们是分开的
- Core 不能引用 Game 中的任何东西
- Game 通过 `require("src.core.xxx")` 使用 core

### 2. 按功能分目录，不是按类型分目录
- 场景放在 `scenes/`，实体放在 `entities/`，系统放在 `systems/`
- 找东西的时候，先想"这是什么类型的东西"，再去找
- 类似 MVC 架构的目录组织

### 3. 文档独立成目录
- 所有规划文档放在 `docs/`
- 代码里的注释是"微观文档"，docs 里的是"宏观文档"
- 新加入的人（或未来的你）先看 docs，再看代码

### 4. 资源和代码分离
- `assets/` 放所有非代码文件
- 方便后续做资源打包、压缩、热更新
- 也方便美术/音效独立工作（虽然现在只有你一个人）

## 新增文件时的判断

不确定文件放哪里？问自己几个问题：

1. **这个东西是不是所有游戏都能用？** → 放 `src/core/`
2. **这个东西是不是只有这个游戏有？** → 放 `src/game/`
3. **它是一个"画面/场景"吗？** → 放 `src/game/scenes/`
4. **它是一个"东西/对象"吗？** → 放 `src/game/entities/`
5. **它是一套"规则/逻辑"吗？** → 放 `src/game/systems/`
6. **它是界面元素吗？** → 放 `src/game/ui/`
7. **它是数据文件吗？** → 放 `assets/`

---
*文档版本: V0.1 | 最后更新: 2026-06-10*
