//
//  SettingsView.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import SwiftUI

// MARK: - 设置容器视图（用于页面切换）

struct SettingsContainerView: View {
    let onBack: () -> Void
    
    @State private var stockStore = StockStore.shared
    @State private var searchText = ""
    @State private var searchResults: [StockSearchResult] = []
    @State private var isSearching = false
    @State private var selectedTab = 0
    @State private var showDeleteConfirm = false
    @State private var stockToDelete: String?
    @State private var searchTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 顶部标题栏
                headerView
                
                Divider()
                
                // 标签切换
                tabPicker
                
                // 内容区域
                if selectedTab == 0 {
                    myStocksView
                } else {
                    searchView
                }
            }
            .background(Color(nsColor: .windowBackgroundColor))
            
            // 自定义删除确认对话框
            if showDeleteConfirm {
                deleteConfirmOverlay
            }
        }
    }
    
    // MARK: - 删除确认对话框
    
    private var deleteConfirmOverlay: some View {
        ZStack {
            // 半透明背景
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    // 点击背景关闭
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showDeleteConfirm = false
                        stockToDelete = nil
                    }
                }
            
            // 对话框
            VStack(spacing: 16) {
                // 图标
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                
                // 标题
                Text("确认删除")
                    .font(.system(size: 15, weight: .semibold))
                
                // 消息
                Text("确定要从自选中删除这只股票吗？")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                // 按钮
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDeleteConfirm = false
                            stockToDelete = nil
                        }
                    }) {
                        Text("取消")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        if let code = stockToDelete {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                stockStore.removeStock(code: code)
                            }
                        }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showDeleteConfirm = false
                            stockToDelete = nil
                        }
                    }) {
                        Text("删除")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(width: 260)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .transition(.scale(scale: 0.9).combined(with: .opacity))
        }
        .animation(.easeInOut(duration: 0.2), value: showDeleteConfirm)
    }
    
    // MARK: - 顶部标题栏
    
    private var headerView: some View {
        HStack {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                    Text("返回")
                        .font(.system(size: 13))
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text("股票设置")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            // 占位，保持标题居中
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                Text("返回")
                    .font(.system(size: 13))
            }
            .opacity(0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - 标签切换
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "我的自选", icon: "star.fill", index: 0)
            tabButton(title: "搜索添加", icon: "magnifyingglass", index: 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button(action: { 
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = index 
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(selectedTab == index ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedTab == index ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - 我的自选列表
    
    private var myStocksView: some View {
        VStack(spacing: 0) {
            // 股票数量统计
            if !stockStore.stockCodes.isEmpty {
                HStack {
                    Text("共 \(stockStore.stockCodes.count) 只自选")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
            
            if stockStore.stockCodes.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(stockStore.stockCodes, id: \.self) { code in
                        StockItemRow(code: code) {
                            stockToDelete = code
                            showDeleteConfirm = true
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onMove { source, destination in
                        stockStore.moveStock(from: source, to: destination)
                    }
                    .onDelete { indexSet in
                        if let index = indexSet.first {
                            stockToDelete = stockStore.stockCodes[index]
                            showDeleteConfirm = true
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            // 底部提示
            HStack(spacing: 6) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 10))
                Text("拖动调整顺序")
                Spacer()
                Image(systemName: "arrow.left")
                    .font(.system(size: 10))
                Text("左滑删除")
            }
            .font(.system(size: 10))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.slash")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("还没有自选股票")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            Text("点击「搜索添加」来添加股票")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 搜索视图
    
    private var searchView: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar
            
            // 搜索结果
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.quaternary)
                    Text("未找到相关股票")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchText.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(.quaternary)
                    Text("搜索股票")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        searchHintRow(icon: "building.columns", text: "A股：输入代码或名称，如 600036 或 招商", color: .red)
                        searchHintRow(icon: "globe.asia.australia", text: "港股：输入代码或名称，如 00700 或 腾讯", color: .orange)
                        searchHintRow(icon: "globe.americas", text: "美股：输入代码或名称，如 AAPL 或 苹果", color: .blue)
                        searchHintRow(icon: "chart.bar", text: "期货：输入大写代码，如 IF、CU", color: .purple)
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                searchResultsList
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14))
            
            TextField("搜索股票代码或名称...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit {
                    Task {
                        await performSearch()
                    }
                }
            
            if !searchText.isEmpty {
                Button(action: { 
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: searchText) { _, newValue in
            // 取消之前的搜索任务
            searchTask?.cancel()
            
            if newValue.isEmpty {
                searchResults = []
                isSearching = false
            } else if newValue.count >= 2 {
                // 防抖：延迟 300ms 后搜索
                searchTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if !Task.isCancelled {
                        await performSearch()
                    }
                }
            }
        }
    }
    
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { result in
                    SearchResultRow(
                        result: result,
                        isAdded: stockStore.contains(code: result.code)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if stockStore.contains(code: result.code) {
                                stockStore.removeStock(code: result.code)
                            } else {
                                stockStore.addStock(code: result.code)
                            }
                        }
                    }
                    
                    if result.id != searchResults.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 辅助视图
    
    private func searchHintRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - 搜索方法
    
    @MainActor
    private func performSearch() async {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        do {
            let results = try await StockService.shared.searchStock(keyword: searchText)
            searchResults = results
            isSearching = false
        } catch {
            searchResults = []
            isSearching = false
        }
    }
}

// MARK: - 股票项目行

struct StockItemRow: View {
    let code: String
    let onDelete: () -> Void
    
    @State private var stockName: String = ""
    @State private var marketType: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            // 市场标签
            marketBadge
            
            VStack(alignment: .leading, spacing: 2) {
                Text(stockName.isEmpty ? code.uppercased() : stockName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(code.uppercased())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .task {
            await loadStockInfo()
        }
    }
    
    private var marketBadge: some View {
        Text(getMarketLabel())
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(getMarketColor())
            )
    }
    
    private func getMarketLabel() -> String {
        if code.hasPrefix("sh") || code.hasPrefix("sz") || code.hasPrefix("bj") {
            return "A股"
        } else if code.hasPrefix("hk") {
            return "港股"
        } else if code.hasPrefix("usr_") || code.hasPrefix("gb_") {
            return "美股"
        } else if code.hasPrefix("nf_") {
            return "期货"
        } else if code.hasPrefix("hf_") {
            return "外期"
        }
        return "其他"
    }
    
    private func getMarketColor() -> Color {
        if code.hasPrefix("sh") || code.hasPrefix("sz") || code.hasPrefix("bj") {
            return .red
        } else if code.hasPrefix("hk") {
            return .orange
        } else if code.hasPrefix("usr_") || code.hasPrefix("gb_") {
            return .blue
        } else if code.hasPrefix("nf_") {
            return .purple
        } else if code.hasPrefix("hf_") {
            return .indigo
        }
        return .gray
    }
    
    private func loadStockInfo() async {
        do {
            let stocks = try await StockService.shared.getStockData(codes: [code])
            if let stock = stocks.first {
                await MainActor.run {
                    stockName = stock.name
                }
            }
        } catch {
            // 忽略错误
        }
    }
}

// MARK: - 搜索结果行

struct SearchResultRow: View {
    let result: StockSearchResult
    let isAdded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 市场图标
            ZStack {
                Circle()
                    .fill(getMarketColor().opacity(0.15))
                    .frame(width: 36, height: 36)
                
                Text(getMarketLabel())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(getMarketColor())
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(result.code.uppercased())
                    Text("·")
                    Text(result.abbreviation.uppercased())
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button(action: onToggle) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isAdded ? .green : .blue)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
    
    private func getMarketLabel() -> String {
        switch result.market.lowercased() {
        case "sh", "sz", "bj": return "A"
        case "hk": return "港"
        case "us": return "美"
        case "nf": return "期"
        case "hf": return "外"
        default: return "股"
        }
    }
    
    private func getMarketColor() -> Color {
        switch result.market.lowercased() {
        case "sh", "sz", "bj": return .red
        case "hk": return .orange
        case "us": return .blue
        case "nf": return .purple
        case "hf": return .indigo
        default: return .gray
        }
    }
    
    private func getMarketDescription() -> String {
        switch result.market.lowercased() {
        case "sh": return "上海"
        case "sz": return "深圳"
        case "bj": return "北京"
        case "hk": return "港股"
        case "us": return "美股"
        case "nf": return "国内期货"
        case "hf": return "海外期货"
        default: return ""
        }
    }
}

#Preview {
    SettingsContainerView(onBack: {})
}

