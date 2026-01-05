//
//  MarketTradingHours.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation

/// 市场交易时间管理器
class MarketTradingHours {
    static let shared = MarketTradingHours()
    
    private init() {}
    
    // MARK: - 交易时间配置
    
    /// A股交易时间（北京时间）
    /// 上午：9:30 - 11:30
    /// 下午：13:00 - 15:00
    struct AStockHours {
        static let morningStart = (hour: 9, minute: 30)
        static let morningEnd = (hour: 11, minute: 30)
        static let afternoonStart = (hour: 13, minute: 0)
        static let afternoonEnd = (hour: 15, minute: 0)
    }
    
    /// 港股交易时间（北京时间，与香港时间相同）
    /// 上午：9:30 - 12:00
    /// 下午：13:00 - 16:00
    struct HKStockHours {
        static let morningStart = (hour: 9, minute: 30)
        static let morningEnd = (hour: 12, minute: 0)
        static let afternoonStart = (hour: 13, minute: 0)
        static let afternoonEnd = (hour: 16, minute: 0)
    }
    
    /// 美股交易时间（北京时间）
    /// 夏令时（3月第二个周日 - 11月第一个周日）：21:30 - 04:00 (次日)
    /// 冬令时：22:30 - 05:00 (次日)
    /// 盘前：夏令时 16:00-21:30，冬令时 17:00-22:30
    /// 盘后：夏令时 04:00-08:00，冬令时 05:00-09:00
    struct USStockHours {
        // 常规交易时间
        static let summerStart = (hour: 21, minute: 30)
        static let summerEnd = (hour: 4, minute: 0)  // 次日
        static let winterStart = (hour: 22, minute: 30)
        static let winterEnd = (hour: 5, minute: 0)  // 次日
        
        // 包含盘前盘后的扩展时间
        static let summerExtendedStart = (hour: 16, minute: 0)
        static let summerExtendedEnd = (hour: 8, minute: 0)  // 次日
        static let winterExtendedStart = (hour: 17, minute: 0)
        static let winterExtendedEnd = (hour: 9, minute: 0)  // 次日
    }
    
    /// 国内期货交易时间（北京时间）
    /// 日盘：9:00-10:15, 10:30-11:30, 13:30-15:00
    /// 夜盘：21:00-23:00 或 21:00-次日01:00 或 21:00-次日02:30（根据品种不同）
    struct CNFutureHours {
        static let morning1Start = (hour: 9, minute: 0)
        static let morning1End = (hour: 10, minute: 15)
        static let morning2Start = (hour: 10, minute: 30)
        static let morning2End = (hour: 11, minute: 30)
        static let afternoonStart = (hour: 13, minute: 30)
        static let afternoonEnd = (hour: 15, minute: 0)
        static let nightStart = (hour: 21, minute: 0)
        static let nightEnd = (hour: 2, minute: 30)  // 次日，取最长的
    }
    
    /// 海外期货交易时间（近乎24小时）
    /// 简化处理：周一到周五几乎全天交易
    struct OverseaFutureHours {
        // 大部分海外期货接近24小时交易，只在固定时段休市
        static let tradingHours = 23 // 小时
    }
    
    // MARK: - 判断是否是夏令时
    
    /// 判断当前是否是美国夏令时
    /// 夏令时：3月第二个周日凌晨2点 - 11月第一个周日凌晨2点
    var isUSDaylightSavingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        
        // 计算夏令时开始日期（3月第二个周日）
        var dstStart = DateComponents()
        dstStart.year = year
        dstStart.month = 3
        dstStart.weekday = 1 // 周日
        dstStart.weekdayOrdinal = 2 // 第二个
        dstStart.hour = 2
        
        // 计算夏令时结束日期（11月第一个周日）
        var dstEnd = DateComponents()
        dstEnd.year = year
        dstEnd.month = 11
        dstEnd.weekday = 1 // 周日
        dstEnd.weekdayOrdinal = 1 // 第一个
        dstEnd.hour = 2
        
        guard let startDate = calendar.date(from: dstStart),
              let endDate = calendar.date(from: dstEnd) else {
            return false
        }
        
