import SwiftUI

/// Letter / number avatar asset names and their matching background colors
/// (sourced from the Temporary Icons avatar SVGs).
enum AvatarStyle {
    static func assetName(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "BackupAvatar" }

        if first.isLetter {
            return "Avatar\(String(first).uppercased())"
        }
        if first.isNumber {
            return "AvatarNumber"
        }
        return "BackupAvatar"
    }

    static func backgroundColor(for name: String) -> Color {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return Color(hex: 0xD6DEDB)
        }

        if first.isNumber {
            return Color(hex: 0xD6DEDB)
        }
        guard first.isLetter else {
            return Color(hex: 0xD6DEDB)
        }

        switch Character(String(first).uppercased()) {
        case "A", "U": return Color(hex: 0xF8B6B6)
        case "B", "V": return Color(hex: 0xF2C3AF)
        case "C", "W": return Color(hex: 0xEACFA5)
        case "D", "X": return Color(hex: 0xE5DD97)
        case "E", "Y": return Color(hex: 0xE7EDB0)
        case "F", "Z": return Color(hex: 0xDFC6D4)
        case "G": return Color(hex: 0xC8BFD4)
        case "H": return Color(hex: 0xC7D0DF)
        case "I": return Color(hex: 0xC6DCEB)
        case "J": return Color(hex: 0xC6E5EB)
        case "K": return Color(hex: 0xB6E4E0)
        case "L": return Color(hex: 0xB5E5D1)
        case "M": return Color(hex: 0xC1DFC0)
        case "N": return Color(hex: 0xD3E0AB)
        case "O": return Color(hex: 0xD7DEA4)
        case "P": return Color(hex: 0xB5C3BE)
        case "Q": return Color(hex: 0xBDCCBC)
        case "R": return Color(hex: 0xD1D4BD)
        case "S": return Color(hex: 0xDFDECB)
        case "T": return Color(hex: 0xEFECDF)
        default: return Color(hex: 0xD6DEDB)
        }
    }
}
