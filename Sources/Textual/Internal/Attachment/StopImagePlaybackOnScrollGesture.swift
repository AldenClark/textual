import SwiftUI

struct StopImagePlaybackOnScrollGesture: ViewModifier {
  @Environment(\.imageAttachmentPlaybackController) private var playbackController
  @State private var hasStoppedForCurrentDrag = false

  func body(content: Content) -> some View {
    content.simultaneousGesture(
      DragGesture(minimumDistance: 2)
        .onChanged { _ in
          guard !hasStoppedForCurrentDrag else { return }
          hasStoppedForCurrentDrag = true
          playbackController.stop()
        }
        .onEnded { _ in
          hasStoppedForCurrentDrag = false
        },
      including: .all
    )
  }
}
