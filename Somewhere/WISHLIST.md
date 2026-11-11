# somewhere — Wishlist (Nicole)

The Wishlist part of the app, from the board:

- **How saved items are stored on the phone:** a SwiftData store inside the App Group, shared by the app and the Share Extension
- **The Wishlist page:** a two-column polaroid grid of everything you saved
- **Search and category filters:** search "that blue bag from TikTok", filter by category chips, source app, and sort
- **The context page:** where and when you saved it, why you wanted it (note and voice note), colour, shelf status, and any text found in the screenshot

Requires iOS 17+ (SwiftData, `@Observable`).

## Files

| Folder | File | Targets |
|---|---|---|
| `Model/` | `SavedItem.swift` – the one shared record | **App + Share Extension** |
| | `WishlistEnums.swift` – `ItemCategory`, `SourceApp`, `ItemStatus`, `WishlistSort` | **App + Share Extension** |
| | `SharedStore.swift` – App Group, `ModelContainer`, `SavedItemStore.save/delete/decide`, image downscaling | **App + Share Extension** |
| | `WishlistSearch.swift` – search + filter logic (pure Foundation) | **App + Share Extension** |
| `UI/` | `WishlistView.swift` – the Wishlist page | App |
| | `WishlistComponents.swift` – card, chips, badges, image cache, empty states | App |
| | `ItemDetailView.swift` – the context page | App |
| | `VoiceNoteRow.swift` – voice note playback | App |
| | `Theme.swift` – colours and fonts from the pitch deck | App |
| | `SampleData.swift` – preview data | App |
| `Tests/` | `WishlistSearchTests.swift` | Unit test target |

## Xcode setup

1. Drag the `Model/` and `UI/` folders into the project. In the File Inspector, tick target membership as shown in the table above.
2. **Signing & Capabilities → + App Groups** on *both* the app and the Share Extension targets. Use the same group, e.g. `group.com.somewhere.app`, and update `AppGroup.identifier` in `SharedStore.swift` to match.
3. Attach the container in the app entry point:

   ```swift
   @main
   struct SomewhereApp: App {
       var body: some Scene {
           WindowGroup {
               WishlistView()            // or the TabView that contains it
           }
           .modelContainer(SharedModelContainer.shared)
       }
   }
   ```

4. Optional: add the **Gochi Hand** font (Google Fonts, free) for the handwritten captions. Register it under `UIAppFonts` in Info.plist. Without it, captions fall back to the system font.
5. Tests: in `WishlistSearchTests.swift`, change `@testable import Somewhere` to the app's module name.

## For Mina (Saving)

Use one call from the Share Extension and from the "+" button:

```swift
let context = ModelContext(SharedModelContainer.shared)
try SavedItemStore.save(
    title: metadata.title ?? "",
    image: previewImage,                 // UIImage; downscaled automatically
    link: url,
    source: SourceApp.from(url: url),    // or .screenshot
    recognizedText: visionText,          // makes screenshots searchable
    colorName: "blue", colorHex: "#3B63D9",
    in: context
)
```

- If you don't pass `category`, `ItemCategory.guess(from:)` picks one from the title and screenshot text.
- `colorName` should be a basic colour family (blue, pink, brown, …) so colour search works.

## For Kaitlyn (Shelf)

- New items start as `status == .cooling` with `shelfReadyAt = createdAt + 3 days`. Change `SavedItem.defaultCoolingPeriod` to adjust this.
- Items for the swipe screen: `@Query(filter: #Predicate<SavedItem> { $0.statusRaw == "cooling" })`, then keep the ones where `isReadyToDecide` is true.
- After a swipe: `SavedItemStore.decide(item, keep: true/false, in: context)`. Items marked "let go" disappear from the Wishlist.
- Voice notes: save the `.m4a` into `AppGroup.voiceNotesDirectory` and set `item.voiceNoteFileName` to the file name only. The context page plays it automatically.

## How search works

`"that blue bag from TikTok"` becomes the tokens `blue`, `bag`, `tiktok`. Filler words like "that" and "from" are dropped. **Every** token must match something about the item: title, brand, note, screenshot text, colour, source app, category, or link site.

The search is forgiving in a few ways:
- Plurals: "bags" finds "bag".
- Colour synonyms: "navy" finds blue.
- Category words: "purse" finds anything in *bags & shoes*.
- Prefixes: "blu" finds blue.

## Known limitation

When the Share Extension saves an item while the app is open in the background, the app shows it the next time it comes to the foreground. `WishlistView` re-runs its query on `scenePhase == .active`.
