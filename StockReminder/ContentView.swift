//
//  ContentView.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import SwiftUI

// MARK: - 主容器视图

struct ContentView: View {
    @State private var currentPage: AppPage = .stockList
    @State private var selectedStockForAlert: StockData?
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            switch currentPage {
            case .stockList:
                StockListView(
                    onOpenSettings: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            currentPage = .settings
                        }
                    },
                    onOpenPriceAlert: { stock in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedStockForAlert = stock
                            currentPage = .priceAlert
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
            case .settings:
                SettingsContainerView(onBack: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        currentPage = .stockList
                    }
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
                
            case .priceAlert:
                if let stock = selectedStockForAlert {
                    PriceAlertView(stock: stock) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            currentPage = .stockList
                            selectedStockForAlert = nil
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
            }
        }
        .frame(width: 360, height: 480)
        .clipped()
    }
}

enum AppPage {
    case stockList
    case settings
    case priceAlert
}

// MARK: - 股票列表视图

struct StockListView: View {
    let onOpenSettings: () -> Void
    let onOpenPriceAlert: (StockData) -> Void
    
    // 使用后台刷新服务（直接引用单例，让 @Observable 自动追踪变化）
    private var backgroundService: BackgroundRefreshService { BackgroundRefreshService.shared }
    private var appSettings: AppSettings { AppSettings.shared }
    @State private var isHoveringSettings = false
    @State private var isHoveringRefresh = false
    
    // 从后台服务获取数据
    private var stocks: [StockData] { backgroundService.stocks }
    private var isLoading: Bool { backgroundService.isLoading }
    private var errorMessage: String? { backgroundService.errorMessage }
    private var lastRefreshTime: Date? { backgroundService.lastRefreshTime }
    private var nextRefreshIn: Int { backgroundService.nextRefreshIn }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            // 股票列表
            stockListView
            
