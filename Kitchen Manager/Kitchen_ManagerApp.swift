//
//  Kitchen_ManagerApp.swift
//  Kitchen Manager
//
//  Created by x j zou on 3/21/26.
//

import SwiftUI

@main
struct Kitchen_ManagerApp: App {
    @State private var store = KitchenStore()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
