//
//  ShareViewController.swift
//  share
//
//  Created by l on 11.08.23.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    func isContentValid() -> Bool {
        firstMovieProvider() != nil
    }

    func configurationItems() -> [Any]! {
        []
    }

    func getDuration() -> Double {
        guard let userDefaults = UserDefaults(suiteName: splitFastAppGroup) else {
            return 30
        }

        let stored = userDefaults.double(forKey: "partDuration")
        return stored == 0 ? 30 : stored
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedVideo()
    }

    private func processSharedVideo() {
        guard let provider = firstMovieProvider() else {
            complete()
            return
        }

        Task {
            if let source = await inPlaceSourceFromItemProvider(
                provider,
                typeIdentifier: UTType.movie.identifier,
                suggestedName: provider.suggestedName
            ), let duration = try? await withCoordinatedRead(url: source.url, operation: { coordinatedURL in
                try await loadVideoDuration(url: coordinatedURL)
            }), duration <= splitFastShareInlineLimit {
                _ = try? await withCoordinatedRead(url: source.url) { coordinatedURL in
                    await handleVideo(
                        url: coordinatedURL,
                        sourceName: source.name,
                        sourceAccess: .inPlace,
                        partDuration: self.getDuration()
                    )
                }
                await MainActor.run {
                    self.complete()
                }
                return
            }

            if let copiedSource = await copiedSourceFromItemProvider(
                provider,
                typeIdentifier: UTType.movie.identifier,
                suggestedName: provider.suggestedName,
                useAppGroup: true
            ), let handoffURL = splitFastHandoffURL(for: copiedSource) {
                await openMainApp(url: handoffURL)
            }

            await MainActor.run {
                self.complete()
            }
        }
    }

    private func firstMovieProvider() -> NSItemProvider? {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = item.attachments
        else {
            return nil
        }

        return attachments.first { provider in
            provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier)
                || provider.hasItemConformingToTypeIdentifier(UTType.video.identifier)
        }
    }

    @MainActor
    private func openMainApp(url: URL) async {
        await withCheckedContinuation { continuation in
            extensionContext?.open(url) { _ in
                continuation.resume()
            }
        }
    }

    private func complete() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

}
