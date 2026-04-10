//
//  AppSettings.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation
import SwiftUI

// MARK: - 菜单栏显示类型

enum MenuBarDisplayType: String, CaseIterable, Codable {
    case percent = "percent"        // 显示涨跌幅
    case price = "price"            // 显示当前价格
    case priceAndPercent = "both"   // 显示价格和涨跌幅
    
    var description: String {
        switch self {
        case .percent: return "涨跌幅"
        case .price: return "当前价格"
        case .priceAndPercent: return "价格+涨跌幅"
        }
    }
}

/// 应用设置
@Observable
class AppSettings {
    static let shared = AppSettings()
    
    // MARK: - 刷新间隔配置
    
    /// 最小刷新间隔（秒）
    static let minRefreshInterval: TimeInterval = 3
    
    /// 默认刷新间隔（秒）
    static let defaultRefreshInterval: TimeInterval = 3
    
    /// 可选的刷新间隔选项（秒）
    static let refreshIntervalOptions: [TimeInterval] = [3, 5, 10, 15, 30, 60, 120]
    
    /// 用户设置的刷新间隔（秒）
    var refreshInterval: TimeInterval {
        didSet {
            // 确保不低于最小间隔
            if refreshInterval < Self.minRefreshInterval {
                refreshInterval = Self.minRefreshInterval
            }
            saveToUserDefaults()
            // 通知后台服务
            NotificationCenter.default.post(name: .refreshIntervalDidChange, object: nil)
        }
    }
    
    /// 是否启用自动刷新
    var autoRefreshEnabled: Bool {
        didSet {
            saveToUserDefaults()
            // 通知后台服务
            NotificationCenter.default.post(name: .autoRefreshDidChange, object: nil)
        }
    }
    
    /// 是否只在交易时间刷新
    var onlyRefreshDuringTradingHours: Bool {
        didSet {
            saveToUserDefaults()
        }
    }
    
    // MARK: - 菜单栏显示设置
    
    /// 是否在菜单栏显示股票涨幅
    var showStockInMenuBar: Bool {
        didSet {
            saveToUserDefaults()
            NotificationCenter.default.post(name: .menuBarDisplayDidChange, object: nil)
        }
    }
    
    /// 菜单栏显示的股票代码（空表示显示第一只）
    var menuBarStockCode: String {
        didSet {
            saveToUserDefaults()
            NotificationCenter.default.post(name: .menuBarDisplayDidChange, object: nil)
        }
    }
    
    /// 菜单栏显示内容类型
    var menuBarDisplayType: MenuBarDisplayType {
        didSet {
            saveToUserDefaults()
            NotificationCenter.default.post(name: .menuBarDisplayDidChange, object: nil)
        }
    }

    /// 是否显示成交量
    var showVolume: Bool {
        didSet {
            saveToUserDefaults()
        }
    }
    
    // MARK: - UserDefaults Keys
    
    private let refreshIntervalKey = "refreshInterval"
    private let autoRefreshEnabledKey = "autoRefreshEnabled"
    private let onlyRefreshDuringTradingHoursKey = "onlyRefreshDuringTradingHours"
    private let showStockInMenuBarKey = "showStockInMenuBar"
    private let menuBarStockCodeKey = "menuBarStockCode"
    private let menuBarDisplayTypeKey = "menuBarDisplayType"
    private let showVolumeKey = "showVolume"
    
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
        
        // 菜单栏显示设置
        if defaults.object(forKey: showStockInMenuBarKey) != nil {
            self.showStockInMenuBar = defaults.bool(forKey: showStockInMenuBarKey)
        } else {
            self.showStockInMenuBar = false // 默认关闭
        }
        
        self.menuBarStockCode = defaults.string(forKey: menuBarStockCodeKey) ?? ""
        
        if let typeRaw = defaults.string(forKey: menuBarDisplayTypeKey),
           let type = MenuBarDisplayType(rawValue: typeRaw) {
            self.menuBarDisplayType = type
        } else {
            self.menuBarDisplayType = .percent
        }

        // 成交量显示设置
        if defaults.object(forKey: showVolumeKey) != nil {
            self.showVolume = defaults.bool(forKey: showVolumeKey)
        } else {
            self.showVolume = true // 默认显示
        }
    }
    
    private func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(refreshInterval, forKey: refreshIntervalKey)
        defaults.set(autoRefreshEnabled, forKey: autoRefreshEnabledKey)
        defaults.set(onlyRefreshDuringTradingHours, forKey: onlyRefreshDuringTradingHoursKey)
        defaults.set(showStockInMenuBar, forKey: showStockInMenuBarKey)
        defaults.set(menuBarStockCode, forKey: menuBarStockCodeKey)
        defaults.set(menuBarDisplayType.rawValue, forKey: menuBarDisplayTypeKey)
        defaults.set(showVolume, forKey: showVolumeKey)
    }
    
    // MARK: - 交易时间判断
    
    private var tradingHours: MarketTradingHours { MarketTradingHours.shared }
    
    /// 判断当前是否是 A 股交易时间
    var isAStockTradingTime: Bool {
        tradingHours.isAStockTradingTime
    }
    
    /// 判断当前是否是港股交易时间
    var isHKStockTradingTime: Bool {
        tradingHours.isHKStockTradingTime
    }
    
    /// 判断当前是否是美股交易时间
    var isUSStockTradingTime: Bool {
        tradingHours.isUSStockTradingTime
    }
    
    /// 判断当前是否是国内期货交易时间
    var isCNFutureTradingTime: Bool {
        tradingHours.isCNFutureTradingTime
    }
    
    /// 判断当前是否是海外期货交易时间
    var isOverseaFutureTradingTime: Bool {
        tradingHours.isOverseaFutureTradingTime
    }
    
    /// 是否应该刷新（综合考虑各市场）
    var shouldRefresh: Bool {
        if !onlyRefreshDuringTradingHours {
            return true
        }
        
        // 只要有一个市场在交易，就应该刷新
        return tradingHours.isAnyMarketTrading
    }
    
    /// 检查指定股票是否在交易时间
    func isStockTradingTime(_ stockCode: String) -> Bool {
        if !onlyRefreshDuringTradingHours {
            return true
        }
        return tradingHours.isStockTradingTime(stockCode: stockCode)
    }
    
    /// 检查指定市场是否在交易时间
    func isMarketTradingTime(_ market: MarketType) -> Bool {
        if !onlyRefreshDuringTradingHours {
            return true
        }
        return tradingHours.isTradingTime(for: market)
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

