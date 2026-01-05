//
//  AppInfo.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import Foundation

/// 应用信息
struct AppInfo {
    /// 应用版本号 (如 1.0.0)
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// 构建版本号 (如 1)
    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// 完整版本描述 (如 1.0.0 (1))
    static var fullVersion: String {
        "\(version) (\(build))"
    }
    
    /// 应用名称
    static var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "StockReminder"
    }
    
    /// 应用标识符
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.unknown.stockreminder"
    }
}

