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
            switch currentPage {
            case .stockList:
                StockListView(
                    onOpenSettings: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentPage = .settings
                        }
                    },
                    onOpenPriceAlert: { stock in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            selectedStockForAlert = stock
                            currentPage = .priceAlert
                        }
                    }
                )
                .transition(.move(edge: .leading))
                
            case .settings:
                SettingsContainerView(onBack: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        currentPage = .stockList
                    }
                })
                .transition(.move(edge: .trailing))
                
            case .priceAlert:
                if let stock = selectedStockForAlert {
                    PriceAlertView(stock: stock) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            currentPage = .stockList
                            selectedStockForAlert = nil
                        }
                    }
                    .transition(.move(edge: .trailing))
                }
            }
        }
        .frame(width: 340, height: 450)
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
    
    // 使用后台刷新服务
    @State private var backgroundService = BackgroundRefreshService.shared
    @State private var appSettings = AppSettings.shared
    @State private var isHoveringSettings = false
    
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
            
            Divider()
            
            // 股票列表
            stockListView
            
            Divider()
            
            // 底部操作栏
            footerView
        }
    }
    
    // MARK: - 顶部标题栏
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Logo 和标题
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue)
                Text("Stock Reminder")
                    .font(.system(size: 13, weight: .semibold))
            }
            
            Spacer()
            
            // 刷新按钮
            Button(action: refreshData) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isLoading ? 360 : 0))
                    .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            
            // 设置按钮
            Button(action: onOpenSettings) {
                ZStack {
                    Circle()
                        .fill(isHoveringSettings ? Color.accentColor.opacity(0.15) : Color.clear)
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(isHoveringSettings ? .blue : .secondary)
                }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringSettings = hovering
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
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
                LazyVStack(spacing: 0) {
                    ForEach(Array(stocks.enumerated()), id: \.element.id) { index, stock in
                        StockRowView(stock: stock, onOpenPriceAlert: {
                            onOpenPriceAlert(stock)
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        
                        if index < stocks.count - 1 {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("加载中...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorView(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text("加载失败")
                .font(.system(size: 13, weight: .medium))
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Button(action: refreshData) {
                Text("重试")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text("暂无自选股票")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Button(action: onOpenSettings) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                    Text("添加股票")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 底部操作栏
    
    private var footerView: some View {
        HStack(spacing: 8) {
            // 股票数量
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.yellow)
                Text("\(stocks.count)")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.secondary)
            
            // 自动刷新状态
            if appSettings.autoRefreshEnabled {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 8))
                    Text("\(nextRefreshIn)s")
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // 更新时间
            if let time = stocks.first?.time, !time.isEmpty {
                Text(formatTime(time))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // 退出按钮
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("退出")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
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
}

// MARK: - 股票行视图

struct StockRowView: View {
    let stock: StockData
    let onOpenPriceAlert: () -> Void
    
    @State private var isHovering = false
    @State private var alertManager = PriceAlertManager.shared
    
    private var alertCount: Int {
        alertManager.activeAlertCount(forStock: stock.code)
    }
    
    var body: some View {
        HStack(spacing: 10) {
            // 左侧：名称和代码
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(stock.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    
                    // 提醒图标
                    if alertCount > 0 || isHovering {
                        Button(action: onOpenPriceAlert) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: alertCount > 0 ? "bell.fill" : "bell")
                                    .font(.system(size: 10))
                                    .foregroundStyle(alertCount > 0 ? .orange : .secondary)
                                
                                if alertCount > 0 {
                                    Text("\(alertCount)")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(2)
                                        .background(Circle().fill(.orange))
                                        .offset(x: 5, y: -3)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                
                HStack(spacing: 4) {
                    marketBadge
                    Text(stock.code.uppercased())
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 右侧：价格和涨跌
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.2f", stock.price))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(priceColor)
                
                // 涨跌幅标签
                Text(stock.percentText)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(priceColor)
                    )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var marketBadge: some View {
        Text(stock.marketType.rawValue)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(marketColor)
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
        case .aStock: return .red.opacity(0.8)
        case .hkStock: return .orange.opacity(0.8)
        case .usStock: return .blue.opacity(0.8)
        case .cnFuture: return .purple.opacity(0.8)
        case .overseaFuture: return .indigo.opacity(0.8)
        case .unknown: return .gray.opacity(0.8)
        }
    }
}

#Preview {
    ContentView()
}
