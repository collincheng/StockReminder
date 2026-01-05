//
//  AppSettings.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation
import SwiftUI

/// 应用设置
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    // MARK: - 刷新间隔配置
    
    /// 最小刷新间隔（秒）
    static let minRefreshInterval: TimeInterval = 3
    
    /// 默认刷新间隔（秒）
    static let defaultRefreshInterval: TimeInterval = 30
    
    /// 可选的刷新间隔选项（秒）
    static let refreshIntervalOptions: [TimeInterval] = [5, 10, 15, 30, 60, 120, 300]
    
    /// 用户设置的刷新间隔（秒）
    var refreshInterval: TimeInterval {
        didSet {
            // 确保不低于最小间隔
            if refreshInterval < Self.minRefreshInterval {
                refreshInterval = Self.minRefreshInterval
            }
            saveToUserDefaults()
        }
    }
    
    /// 是否启用自动刷新
    var autoRefreshEnabled: Bool {
        didSet {
            saveToUserDefaults()
        }
    }
    
    /// 是否只在交易时间刷新
    var onlyRefreshDuringTradingHours: Bool {
        didSet {
            saveToUserDefaults()
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private let refreshIntervalKey = "refreshInterval"
    private let autoRefreshEnabledKey = "autoRefreshEnabled"
    private let onlyRefreshDuringTradingHoursKey = "onlyRefreshDuringTradingHours"
    
    // MARK: - 初始化
    
    private init() {
        // 从 UserDefaults 加载设置
        let defaults = UserDefaults.standard
        
        let savedInterval = defaults.double(forKey: refreshIntervalKey)
        self.refreshInterval = savedInterval > 0 ? savedInterval : Self.defaultRefreshInterval
        
        // 默认启用自动刷新
        if defaults.object(forKey: autoRefreshEnabledKey) != nil {
            self.autoRefreshEnabled = defaults.bool(forKey: autoRefreshEnabledKey)
        } else {
            self.autoRefreshEnabled = true
        }
        
        // 默认只在交易时间刷新
        if defaults.object(forKey: onlyRefreshDuringTradingHoursKey) != nil {
            self.onlyRefreshDuringTradingHours = defaults.bool(forKey: onlyRefreshDuringTradingHoursKey)
        } else {
            self.onlyRefreshDuringTradingHours = true
        }
    }
    
    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(refreshInterval, forKey: refreshIntervalKey)
        defaults.set(autoRefreshEnabled, forKey: autoRefreshEnabledKey)
        defaults.set(onlyRefreshDuringTradingHours, forKey: onlyRefreshDuringTradingHoursKey)
    }
    
    // MARK: - 交易时间判断
    
    /// 判断当前是否是 A 股交易时间
    var isAStockTradingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取当前时间的小时和分钟
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        guard let hour = components.hour,
              let minute = components.minute,
              let weekday = components.weekday else {
            return false
        }
        
        // 周末不交易 (1 = 周日, 7 = 周六)
        if weekday == 1 || weekday == 7 {
            return false
        }
        
        let currentMinutes = hour * 60 + minute
        
        // A股交易时间：9:30-11:30, 13:00-15:00
        let morningStart = 9 * 60 + 30   // 9:30
        let morningEnd = 11 * 60 + 30    // 11:30
        let afternoonStart = 13 * 60      // 13:00
        let afternoonEnd = 15 * 60        // 15:00
        
        return (currentMinutes >= morningStart && currentMinutes <= morningEnd) ||
               (currentMinutes >= afternoonStart && currentMinutes <= afternoonEnd)
    }
    
    /// 判断当前是否是美股交易时间（美东时间 9:30-16:00，含盘前盘后 4:00-20:00）
    var isUSStockTradingTime: Bool {
        // 简化处理：美股包含盘前盘后时间较长，这里使用宽松判断
        // 北京时间：夏令时 21:30-04:00，冬令时 22:30-05:00
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .weekday], from: now)
        
        guard let hour = components.hour, let weekday = components.weekday else {
            return false
        }
        
        // 周末不交易
        if weekday == 1 || weekday == 7 {
            return false
        }
        
        // 北京时间大致范围：21:00 - 05:00（跨天）
        return hour >= 21 || hour <= 5
    }
    
    /// 是否应该刷新（综合考虑各市场）
    var shouldRefresh: Bool {
        if !onlyRefreshDuringTradingHours {
            return true
        }
        
        // 只要有一个市场在交易，就应该刷新
        return isAStockTradingTime || isUSStockTradingTime
    }
    
    /// 获取刷新间隔描述
    func intervalDescription(_ interval: TimeInterval) -> String {
        if interval < 60 {
            return "\(Int(interval)) 秒"
        } else {
            return "\(Int(interval / 60)) 分钟"
        }
    }
}

