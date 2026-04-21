import SwiftUI
import Textual

struct InlineTextDemo: View {
  var body: some View {
    Form {
      Section("Images") {
        InlineText(
          markdown: """
            This is a *lighthearted* but **perfectly serious** paragraph where `inline code` lives \
            happily alongside ~~a terrible idea~~ a better one, a [useful link](https://example.com), \
            and a bit of _extra emphasis_ just for style. To keep things interesting without overdoing \
            it, here’s a completely random image that adapts to the container width:

            ![Random image](https://picsum.photos/seed/textual/400/250)
            """
        )
        .textual.textSelection(.enabled)
      }
      Section("Custom Emoji") {
        InlineText(
          markdown: """
            **Working late on the new feature** has been surprisingly fun—_even when the build \
            fails_ :confused_dog:, a quick refactor usually gets things back on track :doge:, \
            and when it doesn’t, I just roll with it :dogroll: until the solution finally \
            clicks (though sometimes I still end up a bit **:confused_dog:** or _small \
            :confused_dog:_... plus another :confused_dog: for good measure).
            """,
          syntaxExtensions: [.emoji(.mastoEmoji)]
        )
        .textual.inlineStyle(
          InlineStyle()
            .strong(.bold, .fontScale(1.3))
            .emphasis(.italic, .fontScale(0.85))
        )
      }
      Section("Custom Inline Style") {
        InlineText(
          markdown: """
            This is a *lighthearted* but **perfectly serious** paragraph where `inline code` lives \
            happily alongside ~~a terrible idea~~ a better one, a [useful link](https://example.com), \
            and a bit of _extra emphasis_ just for style.
            """
        )
        .textual.inlineStyle(.custom)
      }
      Section("Interactive Pill Attachments") {
        PillDemoView()
      }
      Section("Highlight Effect") {
        HighlightEffectDemo()
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Pill Demo View

struct PillDemoView: View {
  var body: some View {
    InlineText("pills", parser: PillDemoParser())
      .attachmentRenderingMode(.canvas)  // Use canvas - pills render correctly as images
      .environment(\.openURL, OpenURLAction { url in
        print("🎯 Pill tapped: \(url)")
        if url.scheme == "citation" {
          print("   ✅ Citation link detected!")
          if let host = url.host, let index = Int(host) {
            print("   📍 Citation index: \(index)")
          }
          return .handled
        }
        return .systemAction
      })
  }
}

// MARK: - Pill Demo Parser

@MainActor
struct PillDemoParser: MarkupParser {
  func attributedString(for input: String) throws -> AttributedString {
    var text = AttributedString("This paragraph demonstrates inline ")

    // Add first pill - attachment for visual + link for tap handling
    var pill1 = AttributedString("\u{FFFC}")  // Object replacement character for attachment
    pill1.textual.attachment = AnyAttachment(
      PillAttachment(text: "PubMed", onTap: nil)  // Don't need onTap, link handles it
    )
    pill1.link = URL(string: "citation://0")  // Link makes it tappable
    text.append(pill1)

    text.append(AttributedString(" and "))

    // Add second pill
    var pill2 = AttributedString("\u{FFFC}")
    pill2.textual.attachment = AnyAttachment(
      PillAttachment(text: "NICE", onTap: nil)
    )
    pill2.link = URL(string: "citation://1")
    text.append(pill2)

    text.append(AttributedString(" interactive pill attachments flowing naturally with the text, even when the text wraps to multiple lines."))

    return text
  }
}

struct HighlightEffectDemo: View {
  @State private var progress: CGFloat = 0

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      InlineText(
        markdown: """
          This demonstrates the **animated highlighter** effect. Watch how the \
          **important text** gets highlighted with a smooth animation, making it \
          easy to draw attention to **key information** in your content.
          """
      )
      .textual.inlineStyle(
        InlineStyle()
          .strong(EffectProperty(AnimatableEffectMarker<HighlightEffect>()))
      )
      .textual.animatableEffect(HighlightEffect(
        color: .yellow,
        animationProgress: progress
      ))
      .onAppear {
        startAnimation()
      }

      Button("Replay Animation") {
        startAnimation()
      }
    }
  }

  private func startAnimation() {
    progress = 0
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      withAnimation {
        progress = 1
      }
    }
  }
}

extension InlineStyle {
  fileprivate static var custom: InlineStyle {
    InlineStyle()
      .code(
        .monospaced,
        .fontScale(0.85),
        .backgroundColor(.purple),
        .foregroundColor(.white)
      )
      .emphasis(.italic, .underlineStyle(.single))
      .strikethrough(.foregroundColor(.secondary))
      .link(.foregroundColor(.purple), .underlineStyle(.init(pattern: .dot)))
  }
}

#Preview {
  InlineTextDemo()
}

// MARK: - HighlightEffect

/// An animated highlighter pen effect for text.
struct HighlightEffect: TextRunEffect {
  var color: Color
  var animationProgress: CGFloat
  var verticalOffset: CGFloat
  var heightRatio: CGFloat

  init(
    color: Color = .yellow,
    animationProgress: CGFloat = 1.0,
    verticalOffset: CGFloat = 0.5,
    heightRatio: CGFloat = 0.6
  ) {
    self.color = color
    self.animationProgress = animationProgress
    self.verticalOffset = verticalOffset
    self.heightRatio = heightRatio
  }

  public var animatableData: CGFloat {
    get { animationProgress }
    set { animationProgress = newValue }
  }

  func draw(run: Text.Layout.Run, in context: inout GraphicsContext) {
    let bounds = run.typographicBounds.rect

    let highlightHeight = bounds.height * heightRatio
    let highlightY = bounds.minY + (bounds.height - highlightHeight) * verticalOffset

    let highlightRect = CGRect(
      x: bounds.minX,
      y: highlightY,
      width: bounds.width * animationProgress,
      height: highlightHeight
    )

    let gradient = Gradient(colors: [
      color.opacity(0.2),
      color.opacity(0.5),
      color.opacity(0.3)
    ])

    context.fill(
      Path(roundedRect: highlightRect, cornerRadius: 8),
      with: .linearGradient(
        gradient,
        startPoint: CGPoint(x: highlightRect.minX, y: highlightRect.minY),
        endPoint: CGPoint(x: highlightRect.maxX, y: highlightRect.maxY)
      )
    )
  }
}
