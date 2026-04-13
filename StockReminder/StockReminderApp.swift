//
//  StockReminderApp.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import SwiftUI
import AppKit

@main
struct StockReminderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // 使用空的 Settings scene，实际菜单栏由 AppDelegate 管理
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var backgroundService = BackgroundRefreshService.shared
    private var appSettings = AppSettings.shared
    private var updateTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏项
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 设置初始图标
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // 创建 Popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        
        // 启动定时更新菜单栏
        startMenuBarUpdates()
        
        // 监听数据变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarDisplay),
            name: .stockCodesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateMenuBarDisplay),
            name: .menuBarDisplayDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopover),
            name: .closePopover,
            object: nil
        )
    }
    
    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate(ignoringOtherApps: true)
                // 监听失焦事件，点击 popover 外部时自动关闭
                setupEventMonitor()
            }
        }
    }

    private var eventMonitor: Any?

    private func setupEventMonitor() {
        removeEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self = self, self.popover.isShown {
                self.popover.performClose(nil)
            }
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    @objc func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
        removeEventMonitor()
    }
    
    private func startMenuBarUpdates() {
        // 立即更新一次
        updateMenuBarDisplay()
        
        // 每秒更新一次菜单栏显示
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMenuBarDisplay()
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
    }
    
    @objc private func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }
        
        // 设置图标
        button.image = NSImage(named: "MenuBarIcon")
        button.image?.isTemplate = true
        
        // 如果启用了菜单栏显示
        if appSettings.showStockInMenuBar, let stock = getDisplayStock() {
            button.attributedTitle = createAttributedTitle(for: stock)
        } else {
            button.title = ""
        }
    }
    
    private func getDisplayStock() -> StockData? {
        let stocks = backgroundService.stocks
        guard !stocks.isEmpty else { return nil }
        
        if !appSettings.menuBarStockCode.isEmpty {
            return stocks.first { $0.code.lowercased() == appSettings.menuBarStockCode.lowercased() }
        }
        
        return stocks.first
    }
    
    /// 创建带样式的菜单栏标题
    private func createAttributedTitle(for stock: StockData) -> NSAttributedString {
        let result = NSMutableAttributedString()
        
        // 股票名称 - 使用系统默认颜色
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        result.append(NSAttributedString(string: " \(stock.name) ", attributes: nameAttributes))
        
        // 涨跌幅 - 使用颜色
        let priceText = formatPriceText(stock: stock)
        let priceColor = getStockColor(stock: stock)
        let priceAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: priceColor
        ]
        result.append(NSAttributedString(string: priceText, attributes: priceAttributes))

        // 实时成交量 - 仅个股 + 交易时间显示
        if appSettings.showVolume && !stock.isIndex && appSettings.isStockTradingTime(stock.code) {
            let volumeColor: NSColor = stock.volumeIsUp
                ? NSColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 1.0)
                : NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
            let volumeAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: volumeColor
            ]
            result.append(NSAttributedString(string: " \(stock.volumeText)", attributes: volumeAttributes))
        }

        return result
    }
    
    /// 格式化价格/涨跌幅文字
    private func formatPriceText(stock: StockData) -> String {
        switch appSettings.menuBarDisplayType {
        case .percent:
            return stock.percentText
        case .price:
            return String(format: "%.2f", stock.price)
        case .priceAndPercent:
            return String(format: "%.2f %@", stock.price, stock.percentText)
        }
    }
    
    /// 获取涨跌颜色
    private func getStockColor(stock: StockData) -> NSColor {
        if stock.updown > 0 {
            // 涨 - 鲜艳的红色
            return NSColor(red: 0.95, green: 0.25, blue: 0.25, alpha: 1.0)
        } else if stock.updown < 0 {
            // 跌 - 鲜艳的绿色
            return NSColor(red: 0.2, green: 0.78, blue: 0.35, alpha: 1.0)
        } else {
            return NSColor.secondaryLabelColor
        }
    }
}
