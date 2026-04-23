import SwiftUI

struct StopImagePlaybackOnScrollGesture: ViewModifier {
  @Environment(\.imageAttachmentPlaybackController) private var playbackController
  @State private var movementTracker = ScrollMovementTracker()
  private let movementThreshold: CGFloat = 0.5

  func body(content: Content) -> some View {
    content
      .onGeometryChange(for: CGPoint.self, of: \.globalOrigin) { origin in
        if movementTracker.didExceedThreshold(
          movingTo: origin,
          threshold: movementThreshold
        ) {
          playbackController.stop()
        }
      }
  }
}

private final class ScrollMovementTracker {
  private var lastObservedOrigin: CGPoint?

  func didExceedThreshold(
    movingTo origin: CGPoint,
    threshold: CGFloat
  ) -> Bool {
    defer {
      lastObservedOrigin = origin
    }

    guard let lastObservedOrigin else {
      return false
    }

    let deltaX = abs(origin.x - lastObservedOrigin.x)
    let deltaY = abs(origin.y - lastObservedOrigin.y)
    return deltaX > threshold || deltaY > threshold
  }
}

private extension GeometryProxy {
  var globalOrigin: CGPoint {
    frame(in: .global).origin
  }
}
