//
//  TaskInputView.swift
//  fika
//
//  Created by Makena Robison on 2/26/25.
//

import SwiftUI

struct TaskInputView: View {
    @State private var taskName: String = ""
    @State private var category: String = "Work"
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date()
    @State private var description: String = ""
    
    let categories = ["Work", "Personal", "Health", "Finance", "Other"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Name", text: $taskName)
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    DatePicker("Start Date & Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    
                    DatePicker("End Date & Time", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .frame(minHeight: 50)
                }
                
                Section {
                    Button(action: saveTask) {
                        Text("Add to list!")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("New Task")
        }
    }

    func saveTask() {
        // Handle task saving logic
        print("Task Saved: \(taskName), \(category), \(startDate), \(endDate), \(description)")
    }
}

struct TaskInputView_Previews: PreviewProvider {
    static var previews: some View {
        TaskInputView()
    }
}
