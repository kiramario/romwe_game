# Romwe Games 2D Engine 

一个基于 LÖVE2D 的 2D 游戏项目。首发产品为中国象棋，引擎层可复用于其他 2D 游戏。

## 快速开始

### 运行游戏

```bash
cd /home/romwe_game
love .
```

### 切换版本测试

```bash
git tag               # 查看所有版本
git checkout v0.0.1   # 切换到 V0 版本
```

## 项目结构

```
├── main.lua          # 入口文件
├── conf.lua          # LÖVE2D 配置
├── src/
│   ├── core/         # 通用 2D 引擎层（可复用）
│   └── game/         # 游戏业务层（中国象棋）
├── assets/           # 资源文件（图片、音效、字体）
├── docs/             # 项目文档
├── tests/            # 测试
└── tools/            # 工具脚本
```

## 文档索引

| 文档 | 说明 |
|------|------|
| [docs/00_vision.md](docs/00_vision.md) | 项目愿景 |
| [docs/01_dev_methodology.md](docs/01_dev_methodology.md) | 开发方式选型 |
| [docs/02_architecture.md](docs/02_architecture.md) | 整体架构 |
| [docs/03_directory_structure.md](docs/03_directory_structure.md) | 目录设计 |
| [docs/04_roadmap.md](docs/04_roadmap.md) | 版本路线图 |
| [docs/05_code_style.md](docs/05_code_style.md) | 代码规范 |
| [docs/06_doc_style.md](docs/06_doc_style.md) | 文档规范 |
| [docs/07_modules.md](docs/07_modules.md) | 关键模块说明 |
| [docs/08_deployment.md](docs/08_deployment.md) | 发布路径 |
| [docs/09_risks.md](docs/09_risks.md) | 风险与替代方案 |

## 当前版本

- **版本**: V0.0.1 (开发中)
- **状态**: 脚手架阶段，无实际游戏内容

## 技术栈

- **引擎**: LÖVE2D 11.3
- **语言**: Lua (LuaJIT)
- **目标平台**: Steam > 桌面 > Android

## 开发

详见 [docs/05_code_style.md](docs/05_code_style.md) 代码规范。
