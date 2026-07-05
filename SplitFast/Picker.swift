import UIKit
import SwiftUI
import PhotosUI

struct VideoPicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode

    @Binding var isShown: Bool
    @Binding var selectedSource: SplitSource?

    init(isShown: Binding<Bool>, selectedSource: Binding<SplitSource?>) {
        _isShown = isShown
        _selectedSource = selectedSource
    }

    func close() {
        presentationMode.wrappedValue.dismiss()
        isShown = false
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
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
            guard let result = results.first else {
                parent.close()
                return
            }

            Task {
                let provider = result.itemProvider
                var source: SplitSource?

                if let assetIdentifier = result.assetIdentifier {
                    source = await sourceFromPhotoLibrary(
                        assetIdentifier: assetIdentifier,
                        suggestedName: provider.suggestedName
                    )
                }

                if source == nil, let typeIdentifier = splitFastVideoTypeIdentifier(for: provider) {
                    source = await inPlaceSourceFromItemProvider(
                        provider,
                        typeIdentifier: typeIdentifier,
                        suggestedName: provider.suggestedName
                    )
                }

                if source == nil, let typeIdentifier = splitFastVideoTypeIdentifier(for: provider) {
                    source = await copiedSourceFromItemProvider(
                        provider,
                        typeIdentifier: typeIdentifier,
                        suggestedName: provider.suggestedName,
                        useAppGroup: false
                    )
                }

                await MainActor.run {
                    self.parent.selectedSource = source
                    self.parent.close()
                }
            }
        }
    }
}