            // 底部操作栏
            footerView
        }
    }
    
    // MARK: - 顶部标题栏
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Logo 和标题
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Stock Reminder")
                        .font(.system(size: 13, weight: .semibold))
                    if appSettings.autoRefreshEnabled && nextRefreshIn > 0 {
                        Text("\(nextRefreshIn)s 后刷新")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            // 刷新按钮
            Button(action: refreshData) {
                ZStack {
                    Circle()
                        .fill(isHoveringRefresh ? Color.blue.opacity(0.1) : Color.clear)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isHoveringRefresh ? .blue : .secondary)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringRefresh = hovering
                }
            }
            
            // 设置按钮
            Button(action: onOpenSettings) {
                ZStack {
                    Circle()
                        .fill(isHoveringSettings ? Color.accentColor.opacity(0.1) : Color.clear)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(isHoveringSettings ? .blue : .secondary)
                        .rotationEffect(.degrees(isHoveringSettings ? 30 : 0))
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isHoveringSettings = hovering
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
        )
    }
    
    // MARK: - 股票列表
    
    @ViewBuilder
    private var stockListView: some View {
        if isLoading && stocks.isEmpty {
            loadingView
        } else if let error = errorMessage {
            errorView(error)
        } else if stocks.isEmpty {
            emptyView
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(stocks.enumerated()), id: \.element.id) { index, stock in
                        StockRowView(stock: stock, onOpenPriceAlert: {
                            onOpenPriceAlert(stock)
                        })
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 3)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isLoading)
            }
            
            Text("正在获取行情...")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.orange)
            }
            
            VStack(spacing: 6) {
                Text("加载失败")
                    .font(.system(size: 14, weight: .semibold))
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            Button(action: refreshData) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                    Text("重试")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 6) {
                Text("暂无自选股票")
                    .font(.system(size: 15, weight: .semibold))
                Text("添加您关注的股票，随时掌握行情动态")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: onOpenSettings) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("添加股票")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 底部操作栏
    
    private var footerView: some View {
        VStack(spacing: 6) {
            // 市场交易状态
            marketStatusBar
            
            HStack(spacing: 10) {
                // 股票数量
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.yellow)
                    Text("\(stocks.count) 只自选")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                
                Spacer()
                
                // 更新时间
                if let time = lastRefreshTime {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 5, height: 5)
                        Text("更新于 \(formatRefreshTime(time))")
                            .font(.system(size: 10))
                    }
                    .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                // 退出按钮
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "power")
                            .font(.system(size: 9))
                        Text("退出")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 1, y: -1)
        )
    }
    
    /// 市场状态栏
    private var marketStatusBar: some View {
        let tradingHours = MarketTradingHours.shared
        let activeMarkets = backgroundService.activeTradingMarkets
        let inactiveMarkets = backgroundService.inactiveMarkets
        
        return HStack(spacing: 8) {
            // 交易中的市场
            if !activeMarkets.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)
                    Text(activeMarkets.map { $0.rawValue }.joined(separator: "·"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.green)
                }
            }
            
            // 休市的市场
            if !inactiveMarkets.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.gray.opacity(0.5))
                        .frame(width: 5, height: 5)
                    Text(inactiveMarkets.map { $0.rawValue }.joined(separator: "·"))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 如果全部休市
            if activeMarkets.isEmpty && !inactiveMarkets.isEmpty {
                Text("全部休市")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
    
    // MARK: - 方法
    
    private func refreshData() {
        backgroundService.refresh()
    }
    
    private func formatTime(_ time: String) -> String {
        // 只显示时间部分
        if time.contains(" ") {
            return time.components(separatedBy: " ").last ?? time
        }
        return time
    }
    
    private func formatRefreshTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - 股票行视图

struct StockRowView: View {
    let stock: StockData
    let onOpenPriceAlert: () -> Void
    
    @State private var isHovering = false
    @State private var isPressed = false
    private var alertManager: PriceAlertManager { PriceAlertManager.shared }
    private var appSettings: AppSettings { AppSettings.shared }
    
    private var alertCount: Int {
        alertManager.activeAlertCount(forStock: stock.code)
    }
    
    /// 是否是菜单栏显示的股票
    private var isMenuBarStock: Bool {
        appSettings.menuBarStockCode.lowercased() == stock.code.lowercased()
    }
    
    var body: some View {
        Button(action: {
            // 点击切换菜单栏显示的股票
            if appSettings.showStockInMenuBar {
                if isMenuBarStock {
                    // 如果已经是菜单栏股票，取消显示
                    appSettings.menuBarStockCode = ""
                } else {
                    // 设置为菜单栏显示的股票
                    appSettings.menuBarStockCode = stock.code
                }
                // 切换后关闭 popover
                NotificationCenter.default.post(name: .closePopover, object: nil)
            }
        }) {
            HStack(spacing: 12) {
                // 左侧：涨跌指示条
                RoundedRectangle(cornerRadius: 2)
                    .fill(priceColor.opacity(0.8))
                    .frame(width: 3, height: 36)
                
                // 中间：名称和代码
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(stock.name)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        
                        // 菜单栏显示标记
                        if isMenuBarStock && appSettings.showStockInMenuBar {
                            Image(systemName: "menubar.rectangle")
                                .font(.system(size: 9))
                                .foregroundStyle(.purple)
                                .padding(3)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.purple.opacity(0.1))
                                )
                        }
                        
                        // 提醒图标
                        if alertCount > 0 || isHovering {
                            Button(action: onOpenPriceAlert) {
                                HStack(spacing: 2) {
                                    Image(systemName: alertCount > 0 ? "bell.fill" : "bell")
                                        .font(.system(size: 10))
                                    if alertCount > 0 {
                                        Text("\(alertCount)")
                                            .font(.system(size: 9, weight: .semibold))
                                    }
                                }
                                .foregroundStyle(alertCount > 0 ? .orange : .secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(alertCount > 0 ? Color.orange.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                                )
                            }
                            .buttonStyle(.plain)
                            .highPriorityGesture(
                                TapGesture().onEnded { _ in
                                    onOpenPriceAlert()
                                }
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    HStack(spacing: 6) {
                        marketBadge
                        Text(stock.code.uppercased())
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                // 右侧：价格和涨跌
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.2f", stock.price))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)

                    // 涨跌幅标签
                    HStack(spacing: 3) {
                        Image(systemName: stock.isUp ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                            .font(.system(size: 8))
                        Text(stock.percentText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: stock.isUp ?
                                        [Color.red, Color.red.opacity(0.8)] :
                                        [Color.green, Color.green.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHovering ? 
                      Color(nsColor: .controlBackgroundColor) : 
                      Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .shadow(color: isHovering ? .black.opacity(0.05) : .clear, radius: 4, y: 2)
        )
        .scaleEffect(isPressed ? 0.98 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isPressed)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            // 右键菜单
            Button(action: onOpenPriceAlert) {
                Label("价格提醒", systemImage: "bell")
            }
            
            Divider()
            
            if appSettings.showStockInMenuBar {
                if isMenuBarStock {
                    Button(action: {
                        appSettings.menuBarStockCode = ""
                    }) {
                        Label("取消菜单栏显示", systemImage: "menubar.rectangle")
                    }
                } else {
                    Button(action: {
                        appSettings.menuBarStockCode = stock.code
                    }) {
                        Label("在菜单栏显示", systemImage: "menubar.rectangle")
                    }
                }
            }
        }
    }
    
    private var marketBadge: some View {
        Text(stock.marketType.rawValue)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(marketColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(marketColor.opacity(0.12))
            )
    }
    
    private var priceColor: Color {
        if stock.updown > 0 {
            return .red
        } else if stock.updown < 0 {
            return .green
        }
        return .secondary
    }
    
    private var marketColor: Color {
        switch stock.marketType {
        case .aStock: return .red
        case .hkStock: return .orange
        case .usStock: return .blue
        case .cnFuture: return .purple
        case .overseaFuture: return .indigo
        case .unknown: return .gray
        }
    }
}

#Preview {
    ContentView()
}
