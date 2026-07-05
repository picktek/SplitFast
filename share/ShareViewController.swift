//
//  ShareViewController.swift
//  share
//
//  Created by l on 11.08.23.
//

import UIKit
import Social

class ShareViewController: UIViewController {
    func isContentValid() -> Bool {
        firstMovieProvider() != nil
    }

    func configurationItems() -> [Any]! {
        []
    }

    func getDuration() -> Double {
        SplitSettings.clipLength
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedVideo()
    }

    private func processSharedVideo() {
        guard let provider = firstMovieProvider(),
              let typeIdentifier = splitFastVideoTypeIdentifier(for: provider)
        else {
            complete()
            return
        }

        Task {
            if let source = await inPlaceSourceFromItemProvider(
                provider,
                typeIdentifier: typeIdentifier,
                suggestedName: provider.suggestedName
            ), let duration = try? await source.duration(), duration <= splitFastShareInlineLimit {
                _ = try? await source.read { readableURL in
                    await handleVideo(
                        url: readableURL,
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
                typeIdentifier: typeIdentifier,
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
            splitFastVideoTypeIdentifier(for: provider) != nil
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
