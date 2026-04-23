import SwiftUI

// MARK: - Overview
//
// `TextSelectionInteraction` manages the text selection model lifecycle for multiple `Text` fragments.
//
// Selection is opt-in through the `textSelection` environment value. When enabled, the modifier
// observes text layout changes via `overlayTextLayoutCollection` and creates or updates a
// `TextSelectionModel`. The model is then passed to the platform-specific implementation
// (`PlatformTextSelectionInteraction`), which presents the appropriate selection UI for macOS
// or iOS. This separation keeps model management in shared code while platform interactions
// remain independent.

struct TextSelectionInteraction: ViewModifier {
  #if TEXTUAL_ENABLE_TEXT_SELECTION
    @Environment(\.textSelection) private var textSelection
    @Environment(TextSelectionCoordinator.self) private var coordinator: TextSelectionCoordinator?

    @State private var model = TextSelectionModel()
    @State private var modelUpdater = TextSelectionModelUpdater()
  #endif

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_TEXT_SELECTION
      if textSelection.allowsSelection {
        content
          .overlayTextLayoutCollection { layoutCollection in
            let layoutCollectionSnapshot = AnyTextLayoutCollection(layoutCollection)
            let updateKey = StableLayoutUpdateKey(layoutCollectionSnapshot)
            Color.clear
              .id(updateKey)
              .task {
                modelUpdater.schedule(
                  taskKey: updateKey,
                  model: model,
                  coordinator: coordinator,
                  layoutCollection: layoutCollectionSnapshot
                )
              }
          }
          .modifier(PlatformTextSelectionInteraction(model: model))
          .onDisappear {
            modelUpdater.cancel()
          }
      } else {
        content
      }
    #else
      content
    #endif
  }
}

#if TEXTUAL_ENABLE_TEXT_SELECTION
  extension EnvironmentValues {
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    @usableFromInline
    @Entry var textSelection: any TextSelectability.Type = DisabledTextSelectability.self
  }
#endif

#if TEXTUAL_ENABLE_TEXT_SELECTION
  @MainActor
  private final class TextSelectionModelUpdater {
    private var pendingTask: Task<Void, Never>?
    private var latestRequestedTaskKey: StableLayoutUpdateKey?

    deinit {
      pendingTask?.cancel()
    }

    func schedule(
      taskKey: StableLayoutUpdateKey,
      model: TextSelectionModel,
      coordinator: TextSelectionCoordinator?,
      layoutCollection: AnyTextLayoutCollection
    ) {
      guard latestRequestedTaskKey != taskKey else {
        return
      }
      latestRequestedTaskKey = taskKey

      pendingTask?.cancel()
      pendingTask = Task { @MainActor in
        await Task.yield()
        guard !Task.isCancelled else {
          return
        }

        model.setCoordinator(coordinator)
        model.setLayoutCollection(layoutCollection)
      }
    }

    func cancel() {
      pendingTask?.cancel()
      pendingTask = nil
      latestRequestedTaskKey = nil
    }
  }

  private struct StableLayoutUpdateKey: Hashable, Sendable {
    private let digest: Int

    init(_ layoutCollection: AnyTextLayoutCollection) {
      var hasher = Hasher()
      hasher.combine(layoutCollection.layouts.count)

      for layout in layoutCollection.layouts {
        hasher.combine(layout.attributedString.length)
        hasher.combine(Self.roundedPixel(layout.origin.x))
        hasher.combine(Self.roundedPixel(layout.origin.y))
        hasher.combine(Self.roundedPixel(layout.bounds.width))
        hasher.combine(Self.roundedPixel(layout.bounds.height))
      }

      digest = hasher.finalize()
    }

    private static func roundedPixel(_ value: CGFloat) -> Int {
      Int((value * 2).rounded())
    }
  }
#endif
