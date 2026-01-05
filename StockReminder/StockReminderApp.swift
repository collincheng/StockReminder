//
//  StockReminderApp.swift
//  StockReminder
//
//  Created by Colin on 2026/1/5.
//

import SwiftUI

@main
struct StockReminderApp: App {
    var body: some Scene {
        MenuBarExtra("Stock Reminder", image: "MenuBarIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
