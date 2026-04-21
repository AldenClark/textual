import Foundation
import Testing

@testable import Textual

struct ImageAttachmentURLResolverTests {
  @Test
  func passthroughResolverFallsBackToOriginalURL() async {
    let originalURL = URL(string: "https://example.com/sample.webp")!
    let resolver = ImageAttachmentURLResolver { _ in nil }

    await #expect(resolver.resolvedSourceURL(for: originalURL) == originalURL)
    await #expect(resolver.sourceURL(for: originalURL) == originalURL)
  }

  @Test
  func strictResolverDoesNotFallbackToOriginalURL() async {
    let originalURL = URL(string: "https://example.com/sample.gif")!
    let resolver = ImageAttachmentURLResolver.strict { _ in nil }

    await #expect(resolver.resolvedSourceURL(for: originalURL) == nil)
    await #expect(resolver.sourceURL(for: originalURL) == originalURL)
  }

  @Test
  func strictResolverUsesResolvedLocalURL() async {
    let originalURL = URL(string: "https://example.com/sample.apng")!
    let localURL = URL(filePath: "/tmp/sample.apng")
    let resolver = ImageAttachmentURLResolver.strict { _ in localURL }

    await #expect(resolver.resolvedSourceURL(for: originalURL) == localURL)
    await #expect(resolver.sourceURL(for: originalURL) == localURL)
  }
}
