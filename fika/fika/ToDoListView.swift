//
//  ToDoListView.swift
//  fika
//
//  Created by Makena Robison on 2/26/25.
//
import SwiftUI

// MARK: - Models
struct currTask: Identifiable, Codable {
    let id: Int?
    let name: String?
    let category: String?
    let estimated_time: Int?
    let deadline: String?
    let fixed_time: Bool?
    let priority: String?
    let start_time: String?
    let end_time: String?
    let description: String?
    let divided: Bool?
    let archived: Bool?
    let user_id: Int?
    let stress_entry: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, category, estimated_time, deadline, fixed_time, priority, start_time, end_time, description, divided, archived, user_id, stress_entry
    }
}

// MARK: - TaskService
class TaskService: ObservableObject {
    @Published var tasks: [currTask] = []
    private let baseURL = "http://localhost:8000" // Update with your actual API URL
    
    func fetchTasks(userId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/tasks/?user_id=\(userId)") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        if let jsonString = String(data: data, encoding: .utf8) {
            print("Raw response: \(jsonString)")
        }
        let response = try JSONDecoder().decode([String: [currTask]].self, from: data)
        
        DispatchQueue.main.async {
            self.tasks = response["tasks"] ?? []
        }
    }
    
    func completeTask(taskId: Int, stressLevel: Int, journalEntry: String) async throws {
        guard let url = URL(string: "\(baseURL)/mood/") else {
            throw URLError(.badURL)
        }
        let userId = UserDefaults.standard.integer(forKey: "userId")
        print("userId: \(userId)")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let todayString = dateFormatter.string(from: Date())
        let moodEntry: [String: Any] = [
            "user_id": userId,
            "task_id": taskId,
            "stress_level": stressLevel,
            "date": todayString
        ]
        print("moodEntry: \(moodEntry)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: moodEntry)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    func setTaskArchived(_ task: currTask, archived: Bool, userId: Int) async {
        guard let taskId = task.id else { return }
        guard let url = URL(string: "\(baseURL)/tasks/\(taskId)") else { return }
        var dict = [String: Any]()
        dict["name"] = task.name
        dict["category"] = task.category
        dict["estimated_time"] = task.estimated_time
        dict["deadline"] = task.deadline
        dict["fixed_time"] = task.fixed_time
        dict["priority"] = task.priority
        dict["start_time"] = task.start_time
        dict["end_time"] = task.end_time
        dict["description"] = task.description
        dict["divided"] = task.divided
        dict["archived"] = archived
        dict["stress_entry"] = task.stress_entry
        dict["user_id"] = userId
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: dict)
        do {
            _ = try await URLSession.shared.data(for: request)
            do {
                try await fetchTasks(userId: userId)
            } catch {
                print("Failed to refresh tasks after archiving: \(error)")
            }
        } catch {
            print("Failed to archive/unarchive task: \(error)")
        }
    }
}

// MARK: - Views
struct TaskListView: View {
    @StateObject private var taskService = TaskService()
    @State private var selectedTask: currTask?
    @State private var stressLevel: Int = 5
    @State private var journalEntry: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var pendingArchiveTask: currTask? = nil // For survey before archiving
    // Get user ID from UserDefaults or your auth system
    private let userId = UserDefaults.standard.integer(forKey: "userId")
    
    var currentTasks: [currTask] {
        taskService.tasks.filter { $0.archived != true }
    }
    
    var archivedTasks: [currTask] {
        taskService.tasks.filter { $0.archived == true }
    }
    
    func makeSurvey(for task: currTask) -> some View {
        TaskCompletionSurvey(
            task: task,
            stressLevel: $stressLevel,
            journalEntry: $journalEntry,
            onClose: {
                pendingArchiveTask = nil
            },
            onSubmit: { stressLevel, journalEntry in
                Task {
                    do {
                        try await taskService.completeTask(
                            taskId: task.id ?? 0,
                            stressLevel: stressLevel,
                            journalEntry: journalEntry
                        )
                        await taskService.setTaskArchived(task, archived: true, userId: userId)
                        try await taskService.fetchTasks(userId: userId)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
                pendingArchiveTask = nil
            }
        )
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading tasks...")
                } else {
                    List {
                        if !currentTasks.isEmpty {
                            Section(header: Text("Current Tasks")) {
                                ForEach(currentTasks) { task in
                                    TaskRow(task: task, selectedTask: $selectedTask, taskService: taskService, onArchiveToggle: { isChecked in
                                        if isChecked {
                                            pendingArchiveTask = task
                                        } else {
                                            Task {
                                                await taskService.setTaskArchived(task, archived: false, userId: userId)
                                                try? await taskService.fetchTasks(userId: userId)
                                            }
                                        }
                                    })
                                }
                            }
                        }
                        if !archivedTasks.isEmpty {
                            Section(header: Text("Archived Tasks")) {
                                ForEach(archivedTasks) { task in
                                    TaskRow(task: task, selectedTask: $selectedTask, taskService: taskService, onArchiveToggle: { isChecked in
                                        if !isChecked {
                                            Task {
                                                await taskService.setTaskArchived(task, archived: false, userId: userId)
                                                try? await taskService.fetchTasks(userId: userId)
                                            }
                                        }
                                    })
                                }
                            }
                        }
                        if currentTasks.isEmpty && archivedTasks.isEmpty {
                            Text("No tasks available.")
                        }
                        NavigationLink(destination: ScheduleView()) {
                            Text("View My Schedule")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .padding([.horizontal, .bottom])
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .sheet(item: $pendingArchiveTask) { task in
                makeSurvey(for: task)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
                Text(errorMessage ?? "")
            }
        }
        .task {
            await loadTasks()
        }
    }
    
    private func loadTasks() async {
        isLoading = true
        do {
            try await taskService.fetchTasks(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct TaskRow: View {
    let task: currTask
    @Binding var selectedTask: currTask?
    @ObservedObject var taskService: TaskService
    var disabled: Bool = false
    var onArchiveToggle: ((Bool) -> Void)? = nil
    @State private var isArchiving = false
    // Get user ID from UserDefaults or your auth system
    private let userId = UserDefaults.standard.integer(forKey: "userId")
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { task.archived == true },
                set: { isChecked in
                    onArchiveToggle?(isChecked)
                }
            ))
            .labelsHidden()
            .toggleStyle(CheckboxToggleStyle())
            .disabled(disabled)
            
            VStack(alignment: .leading) {
                Text(task.name ?? "No Name")
                    .font(.headline)
                    .foregroundColor(disabled ? .gray : .primary)
                
                HStack {
                    CategoryTag(category: task.category ?? "No Category")
                    if let deadline = task.deadline {
                        Text("Due: \(formattedDate(deadline))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
    }
    
    func formattedDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "No date" }
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return dateString
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
    let task: currTask
    @Binding var stressLevel: Int
    @Binding var journalEntry: String
    var onClose: () -> Void
    var onSubmit: (Int, String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("How stressed were you while doing \(task.name ?? "No Name")?")) {
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
                        onSubmit(stressLevel, journalEntry)
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Task Reflection")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { onClose() }
                }
            }
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

