//
//  CalendarView.swift
//  FitnessBoo
//
//  Created by Evangelos Meklis on 24/7/25.
//

import SwiftUI

struct CalendarView: View {
    @Binding var selectedDate: Date
    let datesWithEntries: Set<Date>
    
    @State private var currentMonth: Date = Date()
    
    private var calendar: Calendar {
        return Calendar.current
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var body: some View {
        VStack {
            // Month and year header
            headerView
            
            // Days of the week
            daysOfWeekView
            
            // Dates grid
            datesGridView
        }
    }
    
    private var headerView: some View {
        HStack {
            Button(action: {
                changeMonth(by: -1)
            }) {
                Image(systemName: "chevron.left")
            }
            
            Spacer()
            
            Text(monthYearFormatter.string(from: currentMonth))
                .font(.headline)
            
            Spacer()
            
            Button(action: {
                changeMonth(by: 1)
            }) {
                Image(systemName: "chevron.right")
            }
        }
        .padding(.bottom, 10)
    }
    
    private var daysOfWeekView: some View {
        HStack {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var datesGridView: some View {
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!.count
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!
        let startingWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
            ForEach(1..<startingWeekday, id: \.self) { _ in
                Color.clear
            }
            
            ForEach(1...daysInMonth, id: \.self) { day in
                let date = calendar.date(bySetting: .day, value: day, of: currentMonth)!
                
                Button(action: {
                    selectedDate = date
                }) {
                    Text("\(day)")
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(
                            ZStack {
                                if calendar.isDate(date, inSameDayAs: selectedDate) {
                                    Circle()
                                        .fill(Color.accentColor)
                                        .frame(width: 30, height: 30)
                                }
                                
                                if datesWithEntries.contains(calendar.startOfDay(for: date)) {
                                    Circle()
                                        .stroke(Color.secondary, lineWidth: 1)
                                        .frame(width: 30, height: 30)
                                }
                            }
                        )
                        .foregroundColor(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                }
            }
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
}
