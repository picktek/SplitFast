//
//  Video.swift
//  SplitFast
//
//  Created by l on 09.08.23.
//

import Foundation
import AVKit
import Dispatch
import Photos
import AVFoundation

let splitFastAppGroup = "group.splitfast.storage"
let splitFastAlbumName = "SplitFast"
let splitFastShareInlineLimit: Double = 180

enum SplitSourceAccess: String, Codable, CaseIterable {
    case photoKit
    case inPlace
    case copiedFallback

    var label: String {
        switch self {
        case .photoKit:
            return "Photos no-copy"
        case .inPlace:
            return "In-place"
        case .copiedFallback:
            return "Copied fallback"
        }
    }
}

struct SplitSource: Identifiable, Codable, Equatable {
    var id = UUID()
    var url: URL
    var name: String
    var access: SplitSourceAccess
    var deleteAfterUse: Bool
}

enum SplitJobStatus: String, Codable {
    case completed
    case failed
    case canceled
    case noSplitNeeded

    var title: String {
        switch self {
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .canceled:
            return "Canceled"
        case .noSplitNeeded:
            return "No split needed"
        }
    }
}

enum SplitJobPhase: String, Codable {
    case preparing
    case exporting
    case saving
}

struct SplitJobProgress: Equatable {
    var completedClips: Int
    var totalClips: Int
    var currentClipFraction: Double
    var phase: SplitJobPhase

    var fraction: Double {
        guard totalClips > 0 else { return 0 }
        return min(1, (Double(completedClips) + currentClipFraction) / Double(totalClips))
    }

    var label: String {
        switch phase {
        case .preparing:
            return "Preparing"
        case .exporting:
            return "Exporting \(min(completedClips + 1, totalClips)) of \(totalClips)"
        case .saving:
            return "Saving \(totalClips) Output Clips"
        }
    }
}

struct SplitJobHistoryEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var status: SplitJobStatus
    var startedAt: Date
    var endedAt: Date
    var sourceName: String
    var clipLength: Double
    var clipCount: Int
    var outputAssetIdentifiers: [String]
    var sourceAccess: SplitSourceAccess
    var message: String
}

struct SplitJobResult {
    var status: SplitJobStatus
    var startedAt: Date
    var endedAt: Date
    var sourceName: String
    var clipLength: Double
    var clipCount: Int
    var outputAssetIdentifiers: [String]
    var sourceAccess: SplitSourceAccess
    var message: String

    var historyEntry: SplitJobHistoryEntry {
        SplitJobHistoryEntry(
            id: UUID(),
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            sourceName: sourceName,
            clipLength: clipLength,
            clipCount: clipCount,
            outputAssetIdentifiers: outputAssetIdentifiers,
            sourceAccess: sourceAccess,
            message: message
        )
    }
}

enum SplitJobHistoryStore {
    private static let key = "splitJobHistory"

    static func load() -> [SplitJobHistoryEntry] {
        guard let data = defaults.data(forKey: key),
              let entries = try? JSONDecoder().decode([SplitJobHistoryEntry].self, from: data)
        else {
            return []
        }

        return entries.sorted { $0.startedAt > $1.startedAt }
    }

    static func append(_ entry: SplitJobHistoryEntry) {
        var entries = load()
        entries.insert(entry, at: 0)
        save(entries)
    }

    static func delete(id: UUID) {
        save(load().filter { $0.id != id })
    }

    static func clear() {
        defaults.removeObject(forKey: key)
    }

    private static func save(_ entries: [SplitJobHistoryEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: key)
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: splitFastAppGroup) ?? .standard
    }
}

