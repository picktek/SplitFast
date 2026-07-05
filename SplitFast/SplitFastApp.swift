//
//  SplitFastApp.swift
//  SplitFast
//
//  Created by l on 09.08.23.
//

import SwiftUI
import BackgroundTasks

final class BackgroundSplitCoordinator {
    static let shared = BackgroundSplitCoordinator()

    private let identifierPrefix = "com.picktek.SplitFast.processing"
    private var task: BGTask?
    private var registered = false
    var onExpiration: (() -> Void)?

    func register() {
        guard !registered else { return }

        if #available(iOS 26.0, *) {
            registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: "\(identifierPrefix).*", using: nil) { [weak self] task in
                self?.task = task
                task.expirationHandler = {
                    DispatchQueue.main.async {
                        self?.onExpiration?()
                        self?.finish(success: false)
                    }
                }

                if let continuedTask = task as? BGContinuedProcessingTask {
                    continuedTask.progress.totalUnitCount = 1000
                }
            }
        }
    }

    @available(iOS 26.0, *)
    func submit(sourceName: String) -> String? {
        let request = BGContinuedProcessingTaskRequest(
            identifier: "\(identifierPrefix).\(UUID().uuidString)",
            title: "Splitting video",
            subtitle: sourceName
        )
        request.strategy = .queue

        do {
            try BGTaskScheduler.shared.submit(request)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func update(fraction: Double) {
        if #available(iOS 26.0, *), let continuedTask = task as? BGContinuedProcessingTask {
            let clamped = max(0, min(1, fraction))
            continuedTask.progress.totalUnitCount = 1000
            continuedTask.progress.completedUnitCount = Int64(clamped * 1000)
            continuedTask.updateTitle("Splitting video", subtitle: "\(Int(clamped * 100))% complete")
        }
    }

    func finish(success: Bool) {
        task?.setTaskCompleted(success: success)
        task = nil
        onExpiration = nil
    }
}

@main
struct SplitFastApp: App {
    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UITEST_RESET_STATE") {
            // ponytail: reset only what UI tests persist; add fuller fixtures if media E2E needs them.
            SplitSettings.clipLength = 30
            SplitJobHistoryStore.clear()
        }
#endif

        BackgroundSplitCoordinator.shared.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
