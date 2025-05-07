import SwiftUI

// MARK: - Models
struct ScheduleItem: Identifiable, Codable {
    let id: Int
    let user_id: Int
    let task_id: Int?
    let start_time: String
    let end_time: String
    let type: String
    let created_at: String
}

struct ScheduleResponse: Codable {
    let schedule: [ScheduleItem]
}

struct ScheduleTask: Identifiable {
    let id: Int
    let taskId: Int?
    let title: String
    let start: String
    let end: String
    let type: String
    
    var startTime: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current
        if let date = formatter.date(from: start) {
            return date
        } else {
            print("Failed to parse start: \(start)")
            return Date()
        }
    }
    var endTime: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current
        if let date = formatter.date(from: end) {
            return date
        } else {
            print("Failed to parse end: \(end)")
            return Date()
        }
    }
}

// MARK: - ScheduleService
class ScheduleService: ObservableObject {
    @Published var tasks: [ScheduleTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    private let baseURL = "http://localhost:8000" // Update with your actual API URL
    private var taskTitles: [Int: String] = [:] // task_id: name

    // Fetch all tasks for the user and store their titles
    func fetchAllTasks(userId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/tasks/?user_id=\(userId)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode([String: [currTask]].self, from: data)
        let tasks = response["tasks"] ?? []
        self.taskTitles = [:]
        for task in tasks {
            if let id = task.id, let name = task.name {
                self.taskTitles[id] = name
            }
        }
    }

    func fetchSchedule(userId: Int) async throws {
        // Fetch all tasks first to get titles
        try await fetchAllTasks(userId: userId)
        guard let url = URL(string: "\(baseURL)/schedule/\(userId)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let scheduleResponse = try JSONDecoder().decode(ScheduleResponse.self, from: data)
        let schedule = scheduleResponse.schedule
        DispatchQueue.main.async {
            self.tasks = schedule.map {
                let title = ($0.task_id != nil) ? (self.taskTitles[$0.task_id!] ?? "") : $0.type
                return ScheduleTask(id: $0.id, taskId: $0.task_id, title: title, start: $0.start_time, end: $0.end_time, type: $0.type)
            }
        }
    }
    
    func generateNewSchedule(userId: Int) async throws {
        guard let url = URL(string: "\(baseURL)/schedule/generate/\(userId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        // After generating new schedule, fetch the updated schedule
        try await fetchSchedule(userId: userId)
    }
}

// MARK: - Views
struct ScheduleView: View {
    @StateObject private var scheduleService = ScheduleService()
    @State private var goToTaskList = false
    @State private var showGenerateAlert = false
    
    // Get user ID from UserDefaults or your auth system
    private let userId = UserDefaults.standard.integer(forKey: "userId")
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if scheduleService.isLoading {
                    ProgressView("Loading schedule...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack {
                        Text("Today's Schedule")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(formattedDate(Date()))
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    .padding([.top, .horizontal])
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(scheduleService.tasks) { task in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(formatTimeString(task.start)) - \(formatTimeString(task.end))")
                                        .font(.caption)
                                        .frame(width: 110, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title)
                                            .font(.headline)
                                        Text(task.type)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(task.typeColor)
                                    .cornerRadius(10)
                                    .foregroundColor(.white)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Generate New Schedule") {
                        showGenerateAlert = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.fikaTeal)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    NavigationLink(destination: TaskListView(), isActive: $goToTaskList) {
                        Button("Back to Task List") {
                            goToTaskList = true
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.fikaTeal.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Schedule")
            .alert("Generate New Schedule", isPresented: $showGenerateAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Generate") {
                    Task {
                        await generateNewSchedule()
                    }
                }
            } message: {
                Text("This will create a new schedule based on your current tasks and preferences. Your current schedule will be replaced.")
            }
            .alert("Error", isPresented: .constant(scheduleService.errorMessage != nil)) {
                Button("OK") { scheduleService.errorMessage = nil }
            } message: {
                Text(scheduleService.errorMessage ?? "")
            }
        }
        .task {
            await loadSchedule()
        }
    }
    
    private func loadSchedule() async {
        scheduleService.isLoading = true
        do {
            try await scheduleService.fetchSchedule(userId: userId)
        } catch {
            scheduleService.errorMessage = error.localizedDescription
        }
        scheduleService.isLoading = false
    }
    
    private func generateNewSchedule() async {
        scheduleService.isLoading = true
        do {
            try await scheduleService.generateNewSchedule(userId: userId)
        } catch {
            scheduleService.errorMessage = error.localizedDescription
        }
        scheduleService.isLoading = false
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
    
    func formatTimeString(_ isoString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = formatter.date(from: isoString) {
            let outFormatter = DateFormatter()
            outFormatter.dateFormat = "h:mm a"
            return outFormatter.string(from: date)
        }
        // fallback: just show the time part
        if let timePart = isoString.split(separator: "T").last {
            return String(timePart.prefix(5)) // "HH:mm"
        }
        return isoString
    }
}

extension ScheduleTask {
    var typeColor: Color {
        switch type {
        case "Fixed": return .fikaTeal
        case "Flexible": return .fikaTeal.opacity(0.7)
        case "Break": return .gray
        default: return .black
        }
    }
}

#Preview {
    ScheduleView()
}
