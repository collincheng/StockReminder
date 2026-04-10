# StockReminder

macOS 菜单栏股票行情提醒工具，轻量、实时、无干扰。

## 功能

- **菜单栏实时行情** — 在菜单栏显示股票名称、价格、涨跌幅、实时成交量
- **多市场支持** — A 股、港股、美股、国内期货、海外期货
- **自选股管理** — 搜索添加、拖拽排序、左滑删除
- **价格提醒** — 设置目标价格，到价系统通知，支持重复提醒
- **智能刷新** — 自定义刷新间隔（3s - 2min），仅交易时间自动刷新
- **显示可控** — 菜单栏显示内容（涨跌幅/价格/两者）、成交量显示均可自由切换

## 安装

### 从 Release 下载

1. 前往 [Releases](https://github.com/collincheng/StockReminder/releases) 页面
2. 下载最新版 `StockReminder-vX.X.X.zip`
3. 解压后将 `StockReminder.app` 拖入应用程序文件夹
4. 首次打开需右键 → 打开（未签名应用）

### 从源码构建

```bash
git clone https://github.com/collincheng/StockReminder.git
cd StockReminder
xcodebuild -project StockReminder.xcodeproj -scheme StockReminder -configuration Release -derivedDataPath build
open build/Build/Products/Release/StockReminder.app
```

需要 Xcode 16+ 和 macOS 15.6+。

## 技术栈

- **SwiftUI** — 弹出窗口界面
- **AppKit** — 菜单栏状态项（NSStatusItem）
- **Swift Concurrency** — async/await 网络请求
- 无第三方依赖，纯原生实现

## 数据来源

- A 股、美股、期货 — 新浪财经接口
- 港股 — 腾讯财经接口

## License

MIT
