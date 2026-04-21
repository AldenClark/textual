import Combine

/// Coordinates inline animated image playback so only one attachment plays at a time.
public final class ImageAttachmentPlaybackController: ObservableObject {
  @Published public private(set) var activeAttachmentID: String?

  public init(activeAttachmentID: String? = nil) {
    self.activeAttachmentID = activeAttachmentID
  }

  public func play(_ attachmentID: String) {
    activeAttachmentID = attachmentID
  }

  public func stop() {
    activeAttachmentID = nil
  }

  public func stop(ifActive attachmentID: String) {
    guard activeAttachmentID == attachmentID else { return }
    activeAttachmentID = nil
  }
}

