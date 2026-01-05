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
    
    var body: some Scene {
        MenuBarExtra("Stock Reminder", image: "MenuBarIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
