//
//  StockReminderApp.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import SwiftUI

@main
struct StockReminderApp: App {
    // 初始化后台刷新服务（在 App 级别保持活跃）
    @State private var backgroundService = BackgroundRefreshService.shared
    @State private var appSettings = AppSettings.shared
    @State private var menuBarText: String = ""
    @State private var menuBarColor: Color = .primary
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            MenuBarLabel(
                backgroundService: backgroundService,
                appSettings: appSettings
            )
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - 菜单栏标签视图

struct MenuBarLabel: View {
    let backgroundService: BackgroundRefreshService
    let appSettings: AppSettings
    
    var body: some View {
        HStack(spacing: 4) {
            // 图标
            Image("MenuBarIcon")
                .renderingMode(.template)
            
            // 股票信息（如果启用）
            if appSettings.showStockInMenuBar, let stock = displayStock {
                Text(formatDisplay(stock: stock))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(stock.isUp ? Color.red : Color.green)
            }
        }
    }
    
    /// 获取要显示的股票
    private var displayStock: StockData? {
        let stocks = backgroundService.stocks
        guard !stocks.isEmpty else { return nil }
        
        // 如果设置了特定股票代码
        if !appSettings.menuBarStockCode.isEmpty {
            return stocks.first { $0.code.lowercased() == appSettings.menuBarStockCode.lowercased() }
        }
        
        // 默认显示第一只
        return stocks.first
    }
    
    /// 格式化显示内容
    private func formatDisplay(stock: StockData) -> String {
        switch appSettings.menuBarDisplayType {
        case .percent:
            return stock.percentText
        case .price:
            return String(format: "%.2f", stock.price)
        case .priceAndPercent:
            return String(format: "%.2f %@", stock.price, stock.percentText)
        }
    }
}