        return now >= startDate && now < endDate
    }
    
    // MARK: - 交易时间判断
    
    /// 判断指定市场当前是否在交易时间
    func isTradingTime(for market: MarketType) -> Bool {
        switch market {
        case .aStock:
            return isAStockTradingTime
        case .hkStock:
            return isHKStockTradingTime
        case .usStock:
            return isUSStockTradingTime
        case .cnFuture:
            return isCNFutureTradingTime
        case .overseaFuture:
            return isOverseaFutureTradingTime
        case .unknown:
            return true // 未知市场默认可以刷新
        }
    }
    
    /// 判断当前是否是 A 股交易时间
    var isAStockTradingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        
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
        
        let morningStart = AStockHours.morningStart.hour * 60 + AStockHours.morningStart.minute
        let morningEnd = AStockHours.morningEnd.hour * 60 + AStockHours.morningEnd.minute
        let afternoonStart = AStockHours.afternoonStart.hour * 60 + AStockHours.afternoonStart.minute
        let afternoonEnd = AStockHours.afternoonEnd.hour * 60 + AStockHours.afternoonEnd.minute
        
        return (currentMinutes >= morningStart && currentMinutes <= morningEnd) ||
               (currentMinutes >= afternoonStart && currentMinutes <= afternoonEnd)
    }
    
    /// 判断当前是否是港股交易时间
    var isHKStockTradingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        guard let hour = components.hour,
              let minute = components.minute,
              let weekday = components.weekday else {
            return false
        }
        
        // 周末不交易
        if weekday == 1 || weekday == 7 {
            return false
        }
        
        let currentMinutes = hour * 60 + minute
        
        let morningStart = HKStockHours.morningStart.hour * 60 + HKStockHours.morningStart.minute
        let morningEnd = HKStockHours.morningEnd.hour * 60 + HKStockHours.morningEnd.minute
        let afternoonStart = HKStockHours.afternoonStart.hour * 60 + HKStockHours.afternoonStart.minute
        let afternoonEnd = HKStockHours.afternoonEnd.hour * 60 + HKStockHours.afternoonEnd.minute
        
        return (currentMinutes >= morningStart && currentMinutes <= morningEnd) ||
               (currentMinutes >= afternoonStart && currentMinutes <= afternoonEnd)
    }
    
    /// 判断当前是否是美股交易时间（包含盘前盘后）
    var isUSStockTradingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        guard let hour = components.hour,
              let minute = components.minute,
              let weekday = components.weekday else {
            return false
        }
        
        // 周末不交易（注意美股周末按美国时间，这里简化处理）
        // 北京时间周六早上到周一早上是美股休市
        if weekday == 7 { // 周六全天休市
            return false
        }
        if weekday == 1 && hour < 6 { // 周日凌晨之前（周六美国时间）
            return false
        }
        
        let currentMinutes = hour * 60 + minute
        
        // 根据夏令时/冬令时判断
        if isUSDaylightSavingTime {
            // 夏令时：扩展时间 16:00 - 次日 08:00
            let extendedStart = USStockHours.summerExtendedStart.hour * 60 + USStockHours.summerExtendedStart.minute
            let extendedEnd = USStockHours.summerExtendedEnd.hour * 60 + USStockHours.summerExtendedEnd.minute
            
            // 跨天处理：16:00-24:00 或 00:00-08:00
            return currentMinutes >= extendedStart || currentMinutes <= extendedEnd
        } else {
            // 冬令时：扩展时间 17:00 - 次日 09:00
            let extendedStart = USStockHours.winterExtendedStart.hour * 60 + USStockHours.winterExtendedStart.minute
            let extendedEnd = USStockHours.winterExtendedEnd.hour * 60 + USStockHours.winterExtendedEnd.minute
            
            return currentMinutes >= extendedStart || currentMinutes <= extendedEnd
        }
    }
    
    /// 判断当前是否是国内期货交易时间
    var isCNFutureTradingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: now)
        guard let hour = components.hour,
              let minute = components.minute,
              let weekday = components.weekday else {
            return false
        }
        
        // 周末不交易（周六全天，周日夜盘前）
        if weekday == 7 { // 周六
            return false
        }
        if weekday == 1 && hour < 21 { // 周日夜盘前
            return false
        }
        
        let currentMinutes = hour * 60 + minute
        
        // 日盘时间段
        let morning1Start = CNFutureHours.morning1Start.hour * 60 + CNFutureHours.morning1Start.minute
        let morning1End = CNFutureHours.morning1End.hour * 60 + CNFutureHours.morning1End.minute
        let morning2Start = CNFutureHours.morning2Start.hour * 60 + CNFutureHours.morning2Start.minute
        let morning2End = CNFutureHours.morning2End.hour * 60 + CNFutureHours.morning2End.minute
        let afternoonStart = CNFutureHours.afternoonStart.hour * 60 + CNFutureHours.afternoonStart.minute
        let afternoonEnd = CNFutureHours.afternoonEnd.hour * 60 + CNFutureHours.afternoonEnd.minute
        
        // 夜盘时间段
        let nightStart = CNFutureHours.nightStart.hour * 60 + CNFutureHours.nightStart.minute
        let nightEnd = CNFutureHours.nightEnd.hour * 60 + CNFutureHours.nightEnd.minute
        
        // 日盘
        if (currentMinutes >= morning1Start && currentMinutes <= morning1End) ||
           (currentMinutes >= morning2Start && currentMinutes <= morning2End) ||
           (currentMinutes >= afternoonStart && currentMinutes <= afternoonEnd) {
            return true
        }
        
        // 夜盘（跨天）
        if currentMinutes >= nightStart || currentMinutes <= nightEnd {
            return true
        }
        
        return false
    }
    
    /// 判断当前是否是海外期货交易时间
    var isOverseaFutureTradingTime: Bool {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.hour, .weekday], from: now)
        guard let hour = components.hour, let weekday = components.weekday else {
            return false
        }
        
        // 周末部分时间休市（简化处理）
        // 北京时间周六早上约5-6点到周一早上约6-7点休市
        if weekday == 7 && hour >= 6 { // 周六6点后
            return false
        }
        if weekday == 1 && hour < 7 { // 周日7点前
            return false
        }
        
        return true
    }
    
    // MARK: - 获取市场状态描述
    
    /// 获取市场当前状态描述
    func statusDescription(for market: MarketType) -> String {
        if isTradingTime(for: market) {
            return "交易中"
        } else {
            return "休市"
        }
    }
    
    /// 获取市场交易时间描述
    func tradingHoursDescription(for market: MarketType) -> String {
        switch market {
        case .aStock:
            return "9:30-11:30, 13:00-15:00"
        case .hkStock:
            return "9:30-12:00, 13:00-16:00"
        case .usStock:
            if isUSDaylightSavingTime {
                return "21:30-04:00 (夏令时)"
            } else {
                return "22:30-05:00 (冬令时)"
            }
        case .cnFuture:
            return "日盘+夜盘"
        case .overseaFuture:
            return "近24小时"
        case .unknown:
            return "未知"
        }
    }
    
    // MARK: - 检查股票是否在交易时间
    
    /// 检查股票是否在其所属市场的交易时间内
    func isStockTradingTime(stockCode: String) -> Bool {
        let market = getMarketType(from: stockCode)
        return isTradingTime(for: market)
    }
    
    /// 从股票代码获取市场类型
    func getMarketType(from code: String) -> MarketType {
        let lowerCode = code.lowercased()
        if lowerCode.hasPrefix("sh") || lowerCode.hasPrefix("sz") || lowerCode.hasPrefix("bj") {
            return .aStock
        } else if lowerCode.hasPrefix("hk") {
            return .hkStock
        } else if lowerCode.hasPrefix("usr_") || lowerCode.hasPrefix("gb_") {
            return .usStock
        } else if lowerCode.hasPrefix("nf_") {
            return .cnFuture
        } else if lowerCode.hasPrefix("hf_") {
            return .overseaFuture
        }
        return .unknown
    }
    
    // MARK: - 获取当前有交易的市场
    
    /// 获取当前正在交易的市场列表
    var currentTradingMarkets: [MarketType] {
        MarketType.allCases.filter { isTradingTime(for: $0) }
    }
    
    /// 是否有任何市场正在交易
    var isAnyMarketTrading: Bool {
        !currentTradingMarkets.isEmpty
    }
}

// MARK: - MarketType 扩展

extension MarketType: CaseIterable {
    static var allCases: [MarketType] {
        [.aStock, .hkStock, .usStock, .cnFuture, .overseaFuture]
    }
}

