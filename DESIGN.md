---
name: LycheeNote
description: 记录你在团本大秘境遇到的笨蛋
colors:
  window: "rgb(5.5% 5.5% 6.3%)"
  surfaceHover: "rgb(9% 9% 9%)"
  surfaceSelected: "rgb(8.5% 8.5% 8.5%)"
  accent: "rgb(83.5% 23.5% 28.5%)"
  accentHover: "rgb(95% 35% 40%)"
  accentMuted: "rgb(44% 15.5% 18.5%)"
  noteColor: "{colors.accent}"
  border: "rgb(11% 11% 12.5%)"
  text: "rgb(94% 93.2% 91%)"
  textMuted: "rgb(71% 70.5% 69%)"
  textDim: "rgb(59% 58% 59%)"
  field: "rgb(8.5% 8.5% 9.5%)"
  fieldBorder: "rgb(40% 40% 42%)"
  code: "rgb(7.2% 7.2% 8.2%)"
  disabled: "rgb(40% 40% 42%)"
  danger: "rgb(89.5% 30% 31.5%)"
typography:
  brand:
    fontFamily: STANDARD_TEXT_FONT
    fontSize: "16px"
  title:
    fontFamily: STANDARD_TEXT_FONT
    fontSize: "14px"
  body:
    fontFamily: STANDARD_TEXT_FONT
    fontSize: "12px"
  meta:
    fontFamily: STANDARD_TEXT_FONT
    fontSize: "11px"
rounded:
  panel: "10px"
  control: "6px"
  overlay: "8px"
  switch: "8px"
spacing:
  tight: "6px"
  control: "10px"
  content: "16px"
  contentPadding: "16px"
  section: "24px"
components:
  window:
    backgroundColor: "{colors.window}"
    rounded: "{rounded.panel}"
    scale: "1.15x"
    width: "760px"
    height: "520px"
    header: "56px"
    footer: "56px"
  header-action:
    hit: "32px"
    icon: "20px"
    color: "{colors.text}"
    hover: "{colors.accentHover}"
  list-row:
    height: "46px"
    gap: "6px"
    width: "556px"
    backgroundColor: "{colors.window}"
  list-row-hover:
    backgroundColor: "{colors.surfaceHover}"
  list-row-selected:
    backgroundColor: "{colors.surfaceSelected}"
  footer-links:
    hit: "28px"
    icon: "18px"
    stride: "36px"
    inset-right: "28px"
  scroll-view:
    thumb: "3px {colors.accent}"
    hit-area: "12px"
    wheel-step: "52px"
  motion:
    presence: "16px rise + fade · 0.42s"
    slide: "12px rise + fade · 0.18s / exit 0.10s"
    selection-fade: "0.10s"
    toggle-knob: "0.18s cubic-out"
    brand-bounce: "1.386s on open"
    reduced-key: "reduceMotion"
  switch:
    width: "32px"
    height: "18px"
---

# 荔枝笔记 设计规范

本文件是荔枝笔记自有界面的现行视觉与交互规范，也是新增界面的唯一依据。运行主题由 [Shared/Theme.lua](Shared/Theme.lua) 维护，公共控件由 [Shared/Components.lua](Shared/Components.lua) 提供，窗口层级由 [Shared/Layer.lua](Shared/Layer.lua) 管理。性能、对象上限和停止条件统一遵循 [PERFORMANCE.md](PERFORMANCE.md)。离线替身测试见 [tests/smoke.lua](tests/smoke.lua)，它不能替代实机验收。

