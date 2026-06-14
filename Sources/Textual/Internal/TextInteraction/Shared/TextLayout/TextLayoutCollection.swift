#if TEXTUAL_ENABLE_TEXT_SELECTION
  import SwiftUI

  extension Collection {
    subscript(safe index: Index) -> Element? {
      indices.contains(index) ? self[index] : nil
    }
  }

  protocol TextLayoutCollection {
    var layouts: [any TextLayout] { get }

    func isEqual(to other: any TextLayoutCollection) -> Bool
    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool
    func index(of layout: Text.Layout) -> Int?
  }

  struct AnyTextLayoutCollection: TextLayoutCollection, Equatable {
    private let base: any TextLayoutCollection

    init(_ base: any TextLayoutCollection) {
      self.base = base
    }

    var layouts: [any TextLayout] {
      base.layouts
    }

    func isEqual(to other: any TextLayoutCollection) -> Bool {
      base.isEqual(to: other)
    }

    func needsPositionReconciliation(with other: any TextLayoutCollection) -> Bool {
      base.needsPositionReconciliation(with: other)
    }

    func index(of layout: Text.Layout) -> Int? {
      base.index(of: layout)
    }

    static func == (lhs: AnyTextLayoutCollection, rhs: AnyTextLayoutCollection) -> Bool {
      lhs.isEqual(to: rhs.base)
    }
  }

  protocol TextLayout {
    var attributedString: NSAttributedString { get }
    var origin: CGPoint { get }
    var bounds: CGRect { get }
    var lines: [any TextLine] { get }
  }

  extension TextLayout {
    var frame: CGRect {
      bounds.offsetBy(dx: origin.x, dy: origin.y)
    }

    var runs: [any TextRun] {
      lines.flatMap(\.runs)
    }
  }

  protocol TextLine {
    var origin: CGPoint { get }
    var typographicBounds: CGRect { get }
    var runs: [any TextRun] { get }
  }

  protocol TextRun {
    var layoutDirection: LayoutDirection { get }
    var typographicBounds: CGRect { get }
    var url: URL? { get }
    var slices: [any TextRunSlice] { get }
  }

  protocol TextRunSlice {
    var typographicBounds: CGRect { get }
    var characterRange: Range<Int> { get }
  }

  extension TextLayoutCollection {
    func layout(at index: Int) -> (any TextLayout)? {
      layouts[safe: index]
    }

    func line(at indexPath: IndexPath) -> (any TextLine)? {
      layout(at: indexPath.layout)?.lines[safe: indexPath.line]
    }

    func run(at indexPath: IndexPath) -> (any TextRun)? {
      line(at: indexPath)?.runs[safe: indexPath.run]
    }

    func runSlice(at indexPath: IndexPath) -> (any TextRunSlice)? {
      run(at: indexPath)?.slices[safe: indexPath.runSlice]
    }
  }

#endif
