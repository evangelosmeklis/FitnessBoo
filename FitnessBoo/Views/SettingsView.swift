//
//  SettingsView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    
    init(dataService: DataServiceProtocol) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(dataService: dataService))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General")) {
                    Picker("Units", selection: $viewModel.unitSystem) {
                        Text("Metric").tag(UnitSystem.metric)
                        Text("Imperial").tag(UnitSystem.imperial)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                viewModel.loadSettings()
            }
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(dataService: MockDataService())
    }
}
