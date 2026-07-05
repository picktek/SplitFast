//
//  ContentView.swift
//  SplitFast
//
//  Created by l on 09.08.23.
//

import SwiftUI
import UserNotifications
import UIKit

struct ContentView: View {
    @State private var showImagePicker = false
    @State private var showHistory = false
    @State private var partDuration = 30.0
    @State private var selectedSource: SplitSource?
    @State private var pickerError: String?
    @State private var preparingSource = false
    @State private var thumbnail: UIImage?
    @State private var progress: SplitJobProgress?
    @State private var result: SplitJobResult?
    @State private var backgroundMessage: String?
    @State private var cancelRequested = false
    @State private var processing = false
    @State private var history = SplitJobHistoryStore.load()

    private let presets = [15.0, 30.0, 60.0, 90.0, 180.0]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                content
                    .padding()
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("SplitFast")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        history = SplitJobHistoryStore.load()
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                    .accessibilityLabel("Job History")
                    .accessibilityIdentifier("jobHistoryButton")
                }
            }
            .sheet(isPresented: $showImagePicker) {
                VideoPicker(
                    isShown: $showImagePicker,
                    selectedSource: $selectedSource,
                    errorMessage: $pickerError,
                    isPreparingSource: $preparingSource
                )
            }
            .sheet(isPresented: $showHistory) {
                historySheet
            }
            .onAppear {
                partDuration = SplitSettings.clipLength
#if DEBUG
                loadUITestHandoffIfNeeded()
#endif
            }
            .onChange(of: selectedSource?.id) { _ in
                let source = selectedSource
                thumbnail = nil
                result = nil
                backgroundMessage = nil

                guard let source else { return }
                pickerError = nil
                preparingSource = false
                Task {
                    let image = await source.thumbnail()
                    await MainActor.run {
                        if selectedSource?.id == source.id {
                            thumbnail = image
                        }
                    }
                }
            }
            .onOpenURL { url in
                guard let source = splitSource(fromHandoffURL: url) else { return }
                selectedSource = source
            }
        }
    }

    private var content: some View {
        VStack(spacing: 16) {
            videoPanel
            clipLengthPanel
            actionPanel
            statusPanel
        }
    }

    private var videoPanel: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black)
                        .aspectRatio(16 / 9, contentMode: .fit)

                    if let thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "film")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                if let selectedSource {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedSource.name)
                            .font(.headline)
                            .lineLimit(2)
                        Text(selectedSource.access.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    pickerError = nil
                    preparingSource = false
                    showImagePicker = true
                } label: {
                    Label(selectedSource == nil ? "Choose Video" : "Change Video", systemImage: "video.badge.plus")
                }
                .buttonStyle(.bordered)
                .disabled(processing || preparingSource)
                .accessibilityIdentifier("chooseVideoButton")
            }
        }
    }

    private var clipLengthPanel: some View {
        glassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Clip Length")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], spacing: 8) {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            partDuration = preset
                            SplitSettings.clipLength = partDuration
                        } label: {
                            Text("\(Int(preset))s")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(partDuration == preset ? .accentColor : .secondary)
                        .accessibilityIdentifier("clipLengthPreset\(Int(preset))")
                    }
                }

                HStack {
                    Button {
                        partDuration = max(10, partDuration - 5)
                        SplitSettings.clipLength = partDuration
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Decrease Clip Length")
                    .accessibilityIdentifier("decreaseClipLengthButton")

                    Slider(value: $partDuration, in: 10...180, step: 5) {
                        Text("Custom Clip Length")
                    } minimumValueLabel: {
                        Text("10s")
                    } maximumValueLabel: {
                        Text("180s")
                    } onEditingChanged: { editing in
                        if !editing {
                            SplitSettings.clipLength = partDuration
                        }
                    }

                    Button {
                        partDuration = min(180, partDuration + 5)
                        SplitSettings.clipLength = partDuration
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Increase Clip Length")
                    .accessibilityIdentifier("increaseClipLengthButton")
                }

                Text("\(Int(partDuration)) seconds")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("clipLengthValue")
            }
        }
    }

    private var actionPanel: some View {
        HStack(spacing: 12) {
            primaryActionButton

            if selectedSource != nil || result != nil {
                Button {
                    clearSelection()
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
                .disabled(processing)
                .accessibilityIdentifier("clearSelectionButton")
            }
        }
    }

    @ViewBuilder
    private var primaryActionButton: some View {
        if processing {
            Button(role: .destructive) {
                cancelRequested = true
            } label: {
                Label("Cancel Split", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("cancelSplitButton")
        } else {
            Button {
                startSplit()
            } label: {
                Label("Start Split", systemImage: "scissors")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedSource == nil)
            .accessibilityIdentifier("startSplitButton")
        }
    }

    @ViewBuilder
    private var statusPanel: some View {
        if preparingSource || progress != nil || result != nil || backgroundMessage != nil || pickerError != nil {
            glassPanel {
                VStack(alignment: .leading, spacing: 10) {
                    if preparingSource {
                        Text("Preparing Source Video")
                            .font(.headline)
                        ProgressView()
                        Text("Waiting for Photos to provide the video.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let progress {
                        Text(progress.label)
                            .font(.headline)
                        ProgressView(value: progress.fraction)
                        Text("\(Int(progress.fraction * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let result {
                        Text(result.status.title)
                            .font(.headline)
                        Text(result.message)
                            .font(.subheadline)
                            .foregroundStyle(result.status == .failed ? .red : .secondary)
                    }

                    if let backgroundMessage {
                        Text(backgroundMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let pickerError {
                        Text("Could not open Source Video")
                            .font(.headline)
                        Text(pickerError)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private var historySheet: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No Job History")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("emptyJobHistory")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 48)
                } else {
                    ForEach(history) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.status.title)
                                    .font(.headline)
                                Spacer()
                                Text(entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text(entry.sourceName)
                                .lineLimit(2)

                            Text("\(Int(entry.clipLength))s clips - \(entry.clipCount) saved - \(entry.sourceAccess.label)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if !entry.message.isEmpty {
                                Text(entry.message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteHistory)
                }
            }
            .navigationTitle("Job History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        showHistory = false
                    }
                    .accessibilityIdentifier("doneHistoryButton")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All", role: .destructive) {
                        SplitJobHistoryStore.clear()
                        history = []
                    }
                    .disabled(history.isEmpty)
                    .accessibilityIdentifier("clearAllHistoryButton")
                }
            }
        }
    }

    @ViewBuilder
    private func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                content()
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        } else {
            content()
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func startSplit() {
        guard let source = selectedSource else { return }

        cancelRequested = false
        processing = true
        progress = SplitJobProgress(completedClips: 0, totalClips: 0, currentClipFraction: 0, phase: .preparing)
        result = nil
        BackgroundSplitCoordinator.shared.onExpiration = {
            cancelRequested = true
            backgroundMessage = "Background Split expired before the Split Job completed."
        }

        Task {
            await prepareBackgroundIfNeeded(for: source)
            let jobResult = await runSplit(source)
            await MainActor.run {
                result = jobResult
                progress = nil
                processing = false
                history = SplitJobHistoryStore.load()
                BackgroundSplitCoordinator.shared.finish(success: jobResult.status == .completed || jobResult.status == .noSplitNeeded)

                if source.deleteAfterUse || jobResult.status == .completed || jobResult.status == .noSplitNeeded {
                    selectedSource = nil
                    thumbnail = nil
                }
            }

            await notifyIfNeeded(jobResult)
        }
    }

    private func runSplit(_ source: SplitSource) async -> SplitJobResult {
        do {
            return try await source.read { readableURL in
                await handleVideo(
                    url: readableURL,
                    sourceName: source.name,
                    sourceAccess: source.access,
                    deleteSourceAfterUse: source.deleteAfterUse,
                    partDuration: partDuration,
                    shouldCancel: { cancelRequested },
                    onProgress: updateProgress
                )
            }
        } catch {
            let failed = SplitJobResult(
                status: .failed,
                startedAt: Date(),
                endedAt: Date(),
                sourceName: source.name,
                clipLength: partDuration,
                clipCount: 0,
                outputAssetIdentifiers: [],
                sourceAccess: source.access,
                message: error.localizedDescription
            )
            SplitJobHistoryStore.append(failed.historyEntry)
            return failed
        }
    }

    private func updateProgress(_ update: SplitJobProgress) {
        progress = update
        BackgroundSplitCoordinator.shared.update(fraction: update.fraction)
    }

    private func prepareBackgroundIfNeeded(for source: SplitSource) async {
        let duration = await sourceDuration(source)
        guard (duration ?? 0) > splitFastShareInlineLimit else {
            await MainActor.run { backgroundMessage = nil }
            return
        }

        await requestNotificationPermission()

        await MainActor.run {
            if #available(iOS 26.0, *) {
                if let error = BackgroundSplitCoordinator.shared.submit(sourceName: source.name) {
                    backgroundMessage = "Background Split could not start: \(error)"
                } else {
                    backgroundMessage = "Background Split is using iOS continued processing."
                }
            } else {
                backgroundMessage = "Keep SplitFast open until this Split Job completes on this iOS version."
            }
        }
    }

    private func sourceDuration(_ source: SplitSource) async -> Double? {
        try? await source.duration()
    }

    private func notifyIfNeeded(_ jobResult: SplitJobResult) async {
        guard UIApplication.shared.applicationState != .active else { return }

        let content = UNMutableNotificationContent()
        content.title = "SplitFast \(jobResult.status.title)"
        content.body = jobResult.message

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    private func clearSelection() {
        if selectedSource?.deleteAfterUse == true, let url = selectedSource?.url {
            try? FileManager.default.removeItem(at: url)
        }
        selectedSource = nil
        thumbnail = nil
        pickerError = nil
        preparingSource = false
        result = nil
        progress = nil
        backgroundMessage = nil
        cancelRequested = false
    }

#if DEBUG
    private func loadUITestHandoffIfNeeded() {
        guard let rawURL = ProcessInfo.processInfo.environment["UITEST_HANDOFF_URL"],
              let url = URL(string: rawURL),
              let source = splitSource(fromHandoffURL: url)
        else {
            return
        }

        selectedSource = source
    }
#endif

    private func deleteHistory(at offsets: IndexSet) {
        let ids = offsets.map { history[$0].id }
        for id in ids {
            SplitJobHistoryStore.delete(id: id)
        }
        history = SplitJobHistoryStore.load()
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
