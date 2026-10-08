import SwiftUI

enum TempoPalette {
  static let background = Color.adaptive(lightHex: 0xF7F9FC, darkHex: 0x000000)
  static let secondaryBackground = Color.adaptive(lightHex: 0xEEF3F8, darkHex: 0x07090D)
  static let surface = Color.adaptive(lightHex: 0xFFFFFF, darkHex: 0x0C0F14)
  static let elevatedSurface = Color.adaptive(lightHex: 0xFFFFFF, darkHex: 0x151A21)
  static let ink = Color.adaptive(lightHex: 0x05070A, darkHex: 0xF5F7FA)
  static let quiet = Color.adaptive(lightHex: 0x606A76, darkHex: 0xA7AFBA)
  static let faint = Color.adaptive(lightHex: 0x98A1AC, darkHex: 0x68727F)
  static let separator = Color.adaptive(lightHex: 0xDCE2E9, darkHex: 0x2A303A)
  static let accent = Color.adaptive(
    lightHex: 0x1D7FF2,
    darkHex: 0x1D7FF2
  )
  static let onAccent = Color.white
  static let selected = Color.adaptive(
    lightHex: 0xE8F2FF,
    darkHex: 0x0B315D
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
  static let screenTitle = Font.system(.largeTitle, design: .default).weight(.heavy)
  static let sectionTitle = Font.system(.title3, design: .default).weight(.bold)
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
  func tempoSearchSurface() -> some View {
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
