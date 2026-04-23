import SwiftUI
import Combine
import ImageIO
import Foundation

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
      let size = CGSize(width: defaultWidth, height: defaultWidth * 9.0 / 16.0)
      MarkdownImageDebug.log(
        "sizeThatFits fallback url=\(MarkdownImageDebug.urlKey(url)) proposal=\(Int(proposal.width ?? -1)) result=\(MarkdownImageDebug.sizeKey(size))"
      )
      return size
    }

    let aspect = intrinsicSize.width / intrinsicSize.height
    let width = min(maxWidth, intrinsicSize.width)
    let height = width / aspect
    let size = CGSize(width: width, height: height)
    MarkdownImageDebug.log(
      "sizeThatFits intrinsic url=\(MarkdownImageDebug.urlKey(url)) proposal=\(Int(proposal.width ?? -1)) intrinsic=\(MarkdownImageDebug.sizeKey(intrinsicSize)) result=\(MarkdownImageDebug.sizeKey(size))"
    )
    return size
  }
}

private struct URLBackedImageAttachmentView: View {
  @Environment(\.imageAttachmentURLResolver) private var resolver
  @Environment(\.imageAttachmentTapAction) private var tapAction
  @Environment(\.imageAttachmentPlaybackController) private var playbackController
  @State private var attachmentInstanceID = UUID().uuidString
  @State private var resolvedURL: URL?
  @State private var isSupportedAnimatedAsset = false
  @State private var singleLoopDuration: TimeInterval = 0.6
  @State private var isPlaying = false
  @State private var playbackSessionID = UUID()
  @State private var playbackTask: Task<Void, Never>?

  let url: URL

  var body: some View {
    Group {
      if let resolvedURL {
        contentView(for: resolvedURL)
      } else {
        placeholderView
      }
    }
      .contentShape(Rectangle())
      .gesture(
        TapGesture().onEnded {
          tapAction?(url)
        },
        including: .gesture
      )
      .overlay(alignment: .bottomTrailing) {
        if isSupportedAnimatedAsset, !isPlaying {
          Button(action: requestPlayback) {
            SwiftUI.Image(systemName: "play.circle.fill")
              .font(.system(size: 30, weight: .semibold))
              .foregroundStyle(.white)
              .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
              .padding(8)
          }
          .buttonStyle(.plain)
          .contentShape(Rectangle())
          .accessibilityLabel("Play animated image")
        }
      }
      .task(id: url) {
        let sourceURL = await resolver.resolvedSourceURL(for: url)
        MarkdownImageDebug.log(
          "resolvedSource url=\(MarkdownImageDebug.urlKey(url)) source=\(MarkdownImageDebug.urlKey(sourceURL ?? url))"
        )
        resolvedURL = sourceURL
      }
      .task(id: resolvedURL) {
        guard let resolvedURL else {
          await MainActor.run {
            isSupportedAnimatedAsset = false
            singleLoopDuration = 0.6
            playbackController.stop(ifActive: attachmentID)
          }
          return
        }
        await refreshAnimationMetadata(for: resolvedURL)
      }
      .onReceive(playbackController.$activeAttachmentID.removeDuplicates()) { activeAttachmentID in
        handlePlaybackState(activeAttachmentID: activeAttachmentID)
      }
      .onAppear {
        SDWebImageAnimatedCoders.bootstrapIfNeeded()
        handlePlaybackState(activeAttachmentID: playbackController.activeAttachmentID)
      }
      .onDisappear {
        playbackTask?.cancel()
        playbackTask = nil
        stopPlayback()
      }
  }

  @ViewBuilder
  private func contentView(for sourceURL: URL) -> some View {
    #if canImport(SDWebImageSwiftUI)
      if isSupportedAnimatedAsset, isPlaying {
        AnimatedImage(
          url: sourceURL,
          options: [.matchAnimatedImageClass, .fromLoaderOnly],
          isAnimating: .constant(true)
        )
          .customLoopCount(1)
          .resizable()
          .scaledToFit()
          .id(playbackSessionID)
      } else {
        WebImage(
          url: sourceURL,
          options: [.decodeFirstFrameOnly],
          isAnimating: .constant(false)
        ) { image in
          image
            .resizable()
            .scaledToFit()
        } placeholder: {
          placeholderView
        }
        .transition(.fade(duration: 0.18))
      }
    #else
      AsyncImage(url: sourceURL) { phase in
        switch phase {
        case let .success(image):
          image
            .resizable()
            .scaledToFit()
            .transition(.opacity.animation(.easeOut(duration: 0.18)))
        case .empty:
          placeholderView
        case .failure:
          placeholderView
        @unknown default:
          placeholderView
        }
      }
    #endif
  }

