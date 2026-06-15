# 发布路径建议

目标平台优先级：**Steam > 桌面 > Android APK**

每个平台的发布方式、工具链、注意事项。

---

## 一、桌面版（Windows / macOS / Linux）

### 发布原理

LÖVE2D 游戏的发布本质上是：
1. 把项目打包成 `.love` 文件（就是个 zip，改后缀名）
2. 把 `.love` 文件和 LÖVE2D 的运行时合并成可执行文件

用户不需要安装 LÖVE2D 就能运行。

### 打包方式

#### 1. .love 文件（跨平台）

```bash
# 在项目根目录执行
cd /home/love2DGame_brich
zip -r game.love . -x ".*" -x "docs/*" -x "tests/*" -x "tools/*" -x "build/*"
```

生成 `game.love`，安装了 LÖVE2D 的电脑双击就能运行。

优点：简单，一份文件多平台通用
缺点：用户需要安装 LÖVE2D

#### 2. Windows 可执行文件 (.exe)

步骤：
1. 下载 Windows 版 LÖVE2D（32位/64位）
2. 解压得到 love.exe 和一堆 dll
3. 把 game.love 和 love.exe 合并：
   ```cmd
   copy /b love.exe+game.love game.exe
   ```
4. 把 game.exe 和所有 dll 放在一个文件夹里
5. 整个文件夹就是游戏

工具推荐：
- **love-release**：Lua 写的自动打包工具
- 或自己写 build 脚本

#### 3. Linux 版本

- 可以直接发 .love 文件
- 或打包成 AppImage / deb / flatpak
- Steam 上 Linux 版本通常用 .love + 运行时的方式

#### 4. macOS 版本

- 下载 macOS 版 love.app
- 右键显示包内容，把 game.love 放进 Contents/Resources/
- 改个名字就是你的游戏了
- 需要签名才能分发（不签名的话用户要右键打开）

### 桌面版发布 Checklist

- [ ] 窗口标题、图标设置好
- [ ] 游戏配置正确（分辨率、全屏等）
- [ ] 测试过在干净系统上运行
- [ ] 不依赖开发环境的文件
- [ ] 存档路径正确（用 love.filesystem）

---

## 二、Steam 发布

### 前提条件

1. 注册 Steamworks 开发者账号（一次性缴费 100 美元/游戏）
2. 通过 Steam Direct 流程提交游戏
3. 审核通过后才能上架

### 发布流程

1. **准备构建**：打包 Windows / macOS / Linux 版本
2. **上传到 Steam**：用 SteamPipe 工具上传构建
3. **设置商店页面**：截图、宣传片、描述、标签
4. **审核**：Steam 审核（通常 1-2 周）
5. **发布**：设置发售日期，正式上架

### Steam 功能集成（V5 之后再考虑）

- **Steam 成就**：通过 Lua Steamworks 绑定实现
- **云存档**：利用 Steam Cloud，需要配置
- **排行榜**：如果有对战模式
- **手柄支持**：Steam Input

### Steam 集成方案

Lua 调用 Steam API 的方式：
- **luasteam**：开源的 Lua Steamworks 绑定
- **LuaJIT FFI**：自己封装 C API 调用
- **steam_api.dll 直接调用**：通过 FFI 加载 steam_api.dll

建议：V5 先上架基础版，不集成 Steam 功能。后续版本再加成就、云存档。

### 注意事项

- 中国区 Steam 需要考虑人民币定价
- 游戏需要有吸引人的商店页（截图、宣传片很重要）
- 中国象棋在 Steam 上有竞品，需要找差异化
- 建议先做 Steam Next Fest 试玩版，攒 wishlist

---

## 三、Android APK

### 发布原理

用 LÖVE2D 的 Android 移植版（love2d-android），把游戏打包进去。

### 两种方式

#### 方式 1：love2d-android（官方推荐）

- 官方 Android 移植项目
- 下载 Android 工程模板
- 把 .love 文件放到 assets 目录
- 用 Android Studio 或命令行打包 APK
- 可以上架 Google Play

#### 方式 2：APK 构建脚本

- 社区有自动化脚本
- 一条命令生成 APK
- 适合快速迭代测试

### 需要适配的内容

1. **触屏输入**：手机是触屏，不是鼠标
   - 棋盘点击检测要适配触屏
   - 棋子选中区域要够大（手指比鼠标粗）

2. **屏幕适配**：
   - 手机屏幕比例多样（16:9, 19.5:9, 20:9）
   - 需要做等比缩放 + 黑边 / 裁剪
   - 或自适应布局

3. **性能**：
   - 手机 GPU 比电脑弱
   - 粒子、特效不能太复杂
   - 中国象棋这种 2D 游戏一般没问题

4. **存档**：
   - Android 有自己的存储路径
   - 用 love.filesystem 会自动适配

### 国内安卓发布

- 国内上架需要版号（游戏版号很难拿）
- 如果是个人项目，发 APK 给朋友玩没问题
- 要上架应用商店比较麻烦
- 或者走 TapTap 等渠道

### 建议

- V0-V4 阶段不考虑 APK，专注桌面版
- V5 之后再尝试打包 APK，验证可行性
- 如果要正式发布移动版，需要专门花时间做触屏适配

---

## 四、发布时间线建议

```
V0-V2  ────────  纯开发，不考虑发布
V3    ────────  考虑一下窗口模式、分辨率适配
V4    ────────  音效、视觉效果到位，可以内部测试
V5    ────────  打包桌面版 + Steam 商店页筹备
V5.1  ────────  Steam EA (抢先体验) 上架
V6    ────────  正式版 + APK 测试
```

### 为什么 Steam 优先

1. **中国象棋的目标用户在 PC 上**：下棋的人更习惯用电脑
2. **Steam 有成熟的独立游戏生态**： indie 开发者的首选平台
3. **开发方便**：桌面版开发 = 你自己的开发环境，不用额外适配
4. **付费意愿**：Steam 用户愿意为好游戏付费
5. **先验证市场**：Steam 数据好再考虑移动版

### 为什么 APK 放后面

1. **需要额外适配**：触屏、屏幕比例、性能
2. **国内发行难**：版号问题
3. **竞争激烈**：手机上免费象棋 app 很多，收费很难
4. **开发成本高**：要维护两个平台的版本

---

## 五、构建工具链建议

### V0 阶段
- 手动 zip 打包 .love
- 自己本地测试

### V5 阶段
- 写 build.sh 脚本，一键打包
- 支持：.love, Windows exe, macOS app
- 自动生成版本号

### 未来（V5 之后）
- CI/CD：GitHub Actions 自动构建
- 每次提交自动打包
- 自动上传到 Steam Pipe（如果配置了）

---

## 六、版本号与命名

### 文件命名
- `chinese-chess_v1.0.0_win64.zip` — Windows 64位版
- `chinese-chess_v1.0.0_mac.zip` — macOS 版
- `chinese-chess_v1.0.0_love.zip` — .love 文件版
- `chinese-chess_v1.0.0.apk` — Android 版

### 版本号规则（语义化版本）
- **主版本号**：大版本，重大变更
- **次版本号**：新增功能
- **修订号**：bug 修复

例如：`v1.2.3` = 第1大版本，第2次功能更新，第3次修复

---
*文档版本: V0.1 | 最后更新: 2026-06-10*
