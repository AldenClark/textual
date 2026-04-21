import SwiftUI

struct StopImagePlaybackOnScrollGesture: ViewModifier {
  @Environment(\.imageAttachmentPlaybackController) private var playbackController
  @State private var lastObservedOrigin: CGPoint?
  private let movementThreshold: CGFloat = 0.5

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGPoint.self, of: \.globalOrigin) { origin in
        if let lastObservedOrigin {
          let deltaX = abs(origin.x - lastObservedOrigin.x)
          let deltaY = abs(origin.y - lastObservedOrigin.y)
          if deltaX > movementThreshold || deltaY > movementThreshold {
            playbackController.stop()
          }
        }
        self.lastObservedOrigin = origin
      }
  }
}

private extension GeometryProxy {
  var globalOrigin: CGPoint {
    frame(in: .global).origin
  }
}
