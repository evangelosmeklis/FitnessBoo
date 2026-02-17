//
//  DesignColors.swift
//  FitnessBoo
//
//  Created by Antigravity on 4/1/26.
//

import SwiftUI
import UIKit

extension Color {
    // MARK: - Whoop-Inspired Palette
    
    /// Core blue accents
    static let premiumBlue = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0) :
            UIColor(red: 0.47, green: 0.75, blue: 1.0, alpha: 1.0)
    })
    
    /// Teal highlight for progress/positive states
    static let premiumMint = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.0, green: 0.85, blue: 0.75, alpha: 1.0) :
            UIColor(red: 0.0, green: 1.0, blue: 0.88, alpha: 1.0)
    })
    
    /// Green accent for secondary metrics
    static let premiumTeal = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.18, green: 0.85, blue: 0.51, alpha: 1.0) :
            UIColor(red: 0.34, green: 1.0, blue: 0.64, alpha: 1.0)
    })
    
    /// Warm accent for alerts/calories
    static let premiumCoral = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 1.0, green: 0.42, blue: 0.21, alpha: 1.0) :
            UIColor(red: 1.0, green: 0.55, blue: 0.26, alpha: 1.0)
    })
    
    /// Primary action color
    static let premiumIndigo = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.47, green: 0.75, blue: 1.0, alpha: 1.0) :
            UIColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0)
    })
    
    /// Aqua accent for calm metrics
    static let premiumSky = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.0, green: 1.0, blue: 0.88, alpha: 1.0) :
            UIColor(red: 0.0, green: 0.85, blue: 0.75, alpha: 1.0)
    })
    
    /// Main background - dark charcoal like Whoop
    static let premiumMainBackground = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.11, green: 0.12, blue: 0.13, alpha: 1.0) :
            UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1.0)
    })

    /// Layered surfaces - card backgrounds
    static let premiumCardBackground = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1.0) :
            UIColor(white: 1.0, alpha: 1.0)
    })

    static let premiumElevatedBackground = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.19, green: 0.20, blue: 0.22, alpha: 1.0) :
            UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1.0)
    })

    static let premiumBorder = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.25, green: 0.27, blue: 0.29, alpha: 1.0) :
            UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
    })
    
    /// Text tones - adaptive for light and dark
    static let premiumTextPrimary = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.95, green: 0.96, blue: 0.97, alpha: 1.0) :
            UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0)
    })

    static let premiumTextSecondary = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.60, green: 0.62, blue: 0.65, alpha: 1.0) :
            UIColor(red: 0.45, green: 0.45, blue: 0.47, alpha: 1.0)
    })

    static let premiumTextTertiary = Color(UIColor { trait in
        return trait.userInterfaceStyle == .dark ?
            UIColor(red: 0.48, green: 0.50, blue: 0.54, alpha: 1.0) :
            UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1.0)
    })
    
    // MARK: - Gradients
    
    static let primaryGradient = LinearGradient(
        colors: [Color.premiumMint, Color.premiumBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color.premiumTeal, Color.premiumMint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Premium Glass Background Modifier

struct PremiumGlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.premiumCardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                Color.premiumBorder.opacity(colorScheme == .dark ? 0.5 : 0.3),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: colorScheme == .dark ?
                    Color.black.opacity(0.4) :
                    Color.black.opacity(0.08),
                radius: colorScheme == .dark ? 10 : 6,
                x: 0,
                y: colorScheme == .dark ? 5 : 2
            )
    }
}

extension View {
    /// Applies a premium glass background effect
    func premiumGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(PremiumGlassBackground(cornerRadius: cornerRadius))
    }
    
    /// Adds a subtle premium sheen instead of a neon glow
    func premiumSheen(color: Color, opacity: Double = 0.3) -> some View {
        self.shadow(color: color.opacity(opacity), radius: 8, x: 0, y: 0)
    }
}
