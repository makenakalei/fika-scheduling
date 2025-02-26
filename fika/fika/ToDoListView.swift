//
//  ToDoListView.swift
//  fika
//
//  Created by Makena Robison on 2/26/25.
//
import SwiftUI

struct Task: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let startDate: Date
    var isCompleted: Bool = false
}

struct TaskListView: View {
    @State private var tasks: [Task] = [
        Task(name: "Morning Yoga", category: "Health", startDate: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!),
        Task(name: "Work Meeting", category: "Work", startDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date())!),
        Task(name: "Grocery Shopping", category: "Personal", startDate: Calendar.current.date(byAdding: .hour, value: 5, to: Date())!),
        Task(name: "Gym Workout", category: "Fitness", startDate: Calendar.current.date(byAdding: .hour, value: 7, to: Date())!),
        Task(name: "Doctor's Appointment", category: "Health", startDate: Calendar.current.date(byAdding: .hour, value: 9, to: Date())!)
    ]
    
    @State private var showSurvey = false
    @State private var selectedTask: Task?
    @State private var stressLevel: Int = 5
    @State private var journalEntry: String = ""

    var currentTasks: [Task] {
        tasks.filter { !$0.isCompleted }.sorted { $0.startDate < $1.startDate }
    }
    
    var archivedTasks: [Task] {
        tasks.filter { $0.isCompleted }.sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        NavigationView {
            List {
                if !currentTasks.isEmpty {
                    Section(header: Text("Current Tasks")) {
                        ForEach($tasks.filter { !$0.wrappedValue.isCompleted }) { $task in
                            TaskRow(task: $task, showSurvey: $showSurvey, selectedTask: $selectedTask)
                        }
                    }
                }
                
                if !archivedTasks.isEmpty {
                    Section(header: Text("Archived Tasks")) {
                        ForEach($tasks.filter { $0.wrappedValue.isCompleted }) { $task in
                            TaskRow(task: $task, showSurvey: $showSurvey, selectedTask: $selectedTask, disabled: true)
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .sheet(isPresented: $showSurvey) {
                if let task = selectedTask {
                    TaskCompletionSurvey(
                        task: task,
                        stressLevel: $stressLevel,
                        journalEntry: $journalEntry,
                        onClose: {
                            showSurvey = false
                            selectedTask = nil
                        }
                    )
                }
            }
        }
    }
}

struct TaskRow: View {
    @Binding var task: Task
    @Binding var showSurvey: Bool
    @Binding var selectedTask: Task?
    var disabled: Bool = false

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { task.isCompleted },
                set: { isChecked in
                    task.isCompleted = isChecked
                    if isChecked {
                        selectedTask = task
                        showSurvey = true
                    }
                }
            ))
            .labelsHidden()
            .toggleStyle(CheckboxToggleStyle())
            .disabled(disabled)

            VStack(alignment: .leading) {
                Text(task.name)
                    .font(.headline)
                    .foregroundColor(disabled ? .gray : .primary)

                HStack {
                    CategoryTag(category: task.category)
                    Text("\(formattedDate(task.startDate)) at \(formattedTime(task.startDate))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct CategoryTag: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(categoryColor(category))
            .foregroundColor(.white)
            .cornerRadius(10)
    }

    func categoryColor(_ category: String) -> Color {
        switch category {
        case "Work": return Color.blue
        case "Personal": return Color.purple
        case "Health": return Color.green
        case "Fitness": return Color.orange
        case "Finance": return Color.red
        default: return Color.gray
        }
    }
}

struct TaskCompletionSurvey: View {
    let task: Task
    @Binding var stressLevel: Int
    @Binding var journalEntry: String
    var onClose: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("How stressed were you while doing \(task.name)?")) {
                    Picker("Stress Level", selection: $stressLevel) {
                        ForEach(1...10, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Journal Entry (Optional)")) {
                    TextEditor(text: $journalEntry)
                        .frame(minHeight: 100)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray, lineWidth: 1))
                }
                
                Section {
                    Button("Submit") {
                        print("Task: \(task.name) completed with stress level \(stressLevel). Journal: \(journalEntry)")
                        onClose()
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Task Reflection")
            .navigationBarItems(trailing: Button("Close") { onClose() })
        }
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .blue : .gray)
                .font(.title2)
        }
    }
}

struct TaskListView_Previews: PreviewProvider {
    static var previews: some View {
        TaskListView()
    }
}
