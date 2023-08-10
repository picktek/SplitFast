import UIKit
import SwiftUI
import PhotosUI
import BackgroundTasks

struct VideoPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    
    @Binding var isShown: Bool
    @Binding var inputFile: String?
    
    
    init(isShown: Binding<Bool>, inputFile: Binding<String?>) {
        _isShown = isShown
        _inputFile = inputFile
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
        var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
        
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
                guard let targetURL = documentsDirectory?.appendingPathComponent("split_part_main_" + url.lastPathComponent) else {
                    return
                }
                
                do {
                    if FileManager.default.fileExists(atPath: targetURL.path) {
                        try FileManager.default.removeItem(at: targetURL)
                    }
                    
                    try FileManager.default.copyItem(at: url, to: targetURL)
                    
                } catch {
                    print(error.localizedDescription)
                }
                
                self.parent.presentationMode.wrappedValue.dismiss()
                self.parent.inputFile = targetURL.absoluteString
                

                
                
            }
            
        }
        
        
    }
}
