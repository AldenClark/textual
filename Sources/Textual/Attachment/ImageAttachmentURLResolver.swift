import Foundation

/// Resolves a remote image URL to a preferred source URL before rendering.
///
/// Use this resolver to redirect attachment image loading to an app-managed source, such as a
/// pre-fetched local file URL from a shared cache.
public struct ImageAttachmentURLResolver: Sendable {
  public typealias Resolve = @Sendable (URL) async -> URL?

  private let resolve: Resolve?

  /// Creates a resolver.
  ///
  /// - Parameter resolve: Returns an alternate source URL for the input URL. Return `nil` to keep
  ///   the original URL.
  public init(_ resolve: Resolve? = nil) {
    self.resolve = resolve
  }

  /// Resolves a URL to the preferred source URL.
  public func sourceURL(for url: URL) async -> URL {
    await resolve?(url) ?? url
  }

  /// A resolver that keeps the original URL.
  public static let passthrough = Self(nil)
}
