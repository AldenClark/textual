import SwiftUI

public typealias URLImageAttachmentSizeProvider = @Sendable (URL) async -> CGSize?

/// Backend mode for URL-based image attachment rendering.
public enum URLImageAttachmentBackend: String, CaseIterable, Sendable {
  /// Decodes image frames with Textual's built-in image pipeline.
  case textualNative

  /// Uses a URL-backed attachment view powered by SDWebImage's animated renderer.
  case sdWebImage
}

/// Attachment loader for URL-based markdown images with selectable backends.
///
/// Use this loader when you want to switch image rendering behavior without replacing Textual's
/// markdown parsing and layout pipeline.
public struct AdaptiveURLImageAttachmentLoader: AttachmentLoader {
  public typealias Attachment = AdaptiveImageAttachment

  private let baseURL: URL?
  private let sizeProvider: URLImageAttachmentSizeProvider?
  public let backend: URLImageAttachmentBackend

  public init(
    relativeTo baseURL: URL? = nil,
    backend: URLImageAttachmentBackend = .textualNative,
    sizeProvider: URLImageAttachmentSizeProvider? = nil
  ) {
    self.baseURL = baseURL
    self.backend = backend
    self.sizeProvider = sizeProvider
  }

  public func attachment(
    for url: URL,
    text: String,
    environment _: ColorEnvironmentValues
  ) async throws -> AdaptiveImageAttachment {
    let imageURL = URL(string: url.absoluteString, relativeTo: baseURL) ?? url

    switch backend {
    case .textualNative:
      let image = try await ImageLoader.shared.image(for: imageURL)
      return .decoded(ImageAttachment(image: image, text: text))
    case .sdWebImage:
      let intrinsicSize = await sizeProvider?(imageURL)
      return .urlBacked(
        URLBackedImageAttachment(
          url: imageURL,
          text: text,
          intrinsicSize: intrinsicSize
        )
      )
    }
  }
}

extension AttachmentLoader where Self == AdaptiveURLImageAttachmentLoader {
  /// Loads markdown images using the selected backend.
  ///
  /// - Parameters:
  ///   - baseURL: Base URL used to resolve relative image URLs.
  ///   - backend: Rendering backend for resolved image URLs.
  public static func adaptiveImage(
    relativeTo baseURL: URL? = nil,
    backend: URLImageAttachmentBackend = .textualNative,
    sizeProvider: URLImageAttachmentSizeProvider? = nil
  ) -> Self {
    .init(relativeTo: baseURL, backend: backend, sizeProvider: sizeProvider)
  }
}

/// Wrapper attachment used by `AdaptiveURLImageAttachmentLoader`.
public struct AdaptiveImageAttachment: Attachment {
  private enum Storage: Hashable {
    case decoded(ImageAttachment)
    case urlBacked(URLBackedImageAttachment)
  }

  private let storage: Storage

  fileprivate static func decoded(_ attachment: ImageAttachment) -> Self {
    .init(storage: .decoded(attachment))
  }

  fileprivate static func urlBacked(_ attachment: URLBackedImageAttachment) -> Self {
    .init(storage: .urlBacked(attachment))
  }

  private init(storage: Storage) {
    self.storage = storage
  }

  public var description: String {
    switch storage {
    case let .decoded(attachment):
      attachment.description
    case let .urlBacked(attachment):
      attachment.description
    }
  }

  @ViewBuilder
  public var body: some View {
    switch storage {
    case let .decoded(attachment):
      attachment.body
    case let .urlBacked(attachment):
      attachment.body
    }
  }

  public func sizeThatFits(
    _ proposal: ProposedViewSize,
    in environment: TextEnvironmentValues
  ) -> CGSize {
    switch storage {
    case let .decoded(attachment):
      attachment.sizeThatFits(proposal, in: environment)
    case let .urlBacked(attachment):
      attachment.sizeThatFits(proposal, in: environment)
    }
  }

  public func pngData() -> Data? {
    switch storage {
    case let .decoded(attachment):
      attachment.pngData()
    case let .urlBacked(attachment):
      attachment.pngData()
    }
  }
}
