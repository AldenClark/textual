import SwiftUI

#if canImport(SDWebImageSwiftUI)
  import SDWebImageSwiftUI
#endif

@usableFromInline
struct URLBackedImageAttachment: Attachment {
  let url: URL
  let text: String

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
    let width = max(proposal.width ?? 240, 1)
    let clampedWidth = min(width, 960)
    return CGSize(width: clampedWidth, height: clampedWidth * 9.0 / 16.0)
  }
}

private struct URLBackedImageAttachmentView: View {
  @Environment(\.imageAttachmentURLResolver) private var resolver
  @State private var resolvedURL: URL?
  @State private var aspectRatio: CGFloat = 16.0 / 9.0

  let url: URL

  var body: some View {
    contentView(for: resolvedURL ?? url)
      .aspectRatio(max(aspectRatio, .leastNonzeroMagnitude), contentMode: .fit)
      .task(id: url) {
        resolvedURL = await resolver.sourceURL(for: url)
      }
  }

  @ViewBuilder
  private func contentView(for sourceURL: URL) -> some View {
    #if canImport(SDWebImageSwiftUI)
      AnimatedImage(url: sourceURL)
        .indicator(.activity)
        .resizable()
        .onSuccess { image, _, _ in
          updateAspectRatio(using: image)
        }
    #else
      AsyncImage(url: sourceURL) { phase in
        switch phase {
        case let .success(image):
          image
            .resizable()
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

  private func updateAspectRatio(using image: PlatformImage) {
    let size = image.size
    guard size.width > 0, size.height > 0 else { return }
    aspectRatio = size.width / size.height
  }
}
