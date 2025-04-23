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
    @State private var deadline: Date = Date()
    @State private var description: String = ""
    @State private var fixedTime: Bool = false
    @State private var estimatedMinutes: Int = 0
    @State private var priority: String = "Low"

    let categories = ["Work", "Personal", "Health", "Finance", "Other"]
    let priorities = ["Low", "Medium", "High", "Extra High"]

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
                    Picker("Priority Level", selection: $priority) {
                        ForEach(priorities, id: \.self) { priority in
                            Text(priority)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    Toggle("Is this a set time block?", isOn: $fixedTime)
                    DatePicker("Start Date & Time", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                    
                    DatePicker("Deadline", selection: $deadline, displayedComponents: [.date, .hourAndMinute])
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .frame(minHeight: 50)

                    VStack(alignment: .leading) {
                        Text("Estimated Time")
                            .font(.headline)

                        HStack {
                            Picker("Hours", selection: Binding(
                                get: { estimatedMinutes / 60 },
                                set: { newHours in
                                    let minutesPart = estimatedMinutes % 60
                                    estimatedMinutes = newHours * 60 + minutesPart
                                })) {
                                ForEach(0..<24) { hour in
                                    Text("\(hour) h").tag(hour)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 100)
                            
                            Picker("Minutes", selection: Binding(
                                get: { estimatedMinutes % 60 },
                                set: { newMinutes in
                                    let hoursPart = estimatedMinutes / 60
                                    estimatedMinutes = hoursPart * 60 + newMinutes
                                })) {
                                ForEach(0..<60) { minute in
                                    Text("\(minute) m").tag(minute)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 100)
                        }
                    }
                    .padding(.top)
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
            .navigationTitle("Add a New Task!")
        }
    }

    struct TaskData: Codable {
            let name: String
            let category: String
            let description: String
            let start_time: String
            let deadline: String
            let estimated_minutes: Int
            let priority: String
            let fixed_time: Bool
        }

    func saveTask() {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            let task = TaskData(
                name: taskName,
                category: category,
                description: description,
                start_time: dateFormatter.string(from: startDate),
                deadline: dateFormatter.string(from: deadline),
                estimated_minutes: estimatedMinutes,
                priority: priority,
                fixed_time: fixedTime
            )

            guard let url = URL(string: "http://127.0.0.1:8000/tasks") else {
                print("Invalid backend URL")
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            do {
                let jsonData = try JSONEncoder().encode(task)
                request.httpBody = jsonData
            } catch {
                print("Failed to encode task: \(error)")
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Error sending task: \(error)")
                    return
                }

                if let data = data,
                   let responseStr = String(data: data, encoding: .utf8) {
                    print("Response: \(responseStr)")
                }
            }.resume()
        }
    }

struct TaskInputView_Previews: PreviewProvider {
    static var previews: some View {
        TaskInputView()
    }
}
