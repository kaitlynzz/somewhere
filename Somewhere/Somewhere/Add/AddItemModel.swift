//
//  AddItemModel.swift
//  Somewhere — Add (Karan)
//
//  The state behind the add sheet. Two modes:
//    • one       — a single AddDraft: paste a link (it looks itself up) or
//                  type a name, add a reason, save.
//    • multiple  — a Reminders-style list of links. "add all to wishlist"
//                  scans every link at once and saves each as it comes back;
//                  the results show as cart rows you can still name / give a
//                  reason / remove.
//
//  Everything saves through SavedItemStore (AddDraft.save), the same call the
//  Share Extension uses, so an item added here is identical to one shared in.
//
//  App target only.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AddItemModel {

    enum Mode { case one, multiple }

    enum Phase: Equatable {
        /// Filling in the form or the list.
        case editing
        case saving
        /// "add one" finished — the success animation.
        case saved(title: String, coolingDays: Int)
        /// "add multiple" — the results list (still scanning while any row is looking).
        case batchResults
        case failed(String)
    }

    var mode: Mode = .one
    private(set) var phase: Phase = .editing

    // MARK: Add one

    var single = AddDraft()

    var canSaveSingle: Bool {
        phase != .saving && single.isLinkValid && single.hasSomethingToSave
    }

    func saveSingle(in context: ModelContext) {
        guard canSaveSingle else { return }
        phase = .saving
        do {
            let item = try single.save(in: context)
            phase = .saved(title: item.title, coolingDays: ShelfSettings.coolingDays)
            Task { await VisualIndexer.run(in: context) }   // tag the picture for search
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // MARK: Add multiple

    /// The list being typed. Always ends in an empty row to type into.
    private(set) var rows: [AddDraft] = [AddDraft()]
    /// What "add all" scanned and saved, in list order.
    private(set) var results: [AddDraft] = []

    /// One row per distinct link; typos and blanks don't count.
    var linksToAdd: [AddDraft] {
        var seen = Set<URL>()
        return rows.filter { row in
            guard let url = row.parsedLink else { return false }
            return seen.insert(url).inserted
        }
    }

    var isScanning: Bool { results.contains { $0.isLooking } }
    var savedCount: Int { results.filter { $0.savedItem != nil }.count }

    func switchTo(_ newMode: Mode) {
        guard phase == .editing || phase == .batchResults || isFailed else { return }
        // Carry a link across so switching never throws away what was typed.
        if newMode == .multiple, single.hasText, rows.allSatisfy({ !$0.hasText }) {
            rows = [AddDraft(linkText: single.linkText), AddDraft()]
        } else if newMode == .one, !single.hasText, let first = rows.first(where: \.hasText), linksToAdd.count == 1 {
            single = AddDraft(linkText: first.linkText)
        }
        mode = newMode
        phase = .editing
    }

    /// Adds an empty row after `row` and returns it (Return on a row = new row, like Reminders).
    @discardableResult
    func insertRow(after row: AddDraft) -> AddDraft {
        let new = AddDraft()
        let index = (rows.firstIndex { $0.id == row.id } ?? rows.count - 1) + 1
        rows.insert(new, at: index)
        return new
    }

    func removeRow(_ row: AddDraft) {
        rows.removeAll { $0.id == row.id }
        ensureTrailingEmptyRow()
    }

    /// A row's text changed. If it now holds several links (pasted a list),
    /// split it into one row each. Returns the row to focus afterwards.
    func rowChanged(_ row: AddDraft) -> AddDraft? {
        let links = LinkMetadataParser.allURLs(in: row.linkText)
        if links.count > 1, let index = rows.firstIndex(where: { $0.id == row.id }) {
            row.linkText = links[0].absoluteString
            let extra = links.dropFirst().map { AddDraft(linkText: $0.absoluteString) }
            rows.insert(contentsOf: extra, at: index + 1)
            ensureTrailingEmptyRow()
            return rows.last
        }
        ensureTrailingEmptyRow()
        return nil
    }

    private func ensureTrailingEmptyRow() {
        if rows.last?.hasText != false { rows.append(AddDraft()) }
    }

    /// Scans every link at once and saves each one as soon as it's read.
    func addAll(in context: ModelContext) async {
        let batch = linksToAdd
        guard !batch.isEmpty, phase == .editing else { return }
        results = batch
        phase = .batchResults

        let jobs = batch.map { draft in
            Task {
                await draft.lookUp()
                // Saved even if the page couldn't be read — the link is
                // still worth keeping, and the row lets you name it.
                _ = try? draft.save(in: context)
            }
        }
        for job in jobs { await job.value }
        await VisualIndexer.run(in: context)
    }

    func remove(_ result: AddDraft, in context: ModelContext) {
        result.unsave(in: context)
        results.removeAll { $0.id == result.id }
    }

    // MARK: Start over

    func reset() {
        single = AddDraft()
        rows = [AddDraft()]
        results = []
        phase = .editing
    }

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }
}
