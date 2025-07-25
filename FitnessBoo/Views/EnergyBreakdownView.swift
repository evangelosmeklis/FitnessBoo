//
//  EnergyBreakdownView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 23/7/25.
//

import SwiftUI

struct EnergyBreakdownView: View {
    let activeEnergy: Double
    let restingEnergy: Double
    let totalEnergy: Double
    
    private var activePercentage: Double {
        guard totalEnergy > 0 else { return 0 }
        return activeEnergy / totalEnergy
    }
    
    private var restingPercentage: Double {
        guard totalEnergy > 0 else { return 0 }
        return restingEnergy / totalEnergy
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress ring or bar
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: restingPercentage)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                Circle()
                    .trim(from: restingPercentage, to: restingPercentage + activePercentage)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text("\(Int(totalEnergy))")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total kcal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Energy Breakdown")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    EnergyBreakdownView(
        activeEnergy: 400.0,
        restingEnergy: 1600.0,
        totalEnergy: 2000.0
    )
    .padding()
}