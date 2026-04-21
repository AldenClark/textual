import Foundation

/// Handles tap interactions for rendered image attachments.
public struct ImageAttachmentTapAction {
  private let action: (URL) -> Void

  public init(_ action: @escaping (URL) -> Void) {
    self.action = action
  }

  func callAsFunction(_ url: URL) {
    action(url)
  }
}

