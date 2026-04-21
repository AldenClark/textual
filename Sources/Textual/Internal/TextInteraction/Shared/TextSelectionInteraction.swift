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
    @State private var layoutSync = LayoutSync()
  #endif

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_TEXT_SELECTION
      if textSelection.allowsSelection {
        content
          .overlayTextLayoutCollection { layoutCollection in
            let layoutCollectionSnapshot = AnyTextLayoutCollection(layoutCollection)
            let taskKey = StableLayoutTaskKey(layoutCollectionSnapshot)
            Color.clear
              .id(taskKey)
              .task {
                layoutSync.schedule(
                  taskKey: taskKey,
                  newValue: layoutCollectionSnapshot,
                  coordinator: coordinator,
                  model: model
                )
              }
          }
          .modifier(PlatformTextSelectionInteraction(model: model))
          .onDisappear {
            layoutSync.cancelPendingUpdate()
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
  @MainActor
  private final class LayoutSync {
    private var pendingTask: Task<Void, Never>?
    private var latestRequestedLayoutCollection: AnyTextLayoutCollection?
    private var latestRequestedTaskKey: StableLayoutTaskKey?

    deinit {
      pendingTask?.cancel()
    }

    func schedule(
      taskKey: StableLayoutTaskKey,
      newValue: AnyTextLayoutCollection,
      coordinator: TextSelectionCoordinator?,
      model: TextSelectionModel
    ) {
      guard latestRequestedTaskKey != taskKey else {
        return
      }
      guard latestRequestedLayoutCollection != newValue else {
        return
      }

      latestRequestedTaskKey = taskKey
      latestRequestedLayoutCollection = newValue
      pendingTask?.cancel()
      pendingTask = Task { @MainActor [newValue] in
        await Task.yield()
        guard !Task.isCancelled else {
          return
        }
        model.setCoordinator(coordinator)
        model.setLayoutCollection(newValue)
      }
    }

    func cancelPendingUpdate() {
      pendingTask?.cancel()
      pendingTask = nil
    }
  }

  private struct StableLayoutTaskKey: Hashable, Sendable {
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
      // Normalize to half-point granularity to suppress layout jitter churn.
      Int((value * 2).rounded())
    }
  }
#endif

#if TEXTUAL_ENABLE_TEXT_SELECTION
  extension EnvironmentValues {
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    @usableFromInline
    @Entry var textSelection: any TextSelectability.Type = DisabledTextSelectability.self
  }
#endif
