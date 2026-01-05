//
//  PriceAlert.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation
import UserNotifications

// MARK: - 价格提醒类型

enum AlertType: String, Codable, CaseIterable {
    case above = "above"    // 价格高于
    case below = "below"    // 价格低于
    
    var description: String {
        switch self {
        case .above: return "高于"
        case .below: return "低于"
        }
    }
    
    var icon: String {
        switch self {
        case .above: return "arrow.up.circle.fill"
        case .below: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - 价格提醒模型

struct PriceAlert: Identifiable, Codable {
    let id: UUID
    let stockCode: String       // 股票代码
    var stockName: String       // 股票名称
    let alertType: AlertType    // 提醒类型
    let targetPrice: Double     // 目标价格
    var isEnabled: Bool         // 是否启用
    var hasTriggered: Bool      // 是否已触发
    let createdAt: Date         // 创建时间
    var triggeredAt: Date?      // 触发时间
    
    init(stockCode: String, stockName: String, alertType: AlertType, targetPrice: Double) {
        self.id = UUID()
        self.stockCode = stockCode
        self.stockName = stockName
        self.alertType = alertType
        self.targetPrice = targetPrice
        self.isEnabled = true
        self.hasTriggered = false
        self.createdAt = Date()
        self.triggeredAt = nil
    }
    
    /// 检查是否应该触发提醒
    func shouldTrigger(currentPrice: Double) -> Bool {
        guard isEnabled && !hasTriggered else { return false }
        
        switch alertType {
        case .above:
            return currentPrice >= targetPrice
        case .below:
            return currentPrice <= targetPrice
        }
    }
}

// MARK: - 价格提醒管理器

@Observable
class PriceAlertManager {
    static let shared = PriceAlertManager()
    
    /// 所有价格提醒
    var alerts: [PriceAlert] {
        didSet {
            saveToUserDefaults()
        }
    }
    
    private let userDefaultsKey = "priceAlerts"
    
    private init() {
        // 从 UserDefaults 加载
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let savedAlerts = try? JSONDecoder().decode([PriceAlert].self, from: data) {
            self.alerts = savedAlerts
        } else {
            self.alerts = []
        }
        
        // 请求通知权限
        requestNotificationPermission()
    }
    
    private func saveToUserDefaults() {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - 通知权限
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知权限已授权")
            } else if let error = error {
                print("通知权限请求失败: \(error)")
            }
        }
    }
    
    // MARK: - 提醒管理
    
    /// 添加价格提醒
    func addAlert(stockCode: String, stockName: String, alertType: AlertType, targetPrice: Double) {
        let alert = PriceAlert(
            stockCode: stockCode,
            stockName: stockName,
            alertType: alertType,
            targetPrice: targetPrice
        )
        alerts.append(alert)
    }
    
    /// 删除价格提醒
    func removeAlert(id: UUID) {
        alerts.removeAll { $0.id == id }
    }
    
    /// 删除某只股票的所有提醒
    func removeAlerts(forStock stockCode: String) {
        alerts.removeAll { $0.stockCode.lowercased() == stockCode.lowercased() }
    }
    
    /// 切换提醒启用状态
    func toggleAlert(id: UUID) {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].isEnabled.toggle()
        }
    }
    
    /// 重置已触发的提醒
    func resetAlert(id: UUID) {
        if let index = alerts.firstIndex(where: { $0.id == id }) {
            alerts[index].hasTriggered = false
            alerts[index].triggeredAt = nil
        }
    }
    
    /// 获取某只股票的提醒
    func getAlerts(forStock stockCode: String) -> [PriceAlert] {
        alerts.filter { $0.stockCode.lowercased() == stockCode.lowercased() }
    }
    
    /// 获取某只股票的活跃提醒数量
    func activeAlertCount(forStock stockCode: String) -> Int {
        alerts.filter { 
            $0.stockCode.lowercased() == stockCode.lowercased() && 
            $0.isEnabled && 
            !$0.hasTriggered 
        }.count
    }
    
    // MARK: - 检查价格并触发提醒
    
    /// 检查所有股票价格并触发提醒
    func checkPrices(stocks: [StockData]) {
        for stock in stocks {
            checkPrice(stock: stock)
        }
    }
    
    /// 检查单个股票价格
    func checkPrice(stock: StockData) {
        let stockAlerts = getAlerts(forStock: stock.code)
        
        for alert in stockAlerts {
            if alert.shouldTrigger(currentPrice: stock.price) {
                triggerAlert(alert: alert, currentPrice: stock.price)
            }
        }
    }
    
    /// 触发提醒
    private func triggerAlert(alert: PriceAlert, currentPrice: Double) {
        // 更新提醒状态
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[index].hasTriggered = true
            alerts[index].triggeredAt = Date()
        }
        
        // 发送系统通知
        sendNotification(alert: alert, currentPrice: currentPrice)
    }
    
    /// 发送系统通知
    private func sendNotification(alert: PriceAlert, currentPrice: Double) {
        let content = UNMutableNotificationContent()
        content.title = "📈 价格提醒"
        content.subtitle = alert.stockName
        
        let priceStr = String(format: "%.2f", currentPrice)
        let targetStr = String(format: "%.2f", alert.targetPrice)
        
        switch alert.alertType {
        case .above:
            content.body = "当前价格 \(priceStr) 已突破 \(targetStr)"
        case .below:
            content.body = "当前价格 \(priceStr) 已跌破 \(targetStr)"
        }
        
        content.sound = .default
        
        // 创建通知请求
        let request = UNNotificationRequest(
            identifier: alert.id.uuidString,
            content: content,
            trigger: nil // 立即发送
        )
        
        // 添加通知
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送通知失败: \(error)")
            } else {
                print("通知已发送: \(alert.stockName)")
            }
        }
    }
}

