import Foundation
import OSLog
import SwiftUI

public typealias URLImageAttachmentSizeProvider = @Sendable (URL) async -> CGSize?
public typealias URLImageAttachmentSyncSizeProvider = @Sendable (URL) -> CGSize?

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
  private let syncSizeProvider: URLImageAttachmentSyncSizeProvider?
  public let backend: URLImageAttachmentBackend

  public init(
    relativeTo baseURL: URL? = nil,
    backend: URLImageAttachmentBackend = .textualNative,
    sizeProvider: URLImageAttachmentSizeProvider? = nil,
    syncSizeProvider: URLImageAttachmentSyncSizeProvider? = nil
  ) {
    self.baseURL = baseURL
    self.backend = backend
    self.sizeProvider = sizeProvider
    self.syncSizeProvider = syncSizeProvider
  }

  public func provisionalAttachment(
    for url: URL,
    text: String,
    environment _: ColorEnvironmentValues
  ) -> AdaptiveImageAttachment? {
    let imageURL = URL(string: url.absoluteString, relativeTo: baseURL) ?? url

    switch backend {
    case .textualNative:
      return nil
    case .sdWebImage:
      let intrinsicSize = syncSizeProvider?(imageURL)
      MarkdownImageDebug.log(
        "provisional url=\(MarkdownImageDebug.urlKey(imageURL)) size=\(MarkdownImageDebug.sizeKey(intrinsicSize))"
      )
      return .urlBacked(
        URLBackedImageAttachment(
          url: imageURL,
          text: text,
          intrinsicSize: intrinsicSize
        )
      )
    }
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
      MarkdownImageDebug.log(
        "resolved url=\(MarkdownImageDebug.urlKey(imageURL)) size=\(MarkdownImageDebug.sizeKey(intrinsicSize))"
      )
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

private enum MarkdownImageDebug {
  private static let enabledKey = "io.ethan.pushgo.MarkdownImageDebug"
  private static let logger = Logger(
    subsystem: "com.github.gonzalezreal.Textual",
    category: "markdownImage"
  )

  static func log(_ message: String) {
    guard UserDefaults.standard.bool(forKey: enabledKey) else { return }
    logger.debug("\(message, privacy: .public)")
  }

  static func urlKey(_ url: URL) -> String {
    if !url.lastPathComponent.isEmpty {
      return url.lastPathComponent
    }
    return String(url.absoluteString.suffix(80))
  }

  static func sizeKey(_ size: CGSize?) -> String {
    guard let size else { return "nil" }
    return "\(Int(size.width))x\(Int(size.height))"
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
    sizeProvider: URLImageAttachmentSizeProvider? = nil,
    syncSizeProvider: URLImageAttachmentSyncSizeProvider? = nil
  ) -> Self {
    .init(
      relativeTo: baseURL,
      backend: backend,
      sizeProvider: sizeProvider,
      syncSizeProvider: syncSizeProvider
    )
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