  private var placeholderView: some View {
    Color.clear
  }

  private var attachmentID: String {
    "\(url.absoluteString)#\(attachmentInstanceID)"
  }

  private func requestPlayback() {
    playbackController.play(attachmentID)
    startPlaybackOnce(forceRestart: true)
  }

  private func handlePlaybackState(activeAttachmentID: String?) {
    let shouldAnimate = isSupportedAnimatedAsset && activeAttachmentID == attachmentID
    if shouldAnimate {
      startPlaybackOnce()
    } else {
      stopPlayback()
    }
  }

  private func startPlaybackOnce(forceRestart: Bool = false) {
    if isPlaying, !forceRestart { return }
    isPlaying = true
    playbackSessionID = UUID()
    playbackTask?.cancel()
    let duration = min(max(singleLoopDuration, 0.12), 20)
    playbackTask = Task { [duration, attachmentID, playbackController] in
      let delay = UInt64(duration * 1_000_000_000)
      try? await Task.sleep(nanoseconds: delay)
      await MainActor.run {
        stopPlayback()
        playbackController.stop(ifActive: attachmentID)
      }
    }
  }

  private func stopPlayback() {
    guard isPlaying || playbackTask != nil else { return }
    isPlaying = false
    playbackTask?.cancel()
    playbackTask = nil
  }

  private func refreshAnimationMetadata(for sourceURL: URL) async {
    let metadata = await Self.readAnimationMetadata(from: sourceURL)
    await MainActor.run {
      if isSupportedAnimatedAsset != metadata.supported {
        isSupportedAnimatedAsset = metadata.supported
      }
      if singleLoopDuration != metadata.singleLoopDuration {
        singleLoopDuration = metadata.singleLoopDuration
      }
      if !metadata.supported {
        playbackController.stop(ifActive: attachmentID)
      }
    }
  }

  private struct AnimationMetadata: Sendable {
    let supported: Bool
    let singleLoopDuration: TimeInterval
  }

  nonisolated private static func readAnimationMetadata(from sourceURL: URL) async -> AnimationMetadata {
    if sourceURL.isFileURL {
      return await Task.detached(priority: .utility) {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
          return AnimationMetadata(supported: false, singleLoopDuration: 0.6)
        }
        return Self.readAnimationMetadata(from: source)
      }
      .value
    }

    var request = URLRequest(url: sourceURL)
    request.timeoutInterval = 8

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
        return .init(supported: false, singleLoopDuration: 0.6)
      }
      return await Task.detached(priority: .utility) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
          return AnimationMetadata(supported: false, singleLoopDuration: 0.6)
        }
        return Self.readAnimationMetadata(from: source)
      }
      .value
    } catch {
      return .init(supported: false, singleLoopDuration: 0.6)
    }
  }

  nonisolated private static func readAnimationMetadata(from source: CGImageSource) -> AnimationMetadata {
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

  nonisolated private static func frameDelay(from properties: [CFString: Any]) -> TimeInterval {
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

  nonisolated private static func readDelayValue(
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

private enum MarkdownImageDebug {
  private static let enabledKey = "io.ethan.pushgo.MarkdownImageDebug"
  private static let fileURL = URL(fileURLWithPath: "/tmp/pushgo_markdown_image_debug.log")

  static func log(_ message: String) {
    guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
    append("[TextualMarkdownImageView] \(message)")
  }

  static func urlKey(_ url: URL) -> String {
    if !url.lastPathComponent.isEmpty {
      return url.lastPathComponent
    }
    return String(url.absoluteString.suffix(80))
  }

  static func sizeKey(_ size: CGSize) -> String {
    "\(Int(size.width))x\(Int(size.height))"
  }

  private static func append(_ line: String) {
    let entry = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
    let data = Data(entry.utf8)
    if FileManager.default.fileExists(atPath: fileURL.path) == false {
      _ = FileManager.default.createFile(atPath: fileURL.path, contents: data)
      return
    }
    guard let handle = try? FileHandle(forWritingTo: fileURL) else { return }
    defer { try? handle.close() }
    _ = try? handle.seekToEnd()
    try? handle.write(contentsOf: data)
  }
}
