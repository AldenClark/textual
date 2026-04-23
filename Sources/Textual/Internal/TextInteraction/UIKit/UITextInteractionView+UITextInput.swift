#if TEXTUAL_ENABLE_TEXT_SELECTION && canImport(UIKit)
  import SwiftUI

  extension UITextInteractionView: UITextInput {
    var hasText: Bool {
      model.hasText
    }

    func insertText(_: String) {
      // Do nothing
    }

    func deleteBackward() {
      // Do nothing
    }

    func text(in range: UITextRange) -> String? {
      guard let rangeBox = range as? TextRangeBox else { return nil }
      guard let clampedRange = model.clamped(rangeBox.wrappedValue) else {
        return nil
      }
      return model.text(in: clampedRange)
    }

    func replace(_ range: UITextRange, withText text: String) {
      // Do nothing
    }

    var selectedTextRange: UITextRange? {
      get { model.selectedRange.map(TextRangeBox.init) }
      set {
        let rangeBox = newValue as? TextRangeBox
        if let range = rangeBox?.wrappedValue {
          model.selectedRange = model.clamped(range)
        } else {
          model.selectedRange = nil
        }
        logger.debug("selectedTextRange = \(newValue)")
      }
    }

    var markedTextRange: UITextRange? {
      nil
    }

    var markedTextStyle: [NSAttributedString.Key: Any]? {
      get { nil }
      set {}
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
      // Do nothing
    }

    func unmarkText() {
      // Do nothing
    }

    var beginningOfDocument: UITextPosition {
      TextPositionBox(model.startPosition)
    }

    var endOfDocument: UITextPosition {
      TextPositionBox(model.endPosition)
    }

    func textRange(
      from fromPosition: UITextPosition,
      to toPosition: UITextPosition
    ) -> UITextRange? {
      guard
        let from = fromPosition as? TextPositionBox,
        let to = toPosition as? TextPositionBox
      else {
        return nil
      }
      guard
        let clampedFrom = model.clamped(from.wrappedValue),
        let clampedTo = model.clamped(to.wrappedValue)
      else {
        return nil
      }
      return TextRangeBox(TextRange(from: clampedFrom, to: clampedTo))
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
      guard let positionBox = position as? TextPositionBox else { return nil }
      guard let clampedPosition = model.clamped(positionBox.wrappedValue) else { return nil }
      return model.position(
        from: clampedPosition,
        offset: offset
      ).map(TextPositionBox.init)
    }

    func position(
      from position: UITextPosition,
      in direction: UITextLayoutDirection,
      offset: Int
    ) -> UITextPosition? {
      logger.error("position(from:in:offset:) is not implemented")
      return nil
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
      guard
        let lhs = position as? TextPositionBox, let rhs = other as? TextPositionBox,
        lhs.wrappedValue != rhs.wrappedValue
      else {
        return .orderedSame
      }
      return lhs.wrappedValue < rhs.wrappedValue ? .orderedAscending : .orderedDescending
    }

    func offset(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> Int {
      guard
        let from = fromPosition as? TextPositionBox,
        let to = toPosition as? TextPositionBox
      else { return 0 }
      guard
        let clampedFrom = model.clamped(from.wrappedValue),
        let clampedTo = model.clamped(to.wrappedValue)
      else {
        return 0
      }
      return model.offset(from: clampedFrom, to: clampedTo)
    }

    var tokenizer: any UITextInputTokenizer {
      self
    }

    func position(
      within range: UITextRange,
      farthestIn direction: UITextLayoutDirection
    ) -> UITextPosition? {
      logger.error("position(within:farthestIn:) is not implemented")
      return nil
    }

    func characterRange(
      byExtending position: UITextPosition,
      in direction: UITextLayoutDirection
    ) -> UITextRange? {
      logger.error("characterRange(byExtending:in:) is not implemented")
      return nil
    }

    func baseWritingDirection(
      for position: UITextPosition,
      in direction: UITextStorageDirection
    ) -> NSWritingDirection {
      // Not applicable for non-editable interaction mode?
      return .natural
    }

    func setBaseWritingDirection(_: NSWritingDirection, for _: UITextRange) {
      // Do nothing
    }

    func firstRect(for range: UITextRange) -> CGRect {
      guard let rangeBox = range as? TextRangeBox else { return .zero }
      guard let clampedRange = model.clamped(rangeBox.wrappedValue) else { return .zero }
      return model.firstRect(for: clampedRange)
    }

    func caretRect(for position: UITextPosition) -> CGRect {
      guard let positionBox = position as? TextPositionBox else { return .zero }
      guard let clampedPosition = model.clamped(positionBox.wrappedValue) else { return .zero }
      return model.caretRect(for: clampedPosition)
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
      guard let rangeBox = range as? TextRangeBox else { return [] }
      guard let clampedRange = model.clamped(rangeBox.wrappedValue) else { return [] }
      return model.selectionRects(for: clampedRange)
        .map(TextSelectionRectBox.init)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
      model.closestPosition(to: point).map(TextPositionBox.init)
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
      guard let rangeBox = range as? TextRangeBox else { return nil }
      guard let clampedRange = model.clamped(rangeBox.wrappedValue) else { return nil }
      return model.closestPosition(
        to: point,
        within: clampedRange
      ).map(TextPositionBox.init)
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
      model.characterRange(at: point).map(TextRangeBox.init)
    }

    var textInputView: UIView {
      self
    }

    var isEditable: Bool {
      false
    }

    func attributedText(in range: UITextRange) -> NSAttributedString {
      guard let rangeBox = range as? TextRangeBox else { return .init() }
      guard let clampedRange = model.clamped(rangeBox.wrappedValue) else { return .init() }
      return model.attributedText(in: clampedRange)
    }
  }
#endif
