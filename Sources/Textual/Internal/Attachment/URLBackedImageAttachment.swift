import SwiftUI

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
  @State private var resolvedURL: URL?

  let url: URL

  var body: some View {
    contentView(for: resolvedURL ?? url)
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
}
