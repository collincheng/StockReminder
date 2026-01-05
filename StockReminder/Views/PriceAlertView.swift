//
//  PriceAlertView.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import SwiftUI

// MARK: - 价格提醒设置视图

struct PriceAlertView: View {
    let stock: StockData
    let onDismiss: () -> Void
    
    private var alertManager: PriceAlertManager { PriceAlertManager.shared }
    
    @State private var selectedAlertType: AlertType = .above
    @State private var targetPriceText: String = ""
    @State private var showAddAlert = false
    @State private var selectedRepeatInterval: RepeatInterval = .never
    @State private var isHoveringAddButton = false
    
    private var stockAlerts: [PriceAlert] {
        alertManager.getAlerts(forStock: stock.code)
    }
    
    /// 价格颜色
    private var priceColor: Color {
        stock.updown > 0 ? .red : (stock.updown < 0 ? .green : .secondary)
    }
    
    var body: some View {
        ZStack {
            // 背景渐变
            backgroundGradient
            
            VStack(spacing: 0) {
                // 标题栏
                headerView
                
                // 股票信息卡片
                stockInfoCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                // 提醒列表或添加提醒
                if showAddAlert {
                    addAlertView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    alertListView
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
        }
        .frame(width: 340, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            targetPriceText = String(format: "%.2f", stock.price)
        }
    }
    
    // MARK: - 背景渐变
    
    private var backgroundGradient: some View {
        ZStack {
            // 基础背景
            Color(nsColor: .windowBackgroundColor)
            
            // 顶部渐变光晕
            LinearGradient(
                colors: [
                    priceColor.opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            
            // 装饰性圆形
            Circle()
                .fill(
                    RadialGradient(
                        colors: [priceColor.opacity(0.1), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: 120, y: -100)
                .blur(radius: 40)
        }
    }
    
    // MARK: - 标题栏
    
    private var headerView: some View {
        HStack {
            // 返回/关闭按钮
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if showAddAlert {
                        showAddAlert = false
                    } else {
                        onDismiss()
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text(showAddAlert ? "返回" : "关闭")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 标题
            HStack(spacing: 6) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                Text("价格提醒")
                    .font(.system(size: 15, weight: .semibold))
            }
            
            Spacer()
            
            // 添加按钮
            if !showAddAlert {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showAddAlert = true
                    }
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)
                .scaleEffect(isHoveringAddButton ? 1.1 : 1.0)
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringAddButton = hovering
                    }
                }
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - 股票信息卡片
    
    private var stockInfoCard: some View {
        HStack(spacing: 12) {
            // 左侧涨跌指示条
            RoundedRectangle(cornerRadius: 2)
                .fill(priceColor)
                .frame(width: 4, height: 40)
            
            // 股票名称和代码
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.name)
                    .font(.system(size: 15, weight: .semibold))
                
                HStack(spacing: 6) {
                    // 市场标签
                    Text(stock.marketType.rawValue)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(marketColor)
                        )
                    
                    Text(stock.code.uppercased())
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 价格信息
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", stock.price))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(priceColor)
                
                // 涨跌幅标签
                HStack(spacing: 3) {
                    Image(systemName: stock.updown > 0 ? "arrowtriangle.up.fill" : (stock.updown < 0 ? "arrowtriangle.down.fill" : "minus"))
                        .font(.system(size: 8))
                    Text(stock.percentText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(priceColor)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
    
    /// 市场颜色
    private var marketColor: Color {
        switch stock.marketType {
        case .aStock: return .red
        case .hkStock: return .orange
        case .usStock: return .blue
        case .cnFuture: return .purple
        case .overseaFuture: return .teal
        case .unknown: return .gray
        }
    }
    
    // MARK: - 提醒列表
    
    private var alertListView: some View {
        VStack(spacing: 0) {
            if stockAlerts.isEmpty {
                emptyAlertView
            } else {
                // 提醒数量标签
                HStack {
                    Text("已设置 \(stockAlerts.count) 个提醒")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(stockAlerts) { alert in
                            AlertRowView(alert: alert) {
                                alertManager.toggleAlert(id: alert.id)
                            } onDelete: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    alertManager.removeAlert(id: alert.id)
                                }
                            } onReset: {
                                alertManager.resetAlert(id: alert.id)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }
    
    private var emptyAlertView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // 图标
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.15), Color.orange.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bell.slash")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange.opacity(0.6), .orange.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("暂无价格提醒")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("设置价格提醒，当股价达到目标时\n系统将立即通知您")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            // 添加提醒按钮
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAddAlert = true
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("添加提醒")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 添加提醒视图
    
    private var addAlertView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 提醒类型选择
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "提醒类型", icon: "arrow.up.arrow.down")
                    
                    HStack(spacing: 12) {
                        ForEach(AlertType.allCases, id: \.self) { type in
                            alertTypeButton(type)
                        }
                    }
                }
                .padding(16)
                .background(cardBackground)
                
                // 目标价格输入
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(title: "目标价格", icon: "dollarsign.circle")
                    
                    // 价格输入框
                    HStack(spacing: 12) {
                        HStack {
                            Text("¥")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            TextField("输入价格", text: $targetPriceText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                                )
                        )
                        
                        // 调整按钮
                        VStack(spacing: 4) {
                            adjustButton(icon: "plus", action: { adjustPrice(by: 0.01) })
                            adjustButton(icon: "minus", action: { adjustPrice(by: -0.01) })
                        }
                    }
                    
                    // 快捷价格按钮
                    HStack(spacing: 8) {
                        ForEach([-5, -3, 3, 5, 10], id: \.self) { percent in
                            quickPriceButton(percent: percent)
                        }
                    }
                }
                .padding(16)
                .background(cardBackground)
                
                // 重复提醒选项
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionHeader(title: "提醒频率", icon: "repeat")
                        Spacer()
                        Text(selectedRepeatInterval == .never ? "仅提醒1次" : "持续提醒")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                    }
                    
                    // 重复间隔选择
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(RepeatInterval.allCases, id: \.self) { interval in
                            repeatIntervalButton(interval)
                        }
                    }
                }
                .padding(16)
                .background(cardBackground)
                
                // 添加按钮
                Button(action: addAlert) {
                    HStack(spacing: 10) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 16))
                        Text("确认添加")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: Double(targetPriceText) != nil ? 
                                        [Color.blue, Color.blue.opacity(0.8)] : 
                                        [Color.gray, Color.gray.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Double(targetPriceText) != nil ? .blue.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
                .disabled(Double(targetPriceText) == nil)
            }
            .padding(16)
        }
    }
    
    // MARK: - 辅助视图
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.blue)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
    
