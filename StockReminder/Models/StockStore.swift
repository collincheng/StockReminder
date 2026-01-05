//
//  StockStore.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation
import SwiftUI

/// 股票存储管理器
@Observable
class StockStore {
    static let shared = StockStore()
    
    /// 保存的股票代码列表
    var stockCodes: [String] {
        didSet {
            saveToUserDefaults()
        }
    }
    
    private let userDefaultsKey = "savedStockCodes"
    
    private init() {
        // 从 UserDefaults 加载
        if let saved = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String], !saved.isEmpty {
            self.stockCodes = saved
        } else {
            // 默认股票
            self.stockCodes = [
                "sh000001",  // 上证指数
                "sz399001",  // 深证成指
                "sh600036",  // 招商银行
                "usr_aapl",  // 苹果
            ]
        }
    }
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(stockCodes, forKey: userDefaultsKey)
    }
    
    /// 添加股票
    func addStock(code: String) {
        let normalizedCode = code.lowercased()
        if !stockCodes.contains(normalizedCode) {
            stockCodes.append(normalizedCode)
        }
    }
    
    /// 删除股票
    func removeStock(code: String) {
        stockCodes.removeAll { $0.lowercased() == code.lowercased() }
    }
    
    /// 移动股票顺序
    func moveStock(from source: IndexSet, to destination: Int) {
        stockCodes.move(fromOffsets: source, toOffset: destination)
    }
    
    /// 检查股票是否已添加
    func contains(code: String) -> Bool {
        stockCodes.contains { $0.lowercased() == code.lowercased() }
    }
}

