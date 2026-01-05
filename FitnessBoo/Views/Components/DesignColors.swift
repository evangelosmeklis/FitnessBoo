//
//  DesignColors.swift
//  FitnessBoo
//
//  Created by Antigravity on 4/1/26.
//

import SwiftUI

extension Color {
    // MARK: - Premium Color Palette
    
    /// Deep Royal Blue -> Light Blue Gradient Start
    static let premiumBlue = Color(red: 0.05, green: 0.2, blue: 0.9)
    
    /// Fresh Mint - for positive indicators (replaces neon green)
    static let premiumMint = Color(red: 0.2, green: 0.9, blue: 0.7)
    
    /// Deep Teal - for accents
    static let premiumTeal = Color(red: 0.0, green: 0.5, blue: 0.6)
    
    /// Soft Coral - for warm accents/calories
    static let premiumCoral = Color(red: 1.0, green: 0.45, blue: 0.35)
    
    /// Electric Indigo - for primary actions
    static let premiumIndigo = Color(red: 0.35, green: 0.3, blue: 1.0)
    
    /// Sky Blue - for calm metrics
    static let premiumSky = Color(red: 0.4, green: 0.7, blue: 1.0)
    
    // MARK: - Gradients
    
    static let primaryGradient = LinearGradient(
        colors: [Color.premiumIndigo, Color.premiumBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let accentGradient = LinearGradient(
        colors: [Color.premiumMint, Color.premiumTeal],
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
                    .fill(
                        colorScheme == .dark ? 
                            AnyShapeStyle(Color.white.opacity(0.08)) : 
                            AnyShapeStyle(Material.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.15), // Subtle frost
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.1),
                radius: 12, // Reduced spread for cleaner look
                x: 0,
                y: 6
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