    private func alertTypeButton(_ type: AlertType) -> some View {
        let isSelected = selectedAlertType == type
        let typeColor: Color = type == .above ? .red : .green
        
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                selectedAlertType = type
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected ? typeColor : Color(nsColor: .controlBackgroundColor))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: type.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(isSelected ? .white : typeColor)
                }
                
                Text("价格\(type.description)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(isSelected ? typeColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? typeColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? typeColor.opacity(0.3) : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func adjustButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
    }
    
    private func quickPriceButton(percent: Int) -> some View {
        let isUp = percent > 0
        let color: Color = isUp ? .red : .green
        
        return Button(action: {
            let newPrice = stock.price * (1 + Double(percent) / 100)
            targetPriceText = String(format: "%.2f", newPrice)
            selectedAlertType = isUp ? .above : .below
        }) {
            Text("\(isUp ? "+" : "")\(percent)%")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
    
    private func repeatIntervalButton(_ interval: RepeatInterval) -> some View {
        let isSelected = selectedRepeatInterval == interval
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedRepeatInterval = interval
            }
        }) {
            Text(interval == .never ? "仅1次" : interval.shortDescription)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? 
                              (interval == .never ? Color.gray : Color.orange) : 
                              Color(nsColor: .controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
    }
    
    private func adjustPrice(by amount: Double) {
        if let current = Double(targetPriceText) {
            targetPriceText = String(format: "%.2f", current + amount)
        }
    }
    
    private func addAlert() {
        guard let targetPrice = Double(targetPriceText) else { return }
        
        alertManager.addAlert(
            stockCode: stock.code,
            stockName: stock.name,
            alertType: selectedAlertType,
            targetPrice: targetPrice,
            repeatInterval: selectedRepeatInterval
        )
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            showAddAlert = false
            selectedRepeatInterval = .never
        }
    }
}

// MARK: - 提醒行视图

struct AlertRowView: View {
    let alert: PriceAlert
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onReset: () -> Void
    
    private var typeColor: Color {
        alert.alertType == .above ? .red : .green
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            ZStack {
                Circle()
                    .fill(typeColor.opacity(alert.isEnabled ? 0.12 : 0.05))
                    .frame(width: 40, height: 40)
                
                Image(systemName: alert.alertType.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(typeColor.opacity(alert.isEnabled ? 1 : 0.4))
            }
            
            // 信息
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(String(format: "%.2f", alert.targetPrice))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(alert.isEnabled ? .primary : .secondary)
                    
                    // 提醒类型标签
                    Text(alert.isRepeating ? "每\(alert.repeatInterval.shortDescription)" : "仅1次")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(alert.isRepeating ? Color.orange : Color.gray.opacity(0.6))
                        )
                }
                
                // 状态信息
                HStack(spacing: 4) {
                    if alert.triggerCount > 0 {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text("已提醒 \(alert.triggerCount) 次")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        if !alert.isRepeating {
                            Button(action: onReset) {
                                Text("重置")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text("等待触发")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 10) {
                // 开关
                Toggle("", isOn: Binding(
                    get: { alert.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.7)
                .disabled(!alert.isRepeating && alert.hasTriggered)
                
                // 删除按钮 - 始终显示
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .opacity((!alert.isRepeating && alert.hasTriggered) ? 0.6 : 1)
    }
}

#Preview {
    PriceAlertView(
        stock: StockData(
            code: "sh600036",
            name: "招商银行",
            price: 35.50,
            yestclose: 35.00,
            open: 35.20,
            high: 36.00,
            low: 35.00,
            volume: 1000000,
            amount: 35000000,
            time: "15:00:00"
        ),
        onDismiss: {}
    )
}