func generateThumbnail(path: URL) -> UIImage? {
    do {
        let asset = AVURLAsset(url: path, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        imgGenerator.appliesPreferredTrackTransform = true
        let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
        return UIImage(cgImage: cgImage)
    } catch {
        print("*** Error generating thumbnail: \(error.localizedDescription)")
        return nil
    }
}

func loadVideoDuration(url: URL) async throws -> Double {
    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    let seconds = CMTimeGetSeconds(duration)

    guard seconds.isFinite, seconds > 0 else {
        throw splitFastError("Could not read Source Video duration.")
    }

    return seconds
}

func handleVideo(
    url: URL,
    sourceName: String? = nil,
    sourceAccess: SplitSourceAccess = .inPlace,
    deleteSourceAfterUse: Bool = false,
    partDuration: Float64 = 30.0,
    shouldCancel: @escaping @MainActor () -> Bool = { false },
    onProgress: @escaping @MainActor (SplitJobProgress) -> Void = { _ in }
) async -> SplitJobResult {
    let startedAt = Date()
    let name = sourceName?.isEmpty == false ? sourceName! : url.lastPathComponent

    defer {
        removeSplitTempFiles()
        if deleteSourceAfterUse {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func finish(
        _ status: SplitJobStatus,
        clipCount: Int = 0,
        outputAssetIdentifiers: [String] = [],
        message: String
    ) -> SplitJobResult {
        let result = SplitJobResult(
            status: status,
            startedAt: startedAt,
            endedAt: Date(),
            sourceName: name,
            clipLength: partDuration,
            clipCount: clipCount,
            outputAssetIdentifiers: outputAssetIdentifiers,
            sourceAccess: sourceAccess,
            message: message
        )
        SplitJobHistoryStore.append(result.historyEntry)
        return result
    }

    do {
        guard partDuration > 0 else {
            throw splitFastError("Clip Length must be greater than zero.")
        }

        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw splitFastError("Could not read Source Video duration.")
        }

        if durationSeconds <= partDuration {
            return finish(.noSplitNeeded, message: "Source Video is already shorter than the selected Clip Length.")
        }

        let timescale = max(duration.timescale, CMTimeScale(600))
        let ranges = splitRanges(durationSeconds: durationSeconds, clipLength: partDuration, timescale: timescale)

        await onProgress(SplitJobProgress(completedClips: 0, totalClips: ranges.count, currentClipFraction: 0, phase: .preparing))

        var outputURLs: [URL] = []
        for (index, range) in ranges.enumerated() {
            if await shouldCancel() {
                return finish(.canceled, message: "Split Job was canceled.")
            }

            let outputURL = try await export(
                asset,
                timeRange: range,
                shouldCancel: shouldCancel,
                progress: { fraction in
                    onProgress(SplitJobProgress(
                        completedClips: index,
                        totalClips: ranges.count,
                        currentClipFraction: min(max(fraction, 0), 1),
                        phase: .exporting
                    ))
                }
            )
            outputURLs.append(outputURL)

            await onProgress(SplitJobProgress(completedClips: index + 1, totalClips: ranges.count, currentClipFraction: 0, phase: .exporting))
        }

        if await shouldCancel() {
            return finish(.canceled, message: "Split Job was canceled.")
        }

        await onProgress(SplitJobProgress(completedClips: ranges.count, totalClips: ranges.count, currentClipFraction: 0, phase: .saving))
        let assetIdentifiers = try await saveVideosToAlbum(videoURLs: outputURLs, albumName: splitFastAlbumName)
        return finish(
            .completed,
            clipCount: outputURLs.count,
            outputAssetIdentifiers: assetIdentifiers,
            message: "Saved \(outputURLs.count) Output Clips to \(splitFastAlbumName)."
        )
    } catch is CancellationError {
        return finish(.canceled, message: "Split Job was canceled.")
    } catch {
        return finish(.failed, message: error.localizedDescription)
    }
}

func export(
    _ asset: AVAsset,
    timeRange: CMTimeRange,
    shouldCancel: @escaping @MainActor () -> Bool,
    progress: @escaping @MainActor (Double) async -> Void
) async throws -> URL {
    guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
        throw splitFastError("Could not open temporary storage.")
    }

    let outputMovieURL = cacheDir.appendingPathComponent("split_part_\(UUID().uuidString).mov")
    try? FileManager.default.removeItem(at: outputMovieURL)

    guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
        throw splitFastError("Could not create video exporter.")
    }

    exporter.outputURL = outputMovieURL
    exporter.outputFileType = .mov
    exporter.timeRange = timeRange

    let progressTask = Task {
        while !Task.isCancelled {
            if await shouldCancel() {
                exporter.cancelExport()
                return
            }

            await progress(Double(exporter.progress))

            if exporter.status != .waiting && exporter.status != .exporting {
                return
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    await exporter.export()
    progressTask.cancel()
    await progress(1)

    switch exporter.status {
    case .completed:
        return outputMovieURL
    case .cancelled:
        throw CancellationError()
    case .failed:
        throw exporter.error ?? splitFastError("Export failed.")
    default:
        if let error = exporter.error {
            throw error
        }
        return outputMovieURL
    }
}

func saveVideosToAlbum(videoURLs: [URL], albumName: String) async throws -> [String] {
    guard !videoURLs.isEmpty else { return [] }

    try await ensurePhotoLibraryAccess()
    let album = try await fetchOrCreateAlbum(named: albumName)

    var identifiers: [String] = []
    var changeFailure: Error?
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        PHPhotoLibrary.shared().performChanges({
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
                changeFailure = splitFastError("Could not open \(albumName) album for saving.")
                return
            }
            var placeholders: [PHObjectPlaceholder] = []

            for videoURL in videoURLs {
                guard let assetRequest = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL),
                      let placeholder = assetRequest.placeholderForCreatedAsset
                else {
                    continue
                }
                placeholders.append(placeholder)
            }

            identifiers = placeholders.map(\.localIdentifier)
            albumChangeRequest.addAssets(placeholders as NSArray)
        }, completionHandler: { success, error in
            if let changeFailure {
                continuation.resume(throwing: changeFailure)
            } else if success {
                continuation.resume()
            } else {
                continuation.resume(throwing: error ?? splitFastError("Could not save Output Clips."))
            }
        })
    }

    return identifiers
}

