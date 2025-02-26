//
//  CalendarView.swift
//  fika
//
//  Created by Makena Robison on 2/26/25.
//
import SwiftUI

struct AnimatedCalendarView: View {
    @State private var selectedDate = Date()
    @State private var isMonthView = true
    @State private var currentMonthOffset = 0
    @State private var currentWeekOffset = 0

    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    // Example Event Data (You can replace with dynamic events)
    private let eventDates: [String] = ["2025-02-10", "2025-02-14", "2025-02-21"]
    
    var body: some View {
        VStack {
            // Toggle between Month and Week Views
            Picker("View Mode", selection: $isMonthView) {
                Text("Month").tag(true)
                Text("Week").tag(false)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Swipe Gesture
            let swipeGesture = DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 { // Swipe Left
                        if isMonthView {
                            withAnimation { currentMonthOffset += 1 }
                        } else {
                            withAnimation { currentWeekOffset += 1 }
                        }
                    } else if value.translation.width > 50 { // Swipe Right
                        if isMonthView {
                            withAnimation { currentMonthOffset -= 1 }
                        } else {
                            withAnimation { currentWeekOffset -= 1 }
                        }
                    }
                }

            VStack {
                if isMonthView {
                    monthView()
                        .transition(.slide)
                } else {
                    weekView()
                        .transition(.opacity)
                }
            }
            .gesture(swipeGesture)
            .animation(.easeInOut, value: isMonthView)
        }
        .padding()
    }
    
    // MARK: - Month View
    func monthView() -> some View {
        let daysInMonth = getDaysInMonth(offset: currentMonthOffset)
        let columns = Array(repeating: GridItem(.flexible()), count: 7)

        return VStack {
            Text(getMonthYear(offset: currentMonthOffset))
                .font(.headline)

            LazyVGrid(columns: columns) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day).bold()
                        .frame(maxWidth: .infinity)
                }
                
                ForEach(daysInMonth, id: \.self) { day in
                    VStack {
                        Text("\(day)")
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(isSameDay(day, selectedDate) ? Color.blue : Color.clear)
                            .clipShape(Circle())
                            .onTapGesture {
                                selectedDate = getDateFor(day: day, offset: currentMonthOffset)
                            }
                        
                        if eventDates.contains(getDateString(getDateFor(day: day, offset: currentMonthOffset))) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Week View
    func weekView() -> some View {
        let currentWeek = getCurrentWeek(offset: currentWeekOffset)
        let columns = Array(repeating: GridItem(.flexible()), count: 7)

        return VStack {
            Text("Week of \(getDateString(currentWeek.first ?? Date()))")
                .font(.headline)

            LazyVGrid(columns: columns) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day).bold()
                        .frame(maxWidth: .infinity)
                }

                ForEach(currentWeek, id: \.self) { date in
                    VStack {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(isSameDay(date, selectedDate) ? Color.blue : Color.clear)
                            .clipShape(Circle())
                            .onTapGesture {
                                selectedDate = date
                            }

                        if eventDates.contains(getDateString(date)) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Helpers
    func getDaysInMonth(offset: Int) -> [Int] {
        let calendar = Calendar.current
        let monthDate = calendar.date(byAdding: .month, value: offset, to: Date())!
        let range = calendar.range(of: .day, in: .month, for: monthDate)!
        return Array(range)
    }
    
    func getMonthYear(offset: Int) -> String {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        let monthDate = calendar.date(byAdding: .month, value: offset, to: Date())!
        return dateFormatter.string(from: monthDate)
    }
    
    func getDateFor(day: Int, offset: Int) -> Date {
        let calendar = Calendar.current
        let monthDate = calendar.date(byAdding: .month, value: offset, to: Date())!
        return calendar.date(from: DateComponents(year: calendar.component(.year, from: monthDate), month: calendar.component(.month, from: monthDate), day: day)) ?? Date()
    }
    
    func getCurrentWeek(offset: Int) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today) - 1
        let startOfWeek = calendar.date(byAdding: .day, value: -weekday + (offset * 7), to: today)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    func getDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func isSameDay(_ date1: Date, _ date2: Date) -> Bool {
        return Calendar.current.isDate(date1, inSameDayAs: date2)
    }
    
    func isSameDay(_ day: Int, _ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.day, from: date) == day
    }
}

struct AnimatedCalendarView_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedCalendarView()
    }
}




