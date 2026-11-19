//
//  VisualIndexer.swift
//  Somewhere — runs VisualTagger over saved items in the background.
//
//  Works through every item whose `visualIndexVersion` is behind, so it
//  covers new saves (from the app *and* the Share Extension) and items saved
//  before this existed. Runs at launch, when the app comes back to the
//  foreground, and after an in-app save.
//
//  Bump `currentVersion` when VisualTagger changes, and everything gets
//  re-tagged on the next launch.
//
//  App target only.
//

import Foundation
import SwiftData

@MainActor
enum VisualIndexer {

    /// 2: also works out what each item is (ItemKind).
    static let currentVersion = 2

    private static var isRunning = false
    private static var needsAnotherPass = false

    static func run(in context: ModelContext) async {
        // A save during a pass would be missed by that pass's fetch, so queue one more.
        guard !isRunning else { needsAnotherPass = true; return }
        isRunning = true
        defer { isRunning = false }

        repeat {
            needsAnotherPass = false
            await indexPending(in: context)
        } while needsAnotherPass && !Task.isCancelled
    }

    private static func indexPending(in context: ModelContext) async {
        let version = currentVersion
        let descriptor = FetchDescriptor<SavedItem>(
            predicate: #Predicate { $0.visualIndexVersion < version },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]   // newest first
        )
        guard let pending = try? context.fetch(descriptor) else { return }

        for item in pending {
            if Task.isCancelled { return }
            guard !item.isDeleted else { continue }

            guard let data = item.imageData else {
                // No picture, but the words may still say what it is.
                applyKind(to: item, visionLabels: [])
                item.visualIndexVersion = version
                continue
            }

            // Vision is slow-ish (tens of ms per picture); keep it off the main thread.
            let analysis = await Task.detached(priority: .utility) {
                VisualTagger.analyze(data)
            }.value

            guard !item.isDeleted else { continue }   // deleted while we were looking
            apply(analysis, to: item, version: version)
            try? context.save()
        }
    }

    private static func apply(_ analysis: VisualAnalysis, to item: SavedItem, version: Int) {
        if analysis.classified {
            // Labels first (the detail screen shows the first few), then extra colours.
            var words = analysis.labels.map(\.name)
            words += analysis.colourFamilies.filter { !words.contains($0) }
            item.visualTags = words.isEmpty ? nil : words.joined(separator: " ")
        }

        // Screenshots already got a colour in the Share Extension; link saves didn't.
        if item.colorName == nil, let color = analysis.color {
            item.colorName = color.name
            item.colorHex = color.hex
        }

        applyKind(to: item, visionLabels: analysis.labels)

        // Only fill in "other" — never override a category someone picked.
        if item.category == .other, let category = VisualTagger.category(for: analysis.labels) {
            item.category = category
        }

        // If Vision failed, leave the version behind so it's retried next time.
        if analysis.classified {
            item.visualIndexVersion = version
        }
    }

    /// "shirt", "sneakers"… from the title, page description, Vision, then screenshot text.
    private static func applyKind(to item: SavedItem, visionLabels: [VisualAnalysis.Label]) {
        guard let kind = ItemKind.detect(
            title: item.title,
            description: item.pageDescription,
            visionLabels: visionLabels.map { ($0.name, $0.confidence) },
            recognizedText: item.recognizedText
        ) else { return }
        item.itemType = kind.name
        if item.category == .other { item.category = kind.category }
    }
}
