# Artwork & Sticker Editor for iOS (SwiftUI)

A complete, professional-grade mobile artwork and sticker editor built entirely in Swift and SwiftUI for iOS 16+.

Features a responsive design canvas supporting interactive sticker/text composition, gestures, customizable backgrounds, aspect ratio presets, undo/redo history, drag-to-trash deletion, physical haptic feedback, and isolated high-resolution view capture via `ImageRenderer`.

---

## 📱 Key Features

### 1. Advanced Data Model
- **`CanvasItem`** conforming to `Identifiable` and `Equatable`:
  - **Dynamic content**: Supports both `.image(UIImage)` and `.text(String, Color, Font)`.
  - **Geometric state**: Tracks position (`CGPoint`), scale (default `1.0`), rotation (`Angle`, default `0`).
  - **Unique identity**: `UUID`.
  - **Bounding box control**: `boundsVisible` (`Bool`).
- Custom `Equatable` implementation handles SwiftUI `Font` and image data comparison cleanly across all iOS versions.

### 2. Background Control
- **`CanvasBackground` state**:
  - `.gradient([Color])`: Curated gradient presets (Sunset, Ocean, Aurora, Berry, Midnight, Peach, Neon).
  - `.color(Color)`: Custom solid background color with SwiftUI `ColorPicker`.
  - `.photo(UIImage)`: Background photo import directly from photo library using SwiftUI's native `PhotosPicker`.

### 3. Frame Presets & Selection
- **Aspect Ratio Selector**:
  - `1:1` Square (Feed posts / avatars)
  - `4:5` Portrait (Instagram portrait feeds)
  - `9:16` Story (Reels / TikTok / Stories)
- **Bounding Box Toggle**:
  - Instant UI toggle (`Bounds On` / `Bounds Off`) to show/hide the dashed bounding box, corner indicator handles, and quick delete button on active items.

### 4. Interactive Gestures & Physical Haptics
- **Simultaneous Pinch & Rotation**: Uses `SimultaneousGesture(MagnificationGesture(), RotationGesture())` for smooth, two-finger scaling and rotation.
- **Fluid Dragging & Coordinate Mapping**: Drag items anywhere on the canvas with real-time feedback.
- **Layering (Bring-to-Front & Send-to-Back)**: Tapping or dragging an item brings it to the top layer. Dedicated Layer studio tab also allows duplicate and reorder.
- **Drag-to-Trash Zone**:
  - Floating trash zone automatically animates into view during active drag.
  - Hover detection triggers when dragged over the bottom deletion zone.
  - Releasing deletes the item immediately and records the change in history.
- **Haptic Feedback (`HapticManager`)**:
  - Light impact haptics when entering the trash zone or when an item/image is dropped onto the canvas.
  - Notification haptics for delete, clear, and successful camera roll export.
- **Native Image Drag-and-Drop & Text Entry**:
  - `.onDrop(of: [UTType.image.identifier])` accepts images dropped directly onto the canvas.
  - Built-in `TextEntrySheet` allows choosing text, font size slider (16–64 pt), font design (Rounded, Default, Serif, Mono), and color swatches.

### 5. Undo & Redo History
- **`CanvasHistoryManager`**:
  - Action history captures full snapshots (`CanvasSnapshot`) of canvas items, background state, and aspect ratio.
  - Dedicated **Undo** and **Redo** toolbar buttons with real-time enabled/disabled states.
  - **Clear Canvas** button with confirmation alert (fully undoable).

### 6. Isolated High-Res Export & Persistence
- **Isolated View Capture**:
  - Uses `ImageRenderer` on `CleanCanvasArtworkView`, strictly capturing *only* the artwork layers (background, stickers, text).
  - Absolutely **no system screenshots**, no device status bar icons, no bounding boxes, and no editor control UI in the final render.
- **Retina Resolution**:
  - Automatically sets `ImageRenderer.scale = UIScreen.main.scale` to ensure crisp, print-ready output.
- **Direct Persistence & Sharing**:
  - **Save to Camera Roll**: `PhotoLibraryManager` checks and requests `PHPhotoLibrary.requestAuthorization(for: .addOnly)` and saves to user's Photos.
  - **Standard SwiftUI `ShareLink`**: Conforms to `Transferable` via `ArtworkExportItem` to share high-resolution PNGs immediately across AirDrop, Messages, Instagram, Mail, and Files.

---

## 📂 File Architecture

```
my-project/
├── Info.plist                                # iOS privacy permission descriptions
├── Package.swift                             # Swift Package Manager manifest (iOS 16+)
├── README.md
└── Sources/
    ├── Models/
    │   └── CanvasModels.swift                # CanvasItem, CanvasItemType, CanvasBackground, AspectRatio
    ├── History/
    │   └── CanvasHistoryManager.swift        # Undo/Redo snapshot history engine
    ├── Services/
    │   ├── HapticManager.swift               # UIImpactFeedbackGenerator & UINotificationFeedbackGenerator
    │   └── PhotoLibraryManager.swift         # PHPhotoLibrary authorization & Camera Roll save
    ├── Views/
    │   ├── ArtworkRenderView.swift           # Clean isolated canvas & ImageRenderer export service
    │   └── EditorCanvasView.swift            # Primary integrated interactive editor view
    └── App/
        └── ArtworkEditorApp.swift            # SwiftUI @main App entry point
```

---

## 🚀 Getting Started

### Using in Xcode
1. Open the project in Xcode (or add the folder to your Xcode workspace).
2. Ensure deployment target is set to **iOS 16.0** or later.
3. In your target's `Info.plist`, ensure the following keys are present:
   - `NSPhotoLibraryAddUsageDescription`: *"ArtworkEditor needs permission to save your created artwork to your photo library."*
   - `NSPhotoLibraryUsageDescription`: *"ArtworkEditor needs permission to import stickers and background photos from your library."*
4. Build and run on an iOS simulator or physical device!

### Quick Usage Example
```swift
import SwiftUI
import ArtworkEditor

struct ContentView: View {
    var body: some View {
        EditorCanvasView()
    }
}
```
