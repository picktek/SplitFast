import UIKit
import SwiftUI
import PhotosUI
import BackgroundTasks

struct VideoPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var isShown: Bool
    @Binding var partDuration: Float64
    @Binding var parts: Double
    @Binding var totalParts: Double
    
    init(isShown: Binding<Bool>, partDuration: Binding<Float64>, parts: Binding<Double>, totalParts: Binding<Double>) {
        _isShown = isShown
        _partDuration = partDuration
        
        _parts = parts
        _totalParts = totalParts
    }
    
    func close() {
        self.presentationMode.wrappedValue.dismiss()
        isShown = false
        
    }
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let controller = PHPickerViewController(configuration: config)
        controller.delegate = context.coordinator
        
        return controller
    }
    
    func updateUIViewController(_: PHPickerViewController, context _: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let video = results.first else {
                self.parent.close()
                
                return
            }
            
            video.itemProvider.loadFileRepresentation(forTypeIdentifier: video.itemProvider.registeredTypeIdentifiers.first!) { url, error in
                if let error = error {
                    self.parent.presentationMode.wrappedValue.dismiss()
                    
                    print(error.localizedDescription)
                }
                
                guard let url = url else {
                    self.parent.presentationMode.wrappedValue.dismiss()
                    
                    return
                }
                
                let documentsDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                guard let targetURL = documentsDirectory?.appendingPathComponent(url.lastPathComponent) else {
                    return
                }
                
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    
                    try FileManager.default.copyItem(at: url, to: targetURL)
                    
                    DispatchQueue.main.async {
                        self.parent.presentationMode.wrappedValue.dismiss()
                        
                        print(url, targetURL)
                    }
                    let activity = ProcessInfo.processInfo.beginActivity(options:.background, reason: "To Split video")
                    
                    _ = Task {
                        
                        await handleVideo(url: targetURL, partDuration: self.parent.partDuration, completion: {
                            self.parent.parts = $0
                            self.parent.totalParts = $1
                        })
                        try! FileManager.default.removeItem(at: targetURL)
                        
                        if (UIApplication.shared.applicationState != .active) {
                            let content = UNMutableNotificationContent()
                            content.title = "Spliting Video Completed"
                            content.body = "Total Parts: \(self.parent.totalParts)"
                            
                            let uuidString = UUID().uuidString
                            let request = UNNotificationRequest(identifier: uuidString,
                                                                content: content, trigger: nil)
                            
                            
                            // Schedule the request with the system.
                            let notificationCenter = UNUserNotificationCenter.current()
                            try await notificationCenter.add(request)
                        }
                        ProcessInfo.processInfo.endActivity(activity)
                    }
                    
                    
                } catch {
                    print(error.localizedDescription)
                }
                
                
            }
            
        }
        
        
    }
}
