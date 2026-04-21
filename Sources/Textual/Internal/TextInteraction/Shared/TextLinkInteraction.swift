import SwiftUI

// MARK: - Overview
//
// `TextLinkInteraction` adds lightweight link tapping to a `Text` fragment.
//
// SwiftUI resolves a `Text.Layout` for each fragment and publishes it through the `Text.LayoutKey`
// preference. This modifier reads the anchored layout, converts tap locations to layout-local
// coordinates, and looks for the first run whose typographic bounds contains the tap. When a run
// has a `url`, the modifier invokes the environment’s `openURL` action.

struct TextLinkInteraction: ViewModifier {
  @Environment(\.openURL) private var openURL

  func body(content: Content) -> some View {
    #if TEXTUAL_ENABLE_LINKS
      content
        .overlayPreferenceValue(Text.LayoutKey.self) { value in
          if let anchoredLayout = value.first {
            GeometryReader { geometry in
              let hotspots = linkHotspots(
                origin: geometry[anchoredLayout.origin],
                layout: anchoredLayout.layout
              )

              ZStack(alignment: .topLeading) {
                ForEach(hotspots) { hotspot in
                  Color.clear
                    .contentShape(Rectangle())
                    .frame(
                      width: max(hotspot.rect.width, 1),
                      height: max(hotspot.rect.height, 1)
                    )
                    .position(
                      x: hotspot.rect.midX,
                      y: hotspot.rect.midY
                    )
                    .onTapGesture {
                      openURL(hotspot.url)
                    }
                }
              }
            }
          }
        }
    #else
      content
    #endif
  }

  #if TEXTUAL_ENABLE_LINKS
    private struct LinkHotspot: Identifiable {
      let id: Int
      let rect: CGRect
      let url: URL
    }

    private func linkHotspots(origin: CGPoint, layout: Text.Layout) -> [LinkHotspot] {
      layout
        .flatMap(\.self)
        .enumerated()
        .compactMap { index, run in
          guard let url = run.url else {
            return nil
          }

          return LinkHotspot(
            id: index,
            rect: run.typographicBounds.rect.offsetBy(dx: origin.x, dy: origin.y),
            url: url
          )
        }
    }
  #endif
}