func sourceFromPhotoLibrary(assetIdentifier: String, suggestedName: String?) async -> SplitSource? {
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
    guard let asset = assets.firstObject else { return nil }

    let options = PHVideoRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isNetworkAccessAllowed = true

    return await withCheckedContinuation { continuation in
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, _ in
            guard let urlAsset = avAsset as? AVURLAsset else {
                continuation.resume(returning: nil)
                return
            }

            continuation.resume(returning: SplitSource(
                url: urlAsset.url,
                name: suggestedName?.isEmpty == false ? suggestedName! : "Photos video",
                access: .photoKit,
                deleteAfterUse: false
            ))
        }
    }
}

func inPlaceSourceFromItemProvider(_ provider: NSItemProvider, typeIdentifier: String, suggestedName: String?) async -> SplitSource? {
    await withCheckedContinuation { continuation in
        provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { url, isInPlace, error in
            guard error == nil, isInPlace, let url else {
                continuation.resume(returning: nil)
                return
            }

            continuation.resume(returning: SplitSource(
                url: url,
                name: suggestedName?.isEmpty == false ? suggestedName! : url.lastPathComponent,
                access: .inPlace,
                deleteAfterUse: false
            ))
        }
    }
}

func copiedSourceFromItemProvider(_ provider: NSItemProvider, typeIdentifier: String, suggestedName: String?, useAppGroup: Bool) async -> SplitSource? {
    await withCheckedContinuation { continuation in
        provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
            guard error == nil, let url else {
                continuation.resume(returning: nil)
                return
            }

            do {
                let source = try copySourceVideo(url: url, name: suggestedName, useAppGroup: useAppGroup)
                continuation.resume(returning: source)
            } catch {
                print("Could not copy Source Video: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
}

func copySourceVideo(url: URL, name: String?, useAppGroup: Bool) throws -> SplitSource {
    let directory = try sourceStorageDirectory(useAppGroup: useAppGroup)
    let pickedName = name?.isEmpty == false ? name! : url.lastPathComponent
    let fileName = pickedName.isEmpty ? "video.mov" : pickedName
    let targetURL = directory.appendingPathComponent("split_source_\(UUID().uuidString)_\(fileName)")

    try? FileManager.default.removeItem(at: targetURL)
    try FileManager.default.copyItem(at: url, to: targetURL)

    return SplitSource(url: targetURL, name: fileName, access: .copiedFallback, deleteAfterUse: true)
}

func withCoordinatedRead<T>(url: URL, operation: @escaping (URL) async throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            var operationResult: Result<T, Error>?

            coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
                // ponytail: one worker thread stays blocked so in-place provider access remains valid for the async split.
                let semaphore = DispatchSemaphore(value: 0)
                Task {
                    do {
                        operationResult = .success(try await operation(coordinatedURL))
                    } catch {
                        operationResult = .failure(error)
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }

            if let coordinationError {
                continuation.resume(throwing: coordinationError)
            } else if let operationResult {
                continuation.resume(with: operationResult)
            } else {
                continuation.resume(throwing: splitFastError("Could not coordinate Source Video access."))
            }
        }
    }
}

func splitFastHandoffURL(for source: SplitSource) -> URL? {
    var components = URLComponents()
    components.scheme = "splitfast"
    components.host = "split"
    components.queryItems = [
        URLQueryItem(name: "url", value: source.url.absoluteString),
        URLQueryItem(name: "name", value: source.name),
        URLQueryItem(name: "access", value: source.access.rawValue),
        URLQueryItem(name: "delete", value: source.deleteAfterUse ? "1" : "0")
    ]
    return components.url
}

func splitSource(fromHandoffURL url: URL) -> SplitSource? {
    guard url.scheme == "splitfast", url.host == "split",
          let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    else {
        return nil
    }

    let items = components.queryItems ?? []
    guard let rawURL = items.first(where: { $0.name == "url" })?.value,
          let sourceURL = URL(string: rawURL)
    else {
        return nil
    }

    let name = items.first(where: { $0.name == "name" })?.value
    let access = items.first(where: { $0.name == "access" })?.value.flatMap(SplitSourceAccess.init(rawValue:)) ?? .copiedFallback
    let shouldDelete = items.first(where: { $0.name == "delete" })?.value == "1"

    return SplitSource(
        url: sourceURL,
        name: name?.isEmpty == false ? name! : sourceURL.lastPathComponent,
        access: access,
        deleteAfterUse: shouldDelete
    )
}

func removeCacheDir() {
    removeSplitTempFiles()
}

func removeSplitTempFiles() {
    guard let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }

    do {
        let fileURLs = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)
        for fileURL in fileURLs where fileURL.lastPathComponent.hasPrefix("split_part_") {
            try? FileManager.default.removeItem(at: fileURL)
        }
    } catch {
        print("Could not clear temp folder: \(error)")
    }
}

