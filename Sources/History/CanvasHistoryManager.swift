//
//  CanvasHistoryManager.swift
//  ArtworkEditor
//
//  Created for mobile artwork and sticker editor in SwiftUI.
//

import SwiftUI
import Combine

/// Complete snapshot of the canvas state for undo and redo operations.
public struct CanvasSnapshot: Equatable {
    public let items: [CanvasItem]
    public let background: CanvasBackground
    public let aspectRatio: CanvasAspectRatio

    public init(items: [CanvasItem], background: CanvasBackground, aspectRatio: CanvasAspectRatio) {
        self.items = items
        self.background = background
        self.aspectRatio = aspectRatio
    }
}

/// Manages undo and redo history for artwork manipulation, additions, and deletions.
@MainActor
public final class CanvasHistoryManager: ObservableObject {
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false

    private var undoStack: [CanvasSnapshot] = []
    private var redoStack: [CanvasSnapshot] = []
    private let maxHistoryLimit: Int

    public init(maxHistoryLimit: Int = 40) {
        self.maxHistoryLimit = maxHistoryLimit
    }

    /// Pushes a state snapshot onto the undo stack. Clears the redo stack.
    public func registerSnapshot(_ snapshot: CanvasSnapshot) {
        // Prevent recording consecutive identical states
        if let last = undoStack.last, last == snapshot {
            return
        }
        undoStack.append(snapshot)
        if undoStack.count > maxHistoryLimit {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        updateFlags()
    }

    /// Performs an undo operation by restoring the previous snapshot and pushing current state to redo.
    public func undo(currentSnapshot: CanvasSnapshot) -> CanvasSnapshot? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(currentSnapshot)
        updateFlags()
        return previous
    }

    /// Performs a redo operation by popping the redo stack and pushing current state to undo.
    public func redo(currentSnapshot: CanvasSnapshot) -> CanvasSnapshot? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(currentSnapshot)
        updateFlags()
        return next
    }

    /// Clears all undo and redo history.
    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateFlags()
    }

    private func updateFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}
