//
//  BackgroundRefreshService.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation
import Combine

/// 后台刷新服务 - 独立于视图生命周期运行
@MainActor
@Observable
class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()
    
    /// 最新的股票数据
    var stocks: [StockData] = []

    /// 上次各股票的累计成交量，用于计算增量
    private var previousVolumes: [String: Double] = [:]
    /// 上次各股票的价格，用于无买卖盘数据时的回退判断
    private var previousPrices: [String: Double] = [:]
    
    /// 当前选中股票的分时数据
    var minuteData: [MinuteData] = []
    /// 当前显示分时图的股票代码
    var minuteChartCode: String = ""

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
            MainActor.assumeIsolated { self?.restartBackgroundRefresh() }
        }

        // 监听自动刷新开关变化
        NotificationCenter.default.addObserver(
            forName: .autoRefreshDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                if self.appSettings.autoRefreshEnabled {
                    self.startBackgroundRefresh()
                } else {
                    self.stopBackgroundRefresh()
                }
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
            MainActor.assumeIsolated {
                guard let self = self else { return }

                self.nextRefreshIn -= 1

                // 每分钟更新一次市场状态
                if Int(Date().timeIntervalSince1970) % 60 == 0 {
                    self.updateMarketStatus()
                }

                if self.nextRefreshIn <= 0 {
                    self.nextRefreshIn = Int(self.appSettings.refreshInterval)

                    if self.appSettings.shouldRefresh {
                        Task { await self.loadStockData() }
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
            stocks = []
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let data = try await StockService.shared.getStockData(codes: codes)

            // 按照 stockStore.stockCodes 的顺序排列
            var sortedData = sortStocksByOrder(stocks: data, order: codes)

            // 计算每只股票的成交增量和买卖方向
            for i in sortedData.indices {
                let key = sortedData[i].code.lowercased()
                let prevVol = previousVolumes[key] ?? sortedData[i].volume
                sortedData[i].volumeDelta = max(sortedData[i].volume - prevVol, 0)

                // 判断成交量颜色：有买一卖一数据时用盘口判断，否则用价格变化
                let price = sortedData[i].price
                let sell1 = sortedData[i].sell1Price
                let buy1 = sortedData[i].buy1Price
                if sell1 > 0 && buy1 > 0 {
                    // 成交价 >= 卖一 → 主动买入(红)，<= 买一 → 主动卖出(绿)，中间保持上次
                    if price >= sell1 {
                        sortedData[i].volumeIsUp = true
                    } else if price <= buy1 {
                        sortedData[i].volumeIsUp = false
                    }
                    // 买一和卖一之间：保持默认值(true)，不改变
                } else {
                    // 无盘口数据(美股/期货)，用价格变化判断
                    let prevPrice = previousPrices[key] ?? price
                    sortedData[i].volumeIsUp = price >= prevPrice
                }

                previousVolumes[key] = sortedData[i].volume
                previousPrices[key] = price
            }

            stocks = sortedData
            isLoading = false
            lastRefreshTime = Date()

            // 检查价格提醒
            alertManager.checkPrices(stocks: sortedData)

            // 同步刷新分时图
            if !minuteChartCode.isEmpty {
                await loadMinuteData(code: minuteChartCode)
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
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
            // 同步刷新分时图
            if !minuteChartCode.isEmpty {
                await loadMinuteData(code: minuteChartCode)
            }
        }
    }

    /// 加载分时数据
    func loadMinuteData(code: String) async {
        let yestclose = stocks.first { $0.code.lowercased() == code.lowercased() }?.yestclose ?? 0
        do {
            let data = try await StockService.shared.getMinuteData(code: code, yestclose: yestclose)
            minuteChartCode = code
            minuteData = data
        } catch {
            // 分时数据加载失败不影响主流程
        }
    }
}

// MARK: - 通知名称

extension Notification.Name {
    static let stockCodesDidChange = Notification.Name("stockCodesDidChange")
    static let refreshIntervalDidChange = Notification.Name("refreshIntervalDidChange")
    static let autoRefreshDidChange = Notification.Name("autoRefreshDidChange")
    static let menuBarDisplayDidChange = Notification.Name("menuBarDisplayDidChange")
    static let closePopover = Notification.Name("closePopover")
}

