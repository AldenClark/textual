import Foundation

#if canImport(SDWebImage)
  import SDWebImage
#endif

enum SDWebImageAnimatedCoders {
  static func bootstrapIfNeeded() {
    #if canImport(SDWebImage)
      _ = didBootstrap
    #endif
  }

  #if canImport(SDWebImage)
    private static let didBootstrap: Void = {
      let manager = SDImageCodersManager.shared

      // Keep GIF/APNG/WebP animated coders explicitly registered so animated playback
      // is deterministic even when static image paths are loaded first.
      registerIfNeeded(SDImageGIFCoder.shared, into: manager)
      registerIfNeeded(SDImageAPNGCoder.shared, into: manager)
      registerIfNeeded(SDImageAWebPCoder.shared, into: manager)
    }()

    private static func registerIfNeeded(_ coder: any SDImageCoder, into manager: SDImageCodersManager) {
      let isAlreadyRegistered = (manager.coders ?? []).contains { existing in
        String(reflecting: type(of: existing)) == String(reflecting: type(of: coder))
      }
      if !isAlreadyRegistered {
        manager.addCoder(coder)
      }
    }
  #endif
}
