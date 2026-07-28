import SwiftUI

/// NYT Franklin (VFranklin) type ramp used across the app.
enum NYTFont {
    enum Weight {
        case light
        case medium
        case bold

        var postScriptName: String {
            switch self {
            case .light: return "NYTVFranklin-Light"
            case .medium: return "NYTVFranklin-Medium"
            case .bold: return "NYTVFranklin-Bold"
            }
        }
    }

    static func franklin(_ weight: Weight, size: CGFloat) -> Font {
        .custom(weight.postScriptName, fixedSize: size)
    }

    /// Maps common UI weights onto the available Franklin cuts.
    static func franklin(size: CGFloat, weight: SwiftUI.Font.Weight = .regular) -> Font {
        let cut: Weight
        switch weight {
        case .ultraLight, .thin, .light, .regular:
            cut = .light
        case .medium:
            cut = .medium
        default:
            // semibold, bold, heavy, black
            cut = .bold
        }
        return franklin(cut, size: size)
    }
}

extension Font {
    static func nytFranklin(_ weight: NYTFont.Weight, size: CGFloat) -> Font {
        NYTFont.franklin(weight, size: size)
    }

    static func nytFranklin(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        NYTFont.franklin(size: size, weight: weight)
    }
}
