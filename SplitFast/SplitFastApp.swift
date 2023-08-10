//
//  SplitFastApp.swift
//  SplitFast
//
//  Created by l on 09.08.23.
//

import SwiftUI
import BackgroundTasks

@main
struct SplitFastApp: App {
    
    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { success, error in
                           if success {
                               print("All set!")
                               
                           } else if let error = error {
                               print(error.localizedDescription)
                           }
                       }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
