//
//  NeonColors.swift
//  FitnessBoo
//
//  Created by Claude on 3/11/25.
//

import SwiftUI

extension Color {
    // MARK: - Neon Color Palette for Dark Mode
    
    /// Bright neon cyan - perfect for primary accents
    static let neonCyan = Color(red: 0, green: 1, blue: 1)
    
    /// Bright neon blue - for secondary accents
    static let neonBlue = Color(red: 0.2, green: 0.6, blue: 1)
    
    /// Bright neon green - for positive indicators
    static let neonGreen = Color(red: 0, green: 1, blue: 0.5)
    
    /// Bright neon orange - for calorie tracking
    static let neonOrange = Color(red: 1, green: 0.6, blue: 0)
    
    /// Bright neon pink - for highlights
    static let neonPink = Color(red: 1, green: 0.2, blue: 0.6)
    
    /// Bright neon purple - for special features
    static let neonPurple = Color(red: 0.7, green: 0.2, blue: 1)
    
    // MARK: - Adaptive Neon Colors
    
    /// Adaptive cyan that switches between bright neon in dark mode and normal in light mode
    static var adaptiveNeonCyan: Color {
        Color("AdaptiveNeonCyan")
    }
    
    /// Adaptive blue that switches between bright neon in dark mode and normal in light mode
    static var adaptiveNeonBlue: Color {
        Color("AdaptiveNeonBlue")
    }
    
    /// Adaptive green that switches between bright neon in dark mode and normal in light mode
    static var adaptiveNeonGreen: Color {
        Color("AdaptiveNeonGreen")
    }
}

// MARK: - Neon Glow Modifier

struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
                .shadow(color: color.opacity(0.3), radius: radius * 2, x: 0, y: 0)
        } else {
            content
                .shadow(color: color.opacity(0.2), radius: radius / 2, x: 0, y: 2)
        }
    }
}

extension View {
    /// Adds a neon glow effect in dark mode
    func neonGlow(color: Color, radius: CGFloat = 8) -> some View {
        self.modifier(NeonGlow(color: color, radius: radius))
    }
}

// MARK: - Dark Glass Background Modifier

struct DarkGlassBackground: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        colorScheme == .dark ? 
                            Color.white.opacity(0.05) : 
                            Color(.systemGray6)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(colorScheme == .dark ? 0.2 : 0.3),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: 15,
                x: 0,
                y: 8
            )
    }
}

extension View {
    /// Applies a dark glass background effect
    func darkGlassBackground(cornerRadius: CGFloat = 16) -> some View {
        self.modifier(DarkGlassBackground(cornerRadius: cornerRadius))
    }
}

