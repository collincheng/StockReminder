//
//  BackgroundRefreshService.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation
import Combine

/// 后台刷新服务 - 独立于视图生命周期运行
@Observable
class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()
    
    /// 最新的股票数据
    var stocks: [StockData] = []
    
    /// 是否正在加载
    var isLoading = false
    
    /// 错误信息
    var errorMessage: String?
    
    /// 上次刷新时间
    var lastRefreshTime: Date?
    
    /// 下次刷新倒计时
    var nextRefreshIn: Int = 0
    
    /// 各市场交易状态
    var marketStatus: [MarketType: Bool] = [:]
    
    private var refreshTimer: Timer?
    private let stockStore = StockStore.shared
    private let appSettings = AppSettings.shared
    private let alertManager = PriceAlertManager.shared
    private let tradingHours = MarketTradingHours.shared
    
    private init() {
        // 初始化市场状态
        updateMarketStatus()
        
        // 启动时立即加载数据
        Task {
            await loadStockData()
        }
        
        // 启动后台定时刷新
        startBackgroundRefresh()
        
        // 监听设置变化
        setupObservers()
    }
    
    // MARK: - 市场状态更新
    
    /// 更新各市场交易状态
    func updateMarketStatus() {
        for market in MarketType.allCases {
            marketStatus[market] = tradingHours.isTradingTime(for: market)
        }
    }
    
    /// 获取用户持有的各市场股票数量
    func stockCountByMarket() -> [MarketType: Int] {
        var counts: [MarketType: Int] = [:]
        for stock in stocks {
            counts[stock.marketType, default: 0] += 1
        }
        return counts
    }
    
    /// 获取当前交易中的市场（只返回用户有股票的市场）
    var activeTradingMarkets: [MarketType] {
        let counts = stockCountByMarket()
        return MarketType.allCases.filter { market in
            (counts[market] ?? 0) > 0 && (marketStatus[market] ?? false)
        }
    }
    
    /// 获取当前休市的市场（只返回用户有股票的市场）
    var inactiveMarkets: [MarketType] {
        let counts = stockCountByMarket()
        return MarketType.allCases.filter { market in
            (counts[market] ?? 0) > 0 && !(marketStatus[market] ?? false)
        }
    }
    
    // MARK: - 设置观察者
    
    private func setupObservers() {
        // 监听股票列表变化
        NotificationCenter.default.addObserver(
            forName: .stockCodesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadStockData()
            }
        }
        
        // 监听刷新间隔变化
        NotificationCenter.default.addObserver(
            forName: .refreshIntervalDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.restartBackgroundRefresh()
        }
        
        // 监听自动刷新开关变化
        NotificationCenter.default.addObserver(
            forName: .autoRefreshDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.appSettings.autoRefreshEnabled {
                self.startBackgroundRefresh()
            } else {
                self.stopBackgroundRefresh()
            }
        }
    }
    
    // MARK: - 后台刷新
    
    func startBackgroundRefresh() {
        guard appSettings.autoRefreshEnabled else { return }
        stopBackgroundRefresh()
        
        let interval = appSettings.refreshInterval
        nextRefreshIn = Int(interval)
        
        // 创建定时器 - 在主线程的 common 模式下运行，即使 UI 在交互也不会暂停
        refreshTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.nextRefreshIn -= 1
            
            // 每分钟更新一次市场状态
            if Int(Date().timeIntervalSince1970) % 60 == 0 {
                self.updateMarketStatus()
            }
            
            if self.nextRefreshIn <= 0 {
                self.nextRefreshIn = Int(self.appSettings.refreshInterval)
                
                // 检查是否应该刷新（交易时间等）
                if self.appSettings.shouldRefresh {
                    Task {
                        await self.loadStockData()
                    }
                }
            }
        }
        
        // 添加到 RunLoop 的 common 模式
        if let timer = refreshTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    func stopBackgroundRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    func restartBackgroundRefresh() {
        stopBackgroundRefresh()
        startBackgroundRefresh()
    }
    
    // MARK: - 数据加载
    
    func loadStockData() async {
        let codes = stockStore.stockCodes
        guard !codes.isEmpty else {
            await MainActor.run {
                stocks = []
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let data = try await StockService.shared.getStockData(codes: codes)
            
            // 按照 stockStore.stockCodes 的顺序排列
            let sortedData = sortStocksByOrder(stocks: data, order: codes)
            
            await MainActor.run {
                stocks = sortedData
                isLoading = false
                lastRefreshTime = Date()
                
                // 检查价格提醒
                alertManager.checkPrices(stocks: sortedData)
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    /// 按照指定顺序排列股票
    private func sortStocksByOrder(stocks: [StockData], order: [String]) -> [StockData] {
        var stockDict: [String: StockData] = [:]
        for stock in stocks {
            stockDict[stock.code.lowercased()] = stock
        }
        
        var sortedStocks: [StockData] = []
        for code in order {
            if let stock = stockDict[code.lowercased()] {
                sortedStocks.append(stock)
            }
        }
        
        return sortedStocks
    }
    
    /// 手动刷新
    func refresh() {
        Task {
            await loadStockData()
        }
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let stockCodesDidChange = Notification.Name("stockCodesDidChange")
    static let refreshIntervalDidChange = Notification.Name("refreshIntervalDidChange")
    static let autoRefreshDidChange = Notification.Name("autoRefreshDidChange")
    static let menuBarDisplayDidChange = Notification.Name("menuBarDisplayDidChange")
}