- [1. 阅读与维护边界](#design-1)
- [2. 视觉基础](#design-2)
- [3. 布局与公共控件](#design-3)
- [4. 层级、ESC 与战斗](#design-4)
- [5. 集合石集成](#design-5)
- [6. 文案与验收](#design-6)

<a id="design-1"></a>

## 1. 阅读与维护边界

### 用途

用户可见名称为荔枝笔记 / LycheeNote。插件只做一件事：把某个玩家记下来，并在他下次出现在你队伍或集合石里时提醒你。除主窗口外，插件只以「右键菜单项」和「集合石高亮」两种被动形式出现，没有系统托盘、没有常驻状态条、没有战斗内提示。

代码分四层，依赖方向单向向下，不得反向引用：

| 层 | 位置 | 职责 | 禁止 |
| --- | --- | --- | --- |
| 引导 | [Core/Bootstrap.lua](Core/Bootstrap.lua) | 命名空间、输出通道、错误隔离、公共工具 | 任何初始化工作 |
| 生命周期 | [Core/Config.lua](Core/Config.lua)、[Core/Init.lua](Core/Init.lua) | 存档、事件白名单、显式初始化顺序 | 业务判断 |
| 设计系统 | [Shared/](Shared/) | 主题令牌、公共控件、窗口层级 | 读取存档、写业务数据 |
| 领域 | [Domains/Note/](Domains/Note/) | 记录、侦测、右键、集合石、界面 | 直接调用 `CreateFrame` 之外的外部 UI |

`Core/Bootstrap.lua` 必须排在 TOC 首位，其余文件在加载期就取 `LN` 命名空间。初始化顺序在 `Core/Init.lua` 里显式列出，不使用隐式模块广播。

命名空间除 TOC 私有表外，另挂一个公开句柄 `_G.LycheeNote`，供 `/run` 调试、其他插件集成和实机探针使用。它是只读入口：业务写入一律走 `LN.Notes` 等模块函数。

**跨模块调用必须先存在。** 模块改名后残留的旧方法名不会报错在加载期，而是在实机某条路径上炸成 `attempt to call a nil value`——已经发生过一次（`LN.Notes.FindRecord` 改名为 `Find` 后，集合石列表每次格式化都崩）。`tests/smoke.lua` 的「跨模块 API 契约」检查会从源码里抽出所有 `LN.<模块>.<方法>` 引用并在运行时逐个核对，改名必须同步跑它。

<a id="design-2"></a>

## 2. 视觉基础

### 颜色

颜色源自 `Theme.Colors` 的归一化 RGB，前置令牌用等值百分比表示。近黑底贯穿窗口、头部、内容区和底栏。列表选中行铺 `surfaceSelected` 底，配左侧 2 × 22 荔枝红短条。红色只承担「品牌 / 当前页 / 危险操作 / 已记录标识」四种职责，**不给整行背景染色，也不给普通正文逐段染色**。

荔枝红是插件唯一的品牌色，和 [Lychee](../Lychee) 启动器同源：同一个 `#d53c49`，让两个插件在同一块屏幕上不打架。

- **危险与已记录同色是有意的**。这两个语义在本插件里都指向「危险」，拆成两个红只会让用户多记一条规则。
- **禁用色独立**。`disabled` 是中性灰，不是暗红；正常说明不能降成禁用灰。
- 主文本偏暖白，服务器 / 理由 / 时间用 `textMuted`，列头与次要元信息用 `textDim`。职业专精保留游戏原生职业色，这是唯一允许的彩色正文。

### 文字

所有自有区域在创建时使用客户端 `STANDARD_TEXT_FONT`，不加描边并清除继承阴影。只修改荔枝笔记自有区域，不修改共享 `GameFont` 或 `tooltip` 对象。

| 角色 | 字号 | 用途 |
| --- | --- | --- |
| `brand` | 16 | 窗口标题「荔枝笔记」 |
| `title` | 14 | 弹窗标题、动作菜单标题、空状态 |
| `body` | 12 | 玩家名、设置项名称、按钮文字 |
| `meta` | 11 | 理由、时间、服务器、列头、设置项副文、小节头 |
| `input` | 16 | 输入框与多行文本区文字（不继承 ChatFontNormal） |

表格列头统一 `meta` + `textDim`，无描边、无背景。行内标题左对齐，长文本单行裁切，完整内容通过悬停提示查看。**不在表格里做换行**——固定行高的表比可变行更容易扫读，也避免行高抖动。

**页面不设标题与副标题。** 当前页由头部动作按钮表达（名单页显设置、设置页显返回），标题文字重复一遍只是噪音。空状态只允许一句话。

### 形状与固定项

- 窗口外壳、弹窗、文本区、提示框、动作菜单、开关使用圆角；列表行、分隔列、滚动条使用平直边缘。
- 圆角由可复用纹理区域拼成，面板变高时角部尺寸不变（`Theme.CreateRoundedSurface` 固定 7 块区域）。
- 外壳只有圆角底面，**没有 1px 外描边、没有外发光、没有投影**。层级完全靠底色明度差和留白建立。

### 整体缩放（`uiScale`）

**所有窗口级框体（主窗口、弹窗）与挂在 `UIParent` 的自有浮层（提示框、动作菜单）必须 `SetScale(Theme.Metrics.uiScale)`。** 全部尺寸与字号令牌按荔枝启动器口径（1.15）设计；漏掉缩放会让整个界面比荔枝小 13%——「文字大小各方面都奇怪」的一次实机事故就是这里。联系弹窗挂在 `UIParent`，缩放取入口栏有效缩放与 `UIParent` 的比值（与窗口同步）。

### 锚定规则（`Theme:Anchor`）

**同一个 `(point, relativePoint)` 视为「替换那一条」，不同位置视为「追加一条」，每次变更整组重放。** 因此：

- 单锚控件（列表行、设置行、按钮）可以反复锚定，只替换自己的那一条，不会累积。
- 双锚控件（头部 `TOPLEFT` + `TOPRIGHT`、内容区 `TOPLEFT` + `BOTTOMRIGHT`、底栏 `BOTTOMLEFT` + `BOTTOMRIGHT`、滚动视口、文本区）两条都保留，客户端据此算出尺寸。
- 需要丢弃整组锚点时用 `Theme:ClearAnchors(region)`。

**禁止**把这条规则改回「单键缓存 + 每次 `ClearAllPoints`」。那样第二个锚点会清掉第一个，`header` 宽度变 0、内容被推到窗口外，实机表现为一整块纯黑面板；`tests/smoke.lua` 的「锚点集合：双锚不清掉第一条」与「主窗口各区域都有非零尺寸」两项就是这条的回归门禁。

### 父子关系

- 弹出式/模态框一律挂在 `UIParent`。
- 主窗口内部的**所有**容器（页面、头部、底栏、滚动视口）必须是窗口框体的子框体。内容容器若挂到 `UIParent`，窗口 `Hide()` 时它会留在屏幕上继续显示。
- `tests/smoke.lua` 的顶层 Frame 数量断言覆盖这一点。

<a id="design-3"></a>

## 3. 布局与公共控件

### 信息与操作层级

黑色是整体底面，不代表每种内容都要套一层浅黑底。常态页面只有一层底面；底色用于真正的输入区（`field`）和内容选择（`surfaceSelected`）。只读值不伪装成按钮。

| 身份 | 视觉规则 | 使用约定 |
| --- | --- | --- |
| 头部动作按钮（设置 / 返回） | 32 命中 20 图形，常态 `text` | hover `accentHover`，按下变暗；随当前页互换显隐 |
| 玩家名 | `body` 12 号 `text` | 列表首列，行内唯一的主文字 |
| 次要字段 | `meta` 11 号 `textMuted` / `textDim` | 服务器、理由、时间、职业 |
| 列头 | `meta` 11 号 `textDim` | 无背景、无分隔线 |
| 文字按钮 | `body` 12 号 `text` | hover `accentHover`，无底色、无下划线 |
| 开关 | 关 `switchOff` / 开 `accent` | 32 × 18，滑块 14，状态文字在左 |
| 禁用 | `disabled` | 不响应点击与悬停 |

### 控件规范

| 控件 | 常态与提示 | 反馈与生命周期 |
| --- | --- | --- |
| 头部动作按钮 | 32 命中 / 20 图形，图标无底色 | hover `accentHover`；设置与返回共用槽位，进入设置页互换 |
| 文字按钮 | 透明底 | hover 文字 `accentHover`，不加矩形底、不加下划线 |
| 开关 | 关灰底滑块左 / 开红底滑块右 | 状态文字与开关并排，不只靠颜色表示 |
| 表单输入 | `field` 底 + 1px `fieldBorder` | 焦点 `accentHover`，错误 `danger` 优先于焦点 |
| 文本区 | `code` 底圆角 6 | 无描边；可全选复制 |
| 关闭按钮 | 两条短横，常态 `textMuted` | hover 变 `accentHover` 并显示 `actionHover` 底 |
| 列表行 | 常态透明底 | hover `surfaceHover`；选中 `surfaceSelected` + 红条 |
| 滚动条 | 3 宽红滑块、无轨道 | 12 宽透明命中区，无步进按钮；滚轮步进 52（= 行距） |
| 底部联系入口 | 28 命中 / 18 图形 / 间距 8 / 右边距 28 | 点击在**入口栏上方右对齐**弹出模态（荔枝方案，不居中于屏幕）：code 显 176 方形扫码图，url 显可复制输入框 |
| 提示框 | 不透明近黑、圆角 8、无描边 | 跟随鼠标，边缘 8 留白，翻转贴边 |
| 动作菜单 | 与提示框同底色 | 标题 14 + 操作 12，行高 30，hover 红字 |

**滚动视口必须用裸 `ScrollFrame`，禁止 `UIPanelScrollFrameTemplate`。** 模板会带出暴雪自带的上下箭头按钮和原生滑块，与自绘 3px 滑块叠画——实机上就是列表右缘那两个多余的 18 × 15 方块。滚轮由控件自行接管（`OnMouseWheel`，步进 52），滚动位置经 `Sync()` 统一回读。Lychee 同样只用裸 ScrollFrame。

**公共控件不决定业务。** `Components` 只管外观与状态；保存、启停、导入合并等由调用方校验身份后执行。

### 动效

移植荔枝家族的动效语言，实现集中在 [Shared/Motion.lua](Shared/Motion.lua)：一个共享驱动 Frame，只在动画进行期间挂 `OnUpdate`，结束立即解绑——空闲零每帧工作不变。

| 动效 | 参数 | 使用点 |
| --- | --- | --- |
| Presence | 16px 上浮 + 淡入，0.42s | 主窗口开 / 关 |
| Slide | 12px 上浮 + alpha 0.4→1，0.18s；退出 8px 0.10s | 页面切换、联系弹窗、模态弹窗 |
| Fade | 0.10s | 列表选中红条、开关底色 |
| MoveX | 0.18s cubic-out | 开关滑块 |
| Brand | 挤压 / 抬升 / 回落 1.386s | 品牌标志，窗口打开时一次 |

- **战斗中一律直接落定**；设置里的「动态效果」关闭（`reduceMotion`）后同样直接落定，这是唯一的动效开关。
- 不给正文、行背景、滚动条加动画；动效只出现在层级进出与状态切换上。

### 主窗口布局

几何与 Lychee 启动器逐项对齐，两插件并排时比例与节奏一致：

| 项 | 值 |
| --- | --- |
| 整体缩放 | SetScale 1.15（物理尺寸 874 × 598） |
| 窗口 | 760 × 520 |
| 头部 / 底栏 | 56 / 56 |
| 内容区 | 头部之下整体铺开：宽 728（左右内距 16），高 408 |
| 名单贴片 | 占满内容区 728 |
| 列表行 | 高 46，行距 6，贴片宽 556 |
| 文本区 | 高 140 |
| 底部联系入口 | 命中 28 / 图形 18 / 间距 8 / 右边距 28 |

```
┌──────────────────────────────────────────────────────┐
│ [logo] 荔枝笔记                                  [×] │ 56
├──────────────┬───────────────────────────────────────┤
│              │ 玩家    服务器   职业专精 加入时间 理由 │ 24
│ ▌记录名单    │ 某某    测试服   战士-武器 26/01/01 …  │ 46
│              │                                        │
│   设置       │ …                                      │
│              │                                       ▐│ 3 滑块
├──────────────┴───────────────────────────────────────┤
│                                       [微信] [GitHub] │ 56
└──────────────────────────────────────────────────────┘
```

- 品牌标志固定使用 `Media/lychee-logo.tga` 原始贴图，42 方形（与 Lychee 同尺寸），保持素材本身的颜色，**不做染色、不做动画**。标题用 `Theme.BrandColor` 包裹「荔枝」两字，呼应 `Lychee.toc` 的 `|cffd53c49荔枝|r启动器`。头部不放假副标题，插件的用途由 TOC Notes 承担。
- 无侧栏：默认页是名单，设置收进头部动作按钮（荔枝天赋的方案），进入后按钮换为返回，ESC 也先返回名单。
- 列偏移固定（合计 556）：玩家 0/112、服务器 112/104、职业专精 216/112、加入时间 328/84、理由 412/144。**没有序号列。** 列头与单元格共用同一组 `COLUMNS` 偏移量，不允许两处各写一份。
- **行池上限 12**，与名单长度无关：视口最多 7 行，余量覆盖缩放变化。名单超过视口时滚动；释放行时清空记录引用、提示归属和菜单归属，控件留在池里复用。
- 页面切换只改显隐，不重建控件；两个页面在窗口首次打开时一次性创建。
- 底栏只有联系入口（作者微信扫码 + GitHub 链接），**不放文字署名**。

### 设置页

设置是头部按钮进入的次级页面（返回按钮或 ESC 回名单），整体放在一个滚动视口里，分两段：

**开关段**（每行 46 高、行距 6）：左侧名称（`body` `text`）+ 紧随其下的一行短说明（`meta` `textMuted`），右侧状态文字（`meta`）与开关。说明只写「关掉会发生什么」，不写用途介绍。**当前三行**：`启用插件`、`标记时询问理由`、`动态效果`。

**数据段**（开关段下方留 24 间距）：`meta` 灰字小节头「数据」，其下 24 处一行三个 **48 × 28** 文字按钮 `导出` / `导入` / `全选`，再下 6 处接 556 × 140 文本区，最后一行状态文字。文本区是荔枝天赋 field 的同款做法：`code` 底圆角壳内嵌裸滚动视口，文字 `input` 16 无阴影，光标移动带动滚动，滚轮步进 52。

导出文本前缀 `LN-`（LycheeNote），Base64 + 极简 JSON 序列化。导入校验前缀、Base64 字符集和反序列化结果，三类错误各自给出一句短说明，显示在状态行，不静默失败、不写成长段落。数据不再单独占一页。

<a id="design-4"></a>

## 4. 层级、ESC 与战斗

`Shared/Layer.lua` 是唯一的窗口层级所有者，主窗口和模态弹窗都通过它进出。

- ESC 优先级固定为 **动作菜单 → 模态弹窗 → 设置页返回名单 → 主窗口 → 交还游戏**。都没有时不吞键。
- 只有一个 ESC 接收框，且只在有窗口可见时显示并启用键盘；全部窗口关闭后立即隐藏并 `EnableKeyboard(false)`，**不拦截游戏的聊天框 ESC**。
- 模态打开时主窗口 `EnableMouse(false)` 且整体 alpha 降到 0.70。关闭模态后主窗口保持打开，不重新创建。
- 弹窗和主窗口都是**惰性创建、之后复用**。两个弹窗（添加记录 / 编辑记录）共用同一套外壳控件，仅标题和按钮文字不同。
- 战斗中（`PLAYER_REGEN_DISABLED`）只隐藏全部已登记窗口并停用 ESC 接收框，**脱战不自动重开**。用户重新打开即可。
- 窗口关闭时同时释放提示框和动作菜单的 owner 归属。

<a id="design-5"></a>

## 5. 集合石集成

集合石（第三方插件 MeetingStone）集成只做一件事：**在它的申请人 / 活动列表里标出已记录的人**。没有设置项、按钮、页面和日志，随时跟随主开关。

- 高亮颜色复用 `Theme.NoteColor`（= 品牌红），alpha 0.26，背景上下各内收 1；列表图标使用暴雪自带的团队标记图标，14 方形。
- 团长姓名字段在命中时整体染红，tooltip 追加三行：提示语、加入时间、记录理由。
- 集合石未安装时全部函数立即短路；加载晚于本插件时最多重试 8 次、每次间隔 2 秒，成功后停止，**不留下常驻 timer**。
- hook 只安装一次，用 `__lnNote*` 字段做幂等标记。停用时不可逆的 hook 不卸载，而是让回调立即短路并清掉已绘制的背景与图标。
- **不读取团队查找器（LFG）数据，不订阅 LFG 搜索事件，不产生过滤日志。** 这些能力已废弃；如果要恢复集合石的可配置功能，先改本文件和 [PERFORMANCE.md](PERFORMANCE.md) 的门禁，再写实现。

<a id="design-6"></a>

## 6. 文案与验收

### 文案

- 前缀统一 `|cffd53c49荔枝笔记|r`，由 `LN.Log` 决定，代码里不要手写。**前缀一律荔枝红**（与 Lychee 启动器同源），成功消息不染绿；错误整行 `|cffff5560`。空状态、按钮、字段名一律写「记录」而不是「笨蛋」；「笨蛋」只保留在 TOC Notes 里作为品牌口吻。
- 说明写输入动作和结果，玩家名一律带服务器（`名字-服务器`），不堆叠状态标签。
- 内部错误走 `LN.SafeCall`，只打印一次标签 + 原始错误，不吞掉也不重复提示。

### 验收

- 改局部颜色 / 字体 / 间距：静态检查 + 冒烟测试 + 实际显示尺寸下的视觉检查，说明有无新增对象或驱动。
- 改按钮状态、行复用、生命周期：必须先复现再修复，覆盖真实事件顺序、禁用 / 隐藏、重新绑定。
- 改存档结构、导入导出、集合石：必须补冒烟用例，并在同输入下核对结果集合、顺序与文案。

`tests/smoke.lua` 用最小 WoW 替身按 TOC 顺序加载全部文件并跑通 31 项检查。它能抓加载顺序、顶层 nil 访问、事件派发和主要界面路径的运行时错误，**不能证明客户端事件顺序、受保护操作、taint 或像素渲染**。实机帧时间、战斗关闭和 UI 缩放表现须单独验证。
