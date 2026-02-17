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

// MARK: - Large Circular Metric Card (Whoop-style)
struct LargeCircularMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let progress: Double
    let color: Color
    let icon: String?

    var body: some View {
        GlassCard(cornerRadius: 24) {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text(title.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .tracking(1.2)
                    Spacer()
                }

                // Large circular progress - Whoop style
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(
                            color.opacity(0.15),
                            lineWidth: 18
                        )

                    // Progress ring with gradient
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))

                    // Center content
                    VStack(spacing: 6) {
                        Text(value)
                            .font(.system(size: 56, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)

                        Text(subtitle.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .tracking(0.8)
                    }
                }
                .frame(height: 220)
                .animation(.easeInOut(duration: 0.8), value: progress)
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

// MARK: - Horizontal Metric Row (Whoop-style)
struct HorizontalMetricRow: View {
    let icon: String
    let label: String
    let value: String
    let unit: String?
    let progress: Double?
    let color: Color

    init(icon: String, label: String, value: String, unit: String? = nil, progress: Double? = nil, color: Color) {
        self.icon = icon
        self.label = label
        self.value = value
        self.unit = unit
        self.progress = progress
        self.color = color
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Icon
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(color)
                    )

                // Label
                Text(label.uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                // Value
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.body)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    if let unit = unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Progress bar if provided
            if let progress = progress {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color.opacity(0.15))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: geometry.size.width * min(progress, 1.0), height: 4)
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(.vertical, 8)
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
                .fill(Color.premiumElevatedBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.premiumBorder.opacity(0.6), lineWidth: 1)
                )
        case .primary:
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.premiumIndigo)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.premiumBorder.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.premiumIndigo.opacity(0.35), radius: 8, x: 0, y: 4)
        }
    }
}