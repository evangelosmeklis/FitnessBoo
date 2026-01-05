//
//  GlassCard.swift
//  FitnessBoo
//
//  Created by Kiro on 26/7/25.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .premiumGlassBackground(cornerRadius: cornerRadius)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let progress: Double?
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ZStack {
                        // Subtle background for icon instead of glow
                        Circle()
                            .fill(color.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    
                    Spacer()
                    
                    if let progress = progress {
                        CircularProgressView(progress: progress, color: color, lineWidth: 4)
                            .frame(width: 36, height: 36)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .tracking(0.5) // Reduced tracking
                    
                    Text(value)
                        .font(.system(size: 24, weight: .medium, design: .rounded)) // Clean rounded font
                        .foregroundStyle(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    
    init(progress: Double, color: Color, lineWidth: CGFloat = 3) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.1), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.8), value: progress)
        }
    }
}

// MARK: - Large Circular Metric Card (Premium Update)
struct LargeCircularMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let color: Color
    let icon: String?
    
    var body: some View {
        GlassCard(cornerRadius: 24) {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text(title.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .tracking(1.0)
                    Spacer()
                }
                
                // Large circular progress
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(
                            color.opacity(0.1),
                            lineWidth: 16
                        )
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .shadow(color: color.opacity(0.2), radius: 10, x: 0, y: 0) // Soft sheen
                    
                    // Center content
                    VStack(spacing: 4) {
                        Text(value)
                            .font(.system(size: 44, weight: .medium, design: .rounded))
                            .foregroundStyle(color)
                        
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.body)
                                .foregroundStyle(color.opacity(0.7))
                        }
                    }
                }
                .frame(height: 200)
                .animation(.easeInOut(duration: 0.8), value: progress)
                
                // Footer
                VStack(spacing: 4) {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text("\(Int(progress * 100))% Goal")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Compact Stat Card (Premium Update)
struct CompactStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        GlassCard(cornerRadius: 16) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.uppercased())
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .tracking(0.5)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value)
                            .font(.system(.title3, design: .rounded, weight: .semibold))
                            .foregroundStyle(Color.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer(minLength: 0)
            }
        }
    }
}

struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isLoading: Bool
    let style: GlassButtonStyle
    @Environment(\.colorScheme) private var colorScheme

    enum GlassButtonStyle {
        case `default`
        case primary
    }

    init(_ title: String, icon: String? = nil, isLoading: Bool = false, style: GlassButtonStyle = .default, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isLoading = isLoading
        self.style = style
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    SwiftUI.ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(backgroundView)
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLoading)
    }

    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .default:
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        case .primary:
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.premiumIndigo) // Use premium color
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: Color.premiumIndigo.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }
}