//
//  ContentView.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import SwiftUI

struct ContentView: View {
    @State private var stocks: [StockData] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // 示例股票代码
    private let demoCodes = [
        "sh000001",  // 上证指数
        "sz399001",  // 深证成指
        "sh600036",  // 招商银行
        "usr_aapl",  // 苹果
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
                Text("Stock Reminder")
                    .font(.headline)
                Spacer()
                Button(action: refreshData) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // 股票列表
            if isLoading && stocks.isEmpty {
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        refreshData()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if stocks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.title)
                        .foregroundStyle(.secondary)
                    Text("暂无股票数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(stocks) { stock in
                            StockRowView(stock: stock)
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
            
            Divider()
            
            // 底部操作栏
            HStack {
                Text("更新时间: \(stocks.first?.time ?? "--")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 320, height: 400)
        .task {
            await loadStockData()
        }
    }
    
    private func refreshData() {
        Task {
            await loadStockData()
        }
    }
    
    private func loadStockData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let data = try await StockService.shared.getStockData(codes: demoCodes)
            await MainActor.run {
                stocks = data
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - 股票行视图

struct StockRowView: View {
    let stock: StockData
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(stock.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(stock.code.uppercased())
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.2f", stock.price))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(stock.isUp ? .red : .green)
                
                HStack(spacing: 4) {
                    Text(String(format: "%@%.2f", stock.updown >= 0 ? "+" : "", stock.updown))
                        .font(.system(size: 10, design: .monospaced))
                    Text(stock.percentText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(stock.isUp ? .red : .green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

#Preview {
    ContentView()
}
