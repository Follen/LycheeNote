# 荔枝笔记 LycheeNote

记录你在团本大秘境遇到的笨蛋。名单只保存在本机，不上传任何数据。

## 功能

- **右键标记**：右键任意玩家头像 → 「标记并记录」；选中目标后 `/note add 理由` 直接记录。
- **队伍提醒**：组进本有人时在聊天框提醒一次（内容变化才会再提醒）。
- **集合石高亮**：在集合石的申请人 / 活动列表里标出已记录的人，并给团长名字染红、tooltip 追加记录理由。始终跟随「启用插件」开关，没有单独设置。
- **名单管理**：按时间倒序列出玩家、服务器、职业专精、加入时间和理由，右键行可编辑理由或移除。
- **导入导出**：导出为 `LN-` 开头的文本，复制给队友即可导入。

## 命令

| 命令 | 作用 |
| --- | --- |
| `/note` | 打开 / 关闭主窗口 |
| `/note on` / `/note off` | 启用 / 停用（右键与集合石高亮一并停止） |
| `/note add 理由` | 记录当前选中目标（不带理由则先询问） |

## 安装

把整个 `LycheeNote` 文件夹放进 `Interface\AddOns\`，在插件列表里勾选即可。目标客户端为正式服 12.1.0（`## Interface: 120100`）。

集合石高亮是可选功能，未安装集合石时插件不会残留任何事件或计时器。

## 目录结构

```
LycheeNote/
├── LycheeNote.toc          插件清单
├── Core/
│   ├── Bootstrap.lua       命名空间、输出通道、公共工具（TOC 首位）
│   ├── Config.lua          LycheeNoteDB 存档
│   └── Init.lua            事件白名单与显式初始化顺序
├── Shared/
│   ├── Theme.lua           颜色、字号、圆角、尺寸的唯一来源
│   ├── Components.lua      公共控件
│   └── Layer.lua           窗口层级、ESC、战斗
├── Domains/Note/
│   ├── Note.lua            记录存储与序列化
│   ├── Inspect.lua         职业专精解析
│   ├── Events.lua          队伍检查
│   ├── Menus.lua           右键菜单注入
│   ├── MeetingStone.lua    集合石高亮
│   ├── UI.lua              主窗口
│   └── Dialogs.lua         添加 / 编辑弹窗
├── Media/                  荔枝 logo、圆角纹理与底栏联系入口图标
├── tests/smoke.lua         离线冒烟测试
├── DESIGN.md               设计规范
└── PERFORMANCE.md          性能规范与验收
```

依赖方向单向向下：引导 → 生命周期 / 设计系统 → 领域。新增界面前先读 [DESIGN.md](DESIGN.md)，改运行时行为前先读 [PERFORMANCE.md](PERFORMANCE.md)。

## 测试

```
lua tests/smoke.lua
```

用最小 WoW 替身按 TOC 顺序加载全部文件并跑通 31 项断言。它验证加载顺序、存档、界面生命周期与主要数据路径，**不能替代实机验收**（战斗、受保护操作、集合石各版本结构、UI 缩放仍需在游戏里确认）。

## 迁移说明

v1.0.0 是一次破坏性改名：存档文件从 `RememberNoob.lua` 换成 `LycheeNote.lua`，旧的集合石设置与调试配置不再读取，旧的右键标记入口已移除。**旧名单不会自动迁移**。如需保留，把旧存档里的名单表手动复制到 `LycheeNote.lua` 的 `records` 字段即可。

## 作者

晴昼秋岚#5278
