//
//  ArtworkEditorApp.swift
//  ArtworkEditor
//
//  Entry point for the mobile artwork and sticker editor application.
//

import SwiftUI

#if !SWIFT_PACKAGE
@main
struct ArtworkEditorApp: App {
    var body: some Scene {
        WindowGroup {
            EditorCanvasView()
        }
    }
}
#endif
