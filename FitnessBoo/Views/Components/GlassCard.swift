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
    let opacity: Double
    
    init(cornerRadius: CGFloat = 16, opacity: Double = 0.1, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.opacity = opacity
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let progress: Double?
    
    init(title: String, value: String, subtitle: String? = nil, icon: String, color: Color, progress: Double? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.progress = progress
    }
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                        .frame(width: 24, height: 24)
                    
                    Spacer()
                    
                    if let progress = progress {
                        CircularProgressView(progress: progress, color: color)
                            .frame(width: 32, height: 32)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
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
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

struct GlassButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let isLoading: Bool
    
    init(_ title: String, icon: String? = nil, isLoading: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
        self.isLoading = isLoading
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
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .disabled(isLoading)
        .scaleEffect(isLoading ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isLoading)
    }
}

// MARK: - Preview
struct GlassCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MetricCard(
                title: "Calories",
                value: "1,847",
                subtitle: "423 remaining",
                icon: "flame.fill",
                color: .orange,
                progress: 0.7
            )
            
            GlassButton("Save Goal", icon: "target") {
                // Action
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}