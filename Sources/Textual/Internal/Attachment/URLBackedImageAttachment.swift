import SwiftUI
import Combine
import ImageIO

#if canImport(SDWebImageSwiftUI)
  import SDWebImageSwiftUI
#endif

@usableFromInline
struct URLBackedImageAttachment: Attachment {
  let url: URL
  let text: String
  let intrinsicSize: CGSize?

  @usableFromInline
  var description: String {
    text
  }

  @usableFromInline
  var body: some View {
    URLBackedImageAttachmentView(url: url)
  }

  @usableFromInline
  func sizeThatFits(_ proposal: ProposedViewSize, in _: TextEnvironmentValues) -> CGSize {
    let maxWidth = max(min(proposal.width ?? 240, 960), 1)

    guard
      let intrinsicSize,
      intrinsicSize.width > 0,
      intrinsicSize.height > 0
    else {
      // Keep a conservative default size when intrinsic dimensions are unknown.
      // This avoids stretching small images to full line width.
      let defaultWidth = min(maxWidth, 240)
      return CGSize(width: defaultWidth, height: defaultWidth * 9.0 / 16.0)
    }

    let aspect = intrinsicSize.width / intrinsicSize.height
    let width = min(maxWidth, intrinsicSize.width)
    let height = width / aspect
    return CGSize(width: width, height: height)
  }
}

private struct URLBackedImageAttachmentView: View {
  @Environment(\.imageAttachmentURLResolver) private var resolver
  @Environment(\.imageAttachmentTapAction) private var tapAction
  @Environment(\.imageAttachmentPlaybackController) private var playbackController
  @State private var resolvedURL: URL?
  @State private var isSupportedAnimatedAsset = false
  @State private var singleLoopDuration: TimeInterval = 0.6
  @State private var isAnimating = false
  @State private var playbackTask: Task<Void, Never>?

  let url: URL

  var body: some View {
    contentView(for: resolvedURL ?? url)
      .overlay(alignment: .bottomTrailing) {
        if isSupportedAnimatedAsset, !isAnimating {
          Button(action: requestPlayback) {
            SwiftUI.Image(systemName: "play.circle.fill")
              .font(.system(size: 30, weight: .semibold))
              .foregroundStyle(.white)
              .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
              .padding(8)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Play animated image")
        }
      }
      .contentShape(Rectangle())
      .onTapGesture {
        tapAction?(url)
      }
      .task(id: url) {
        resolvedURL = await resolver.sourceURL(for: url)
      }
      .task(id: resolvedURL ?? url) {
        await refreshAnimationMetadata(for: resolvedURL ?? url)
      }
      .onReceive(playbackController.$activeAttachmentID.removeDuplicates()) { activeAttachmentID in
        handlePlaybackState(activeAttachmentID: activeAttachmentID)
      }
      .onAppear {
        handlePlaybackState(activeAttachmentID: playbackController.activeAttachmentID)
      }
      .onDisappear {
        playbackTask?.cancel()
        playbackTask = nil
        isAnimating = false
        playbackController.stop(ifActive: attachmentID)
      }
  }

  @ViewBuilder
  private func contentView(for sourceURL: URL) -> some View {
    #if canImport(SDWebImageSwiftUI)
      AnimatedImage(url: sourceURL, isAnimating: $isAnimating)
        .indicator(.activity)
        .customLoopCount(1)
        .resizable()
        .scaledToFit()
    #else
      AsyncImage(url: sourceURL) { phase in
        switch phase {
        case let .success(image):
          image
            .resizable()
            .scaledToFit()
        case .empty:
          Color.clear
        case .failure:
          Color.clear
        @unknown default:
          Color.clear
        }
      }
    #endif
  }

  private var attachmentID: String {
    url.absoluteString
  }

  private func requestPlayback() {
    playbackController.play(attachmentID)
  }

  private func handlePlaybackState(activeAttachmentID: String?) {
    let shouldAnimate = isSupportedAnimatedAsset && activeAttachmentID == attachmentID
    if shouldAnimate {
      startPlaybackOnce()
    } else {
      stopPlayback()
    }
  }

  private func startPlaybackOnce() {
    guard !isAnimating else { return }
    isAnimating = true
    playbackTask?.cancel()
    let duration = max(singleLoopDuration, 0.12)
    playbackTask = Task { [duration, attachmentID, playbackController] in
      let delay = UInt64(duration * 1_000_000_000)
      try? await Task.sleep(nanoseconds: delay)
      await MainActor.run {
        playbackController.stop(ifActive: attachmentID)
      }
    }
  }

  private func stopPlayback() {
    isAnimating = false
    playbackTask?.cancel()
    playbackTask = nil
  }

  private func refreshAnimationMetadata(for sourceURL: URL) async {
    let metadata = Self.readAnimationMetadata(from: sourceURL)
    await MainActor.run {
      isSupportedAnimatedAsset = metadata.supported
      singleLoopDuration = metadata.singleLoopDuration
      if !metadata.supported {
        playbackController.stop(ifActive: attachmentID)
      }
    }
  }

  private struct AnimationMetadata {
    let supported: Bool
    let singleLoopDuration: TimeInterval
  }

  private static func readAnimationMetadata(from sourceURL: URL) -> AnimationMetadata {
    guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
      return .init(supported: false, singleLoopDuration: 0.6)
    }

    let frameCount = CGImageSourceGetCount(source)
    guard frameCount > 1 else {
      return .init(supported: false, singleLoopDuration: 0.6)
    }

    let typeIdentifier = (CGImageSourceGetType(source) as String?)?.lowercased() ?? ""
    let isAnimatedFormat =
      typeIdentifier.contains("gif") ||
      typeIdentifier.contains("webp") ||
      typeIdentifier.contains("png")
    guard isAnimatedFormat else {
      return .init(supported: false, singleLoopDuration: 0.6)
    }

    var duration: TimeInterval = 0
    for index in 0 ..< frameCount {
      guard
        let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
      else {
        duration += 0.1
        continue
      }
      duration += frameDelay(from: properties)
    }

    if duration <= 0 {
      duration = min(TimeInterval(frameCount) * 0.1, 12)
    }
    duration = min(max(duration, 0.12), 20)
    return .init(supported: true, singleLoopDuration: duration)
  }

  private static func frameDelay(from properties: [CFString: Any]) -> TimeInterval {
    let dictionaries: [[CFString: Any]] = [
      properties[kCGImagePropertyGIFDictionary] as? [CFString: Any],
      properties[kCGImagePropertyPNGDictionary] as? [CFString: Any],
      properties["WebP" as CFString] as? [CFString: Any],
      properties["{WebP}" as CFString] as? [CFString: Any],
    ]
    .compactMap { $0 }

    for dictionary in dictionaries {
      if let unclamped = readDelayValue(from: dictionary, matching: "UnclampedDelayTime"), unclamped > 0 {
        return max(unclamped, 0.02)
      }
      if let delay = readDelayValue(from: dictionary, matching: "DelayTime"), delay > 0 {
        return max(delay, 0.02)
      }
    }

    return 0.1
  }

  private static func readDelayValue(
    from dictionary: [CFString: Any],
    matching keyword: String
  ) -> TimeInterval? {
    for (key, value) in dictionary {
      let keyString = (key as String).lowercased()
      guard keyString.contains(keyword.lowercased()) else { continue }
      if let number = value as? NSNumber {
        return number.doubleValue
      }
    }
    return nil
  }
}
