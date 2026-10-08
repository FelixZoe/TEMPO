import SwiftUI

enum TempoPalette {
  #if os(iOS)
  static let background = Color(uiColor: .systemBackground)
  static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
  static let surface = Color(uiColor: .secondarySystemBackground)
  static let elevatedSurface = Color(uiColor: .tertiarySystemBackground)
  static let ink = Color(uiColor: .label)
  static let quiet = Color(uiColor: .secondaryLabel)
  static let faint = Color(uiColor: .tertiaryLabel)
  static let separator = Color(uiColor: .separator)
  #else
  static let background = Color(nsColor: .windowBackgroundColor)
  static let secondaryBackground = Color(nsColor: .underPageBackgroundColor)
  static let surface = Color(nsColor: .controlBackgroundColor)
  static let elevatedSurface = Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
  static let ink = Color(nsColor: .labelColor)
  static let quiet = Color(nsColor: .secondaryLabelColor)
  static let faint = Color(nsColor: .tertiaryLabelColor)
  static let separator = Color(nsColor: .separatorColor)
  #endif
  static let accent = Color.adaptive(
    lightHex: 0x3268E8,
    darkHex: 0x7EA7FF
  )
  static let onAccent = Color.white
  static let selected = Color.adaptive(
    lightHex: 0xE9EFFD,
    darkHex: 0x26324B
  )
  static let success = Color.adaptive(
    lightHex: 0x2E7D64,
    darkHex: 0x65BFA1
  )
  static let warning = Color.adaptive(
    lightHex: 0x7A6640,
    darkHex: 0xC9AE72
  )
  static let danger = Color.adaptive(
    lightHex: 0xA3484F,
    darkHex: 0xD9898F
  )
  static let scrim = Color.adaptive(
    lightHex: 0x161925,
    darkHex: 0x000000
  )

  static let canvasGradient = LinearGradient(
    colors: [background, background],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )

  static let actionGradient = LinearGradient(
    colors: [accent, accent.opacity(0.90)],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

enum TempoType {
  static let screenTitle = Font.largeTitle.weight(.bold)
  static let sectionTitle = Font.title3.weight(.semibold)
  static let rowTitle = Font.body.weight(.semibold)
  static let rowTitleCompleted = Font.body
  static let body = Font.body
  static let metadata = Font.caption
}

extension Color {
  static func adaptive(
    lightHex: UInt32,
    darkHex: UInt32
  ) -> Color {
    #if os(iOS)
    Color(UIColor { traits in
      UIColor(hex: traits.userInterfaceStyle == .dark ? darkHex : lightHex)
    })
    #else
    Color(NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return NSColor(hex: isDark ? darkHex : lightHex)
    })
    #endif
  }
}

#if os(iOS)
private extension UIColor {
  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}
#else
private extension NSColor {
  convenience init(hex: UInt32) {
    self.init(
      red: CGFloat((hex >> 16) & 0xFF) / 255,
      green: CGFloat((hex >> 8) & 0xFF) / 255,
      blue: CGFloat(hex & 0xFF) / 255,
      alpha: 1
    )
  }
}
#endif

private struct TempoScreenBackground: ViewModifier {
  func body(content: Content) -> some View {
    content
      .scrollContentBackground(.hidden)
      .background(TempoPalette.canvasGradient.ignoresSafeArea())
      .tint(TempoPalette.accent)
  }
}

extension View {
  func tempoScreen() -> some View { modifier(TempoScreenBackground()) }

  @ViewBuilder
  func tempoFloatingSurface() -> some View {
    #if os(iOS)
    if #available(iOS 26.0, *) {
      self.glassEffect(.regular.interactive(), in: .circle)
    } else {
      self.background(.ultraThinMaterial, in: Circle())
    }
    #else
    self.background(.ultraThinMaterial, in: Circle())
    #endif
  }

  @ViewBuilder
  func tempoFloatingCapsule() -> some View {
    #if os(iOS)
    if #available(iOS 26.0, *) {
      self.glassEffect(.regular.interactive(), in: .capsule)
    } else {
      self.background(.ultraThinMaterial, in: Capsule())
    }
    #else
    self.background(.ultraThinMaterial, in: Capsule())
    #endif
  }
}
