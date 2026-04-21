import Foundation

/// Resolves a remote image URL to a preferred source URL before rendering.
///
/// Use this resolver to redirect attachment image loading to an app-managed source, such as a
/// pre-fetched local file URL from a shared cache.
public struct ImageAttachmentURLResolver: Sendable {
  public typealias Resolve = @Sendable (URL) async -> URL?

  private let resolve: Resolve?
  private let fallsBackToOriginalURL: Bool

  /// Creates a resolver.
  ///
  /// - Parameter resolve: Returns an alternate source URL for the input URL. Return `nil` to keep
  ///   the original URL when `fallbackToOriginalURL` is `true`.
  /// - Parameter fallbackToOriginalURL: Whether to keep the original URL when resolver returns
  ///   `nil`. Defaults to `true` for backward compatibility.
  public init(
    _ resolve: Resolve? = nil,
    fallbackToOriginalURL: Bool = true
  ) {
    self.resolve = resolve
    self.fallsBackToOriginalURL = fallbackToOriginalURL
  }

  /// Resolves a URL to the preferred source URL.
  ///
  /// Returns `nil` when resolver returns `nil` and fallback-to-original is disabled.
  public func resolvedSourceURL(for url: URL) async -> URL? {
    if let resolved = await resolve?(url) {
      return resolved
    }
    return fallsBackToOriginalURL ? url : nil
  }

  /// Resolves a URL to the preferred source URL.
  public func sourceURL(for url: URL) async -> URL {
    await resolvedSourceURL(for: url) ?? url
  }

  /// A resolver that does not fall back to the original URL.
  public static func strict(_ resolve: Resolve? = nil) -> Self {
    .init(resolve, fallbackToOriginalURL: false)
  }

  /// A resolver that keeps the original URL.
  public static let passthrough = Self(nil)
}
