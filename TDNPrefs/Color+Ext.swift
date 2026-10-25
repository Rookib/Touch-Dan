import SwiftUI

let TDN_UICOLOR = UIColor(red: 235.0 / 255, green: 59.0 / 255, blue: 90.0 / 255, alpha: 1.0)
let TDN_COLOR = Color(TDN_UICOLOR)

extension Color {
    init(rgbString: String) {
        let tokens = rgbString.split(separator: ",", omittingEmptySubsequences: false)
        let components = tokens.compactMap { Double($0) }
        guard (3...4).contains(tokens.count), components.count == tokens.count,
              components.allSatisfy({ $0.isFinite }) else {
            self = .clear
            return
        }
        self.init(.sRGB,
                  red: min(max(components[0], 0), 255) / 255,
                  green: min(max(components[1], 0), 255) / 255,
                  blue: min(max(components[2], 0), 255) / 255,
                  opacity: components.count == 4 ? min(max(components[3], 0), 1) : 1)
    }

    func toRGBString() -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "0,0,0,0"
        }
        func channel(_ value: CGFloat) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
        return "\(channel(red)),\(channel(green)),\(channel(blue)),\(min(max(alpha, 0), 1))"
    }
}
