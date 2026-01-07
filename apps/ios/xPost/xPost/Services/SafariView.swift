//
//  SafariView.swift
//  xPost
//
//  Created by Takekuni Tanemori on 1/6/26.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        // This makes it look like an integrated part of your app
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
