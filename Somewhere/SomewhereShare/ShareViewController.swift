//
//  ShareViewController.swift
//  Somewhere — Share Extension entry point.
//
//  iOS shows the extension in the system's bottom sheet when someone taps
//  Share → Somewhere. This controller just hosts the SwiftUI sheet and
//  tells iOS when we're done.
//
//  Extension target only.
//

import UIKit
import SwiftUI

final class ShareViewController: UIViewController {

    private let model = ShareSaveModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Theme is a light palette (cream / paper), so keep the sheet light.
        overrideUserInterfaceStyle = .light
        view.backgroundColor = UIColor(Theme.cream)

        let sheet = SaveSheetView(
            model: model,
            onDone: { [weak self] in self?.finish() },
            onCancel: { [weak self] in self?.cancel() }
        )
        let host = UIHostingController(rootView: sheet)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear

        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        let context = extensionContext
        Task { await model.load(from: context) }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(
            withError: NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        )
    }
}
