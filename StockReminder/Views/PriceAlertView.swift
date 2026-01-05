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
    
    private var stockAlerts: [PriceAlert] {
        alertManager.getAlerts(forStock: stock.code)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerView
            
            Divider()
            
            // 当前价格信息
            currentPriceView
            
            Divider()
            
            // 提醒列表或添加提醒
            if showAddAlert {
                addAlertView
            } else {
                alertListView
            }
        }
        .frame(width: 300, height: 380)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            targetPriceText = String(format: "%.2f", stock.price)
        }
    }
    
    // MARK: - 标题栏
    
    private var headerView: some View {
        HStack {
            Button(action: {
                if showAddAlert {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAddAlert = false
                    }
                } else {
                    onDismiss()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text(showAddAlert ? "返回" : "关闭")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("价格提醒")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            if !showAddAlert {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAddAlert = true
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .opacity(0)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - 当前价格信息
    
    private var currentPriceView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(stock.name)
                    .font(.system(size: 14, weight: .medium))
                Text(stock.code.uppercased())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f", stock.price))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(stock.isUp ? .red : .green)
                
                Text(stock.percentText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(stock.isUp ? .red : .green)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - 提醒列表
    
    private var alertListView: some View {
        VStack(spacing: 0) {
            if stockAlerts.isEmpty {
                emptyAlertView
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(stockAlerts) { alert in
                            AlertRowView(alert: alert) {
                                alertManager.toggleAlert(id: alert.id)
                            } onDelete: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    alertManager.removeAlert(id: alert.id)
                                }
                            } onReset: {
                                alertManager.resetAlert(id: alert.id)
                            }
                            
                            if alert.id != stockAlerts.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var emptyAlertView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text("暂无价格提醒")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("点击右上角 + 添加提醒")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 添加提醒视图
    
    private var addAlertView: some View {
        VStack(spacing: 20) {
            // 提醒类型选择
            VStack(alignment: .leading, spacing: 10) {
                Text("提醒类型")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(AlertType.allCases, id: \.self) { type in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedAlertType = type
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 14))
                                Text("价格\(type.description)")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(selectedAlertType == type ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedAlertType == type ? 
                                          (type == .above ? Color.red : Color.green) : 
                                          Color(nsColor: .controlBackgroundColor))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // 目标价格输入
            VStack(alignment: .leading, spacing: 10) {
                Text("目标价格")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                
                HStack {
                    TextField("输入价格", text: $targetPriceText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                    
                    // 快捷按钮
                    VStack(spacing: 4) {
                        Button(action: { adjustPrice(by: 0.01) }) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.plain)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                        
                        Button(action: { adjustPrice(by: -0.01) }) {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 24, height: 20)
                        }
                        .buttonStyle(.plain)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                    }
                }
                
                // 快捷价格按钮
                HStack(spacing: 8) {
                    quickPriceButton(percent: -5)
                    quickPriceButton(percent: -3)
                    quickPriceButton(percent: 3)
                    quickPriceButton(percent: 5)
                    quickPriceButton(percent: 10)
                }
            }
            
            // 重复提醒选项
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("重复提醒")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if selectedRepeatInterval != .never {
                        Text("持续提醒直到关闭")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                
                // 重复间隔选择
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(RepeatInterval.allCases, id: \.self) { interval in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedRepeatInterval = interval
                                }
                            }) {
                                Text(interval.shortDescription)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(selectedRepeatInterval == interval ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(selectedRepeatInterval == interval ? 
                                                  Color.accentColor : 
                                                  Color(nsColor: .controlBackgroundColor))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            Spacer()
            
            // 添加按钮
            Button(action: addAlert) {
                HStack {
                    Image(systemName: "bell.badge.fill")
                    Text("添加提醒")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor)
                )
            }
            .buttonStyle(.plain)
            .disabled(Double(targetPriceText) == nil)
        }
        .padding(16)
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }
    
    private func quickPriceButton(percent: Int) -> some View {
        Button(action: {
            let newPrice = stock.price * (1 + Double(percent) / 100)
            targetPriceText = String(format: "%.2f", newPrice)
            selectedAlertType = percent > 0 ? .above : .below
        }) {
            Text("\(percent > 0 ? "+" : "")\(percent)%")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(percent > 0 ? .red : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .controlBackgroundColor))
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
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showAddAlert = false
            // 重置状态
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
    
    var body: some View {
        HStack(spacing: 12) {
            // 类型图标
            Image(systemName: alert.alertType.icon)
                .font(.system(size: 20))
                .foregroundStyle(alert.alertType == .above ? .red : .green)
                .opacity(alert.isEnabled ? 1 : 0.4)
            
            // 信息
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text("价格\(alert.alertType.description)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", alert.targetPrice))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    
                    // 重复提醒标签
                    if alert.isRepeating {
                        Text(alert.repeatInterval.shortDescription)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange)
                            )
                    }
                }
                
                // 状态信息
                HStack(spacing: 4) {
                    if alert.triggerCount > 0 {
                        Image(systemName: alert.isRepeating ? "bell.badge.fill" : "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(alert.isRepeating ? .orange : .green)
                        Text(alert.isRepeating ? "已提醒\(alert.triggerCount)次" : "已触发")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        
                        if !alert.isRepeating {
                            Button(action: onReset) {
                                Text("重置")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if alert.isRepeating {
                        Image(systemName: "repeat")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text("重复提醒")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            Spacer()
            
            // 开关和删除
            HStack(spacing: 8) {
                Toggle("", isOn: Binding(
                    get: { alert.isEnabled },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .scaleEffect(0.7)
                // 重复提醒始终可以切换，非重复提醒触发后禁用
                .disabled(!alert.isRepeating && alert.hasTriggered)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // 重复提醒不降低透明度
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