private func splitRanges(durationSeconds: Double, clipLength: Double, timescale: CMTimeScale) -> [CMTimeRange] {
    var ranges: [CMTimeRange] = []
    var start = 0.0

    while start < durationSeconds {
        let end = min(start + clipLength, durationSeconds)
        ranges.append(CMTimeRangeFromTimeToTime(
            start: CMTime(seconds: start, preferredTimescale: timescale),
            end: CMTime(seconds: end, preferredTimescale: timescale)
        ))
        start = end
    }

    return ranges
}

private func ensurePhotoLibraryAccess() async throws {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    if status == .notDetermined {
        let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard newStatus == .authorized || newStatus == .limited else {
            throw splitFastError("Photo Library access was denied.")
        }
        return
    }

    guard status == .authorized || status == .limited else {
        throw splitFastError("Photo Library access was denied.")
    }
}

private func fetchOrCreateAlbum(named albumName: String) async throws -> PHAssetCollection {
    let fetchOptions = PHFetchOptions()
    fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
    let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

    if let album = collection.firstObject {
        return album
    }

    var placeholder: PHObjectPlaceholder?
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
            placeholder = request.placeholderForCreatedAssetCollection
        }, completionHandler: { success, error in
            if success {
                continuation.resume()
            } else {
                continuation.resume(throwing: error ?? splitFastError("Could not create \(albumName) album."))
            }
        })
    }

    guard let placeholder else {
        throw splitFastError("Could not create \(albumName) album.")
    }

    let created = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
    guard let album = created.firstObject else {
        throw splitFastError("Could not open \(albumName) album.")
    }

    return album
}

private func sourceStorageDirectory(useAppGroup: Bool) throws -> URL {
    let directory: URL
    if useAppGroup, let appGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: splitFastAppGroup) {
        directory = appGroup
    } else if let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
        directory = cache
    } else {
        throw splitFastError("Could not open temporary storage.")
    }

    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

func splitFastError(_ message: String) -> NSError {
    NSError(domain: "SplitFast", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}
