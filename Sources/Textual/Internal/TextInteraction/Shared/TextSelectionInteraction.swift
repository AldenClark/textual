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
            Color.clear
              .onChange(of: AnyTextLayoutCollection(layoutCollection), initial: true) {
                modelUpdater.schedule(
                  model: model,
                  coordinator: coordinator,
                  layoutCollection: layoutCollection
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
    private weak var model: TextSelectionModel?
    private weak var coordinator: TextSelectionCoordinator?
    private var layoutCollection: (any TextLayoutCollection)?
    private var isScheduled = false

    func schedule(
      model: TextSelectionModel,
      coordinator: TextSelectionCoordinator?,
      layoutCollection: any TextLayoutCollection
    ) {
      self.model = model
      self.coordinator = coordinator
      self.layoutCollection = layoutCollection

      guard !isScheduled else {
        return
      }
      isScheduled = true

      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.isScheduled = false

        guard
          let model = self.model,
          let layoutCollection = self.layoutCollection
        else {
          return
        }

        model.setCoordinator(self.coordinator)
        model.setLayoutCollection(layoutCollection)
      }
    }

    func cancel() {
      model = nil
      coordinator = nil
      layoutCollection = nil
      isScheduled = false
    }
  }
#endif
