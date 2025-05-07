import SwiftUI

// MARK: - HomeService
class HomeService: ObservableObject {
    @Published var todayTasksCount = 0
    @Published var upcomingDeadlinesCount = 0
    @Published var completedTasksCount = 0
    @Published var averageStress: Double = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "http://localhost:8000"
    
    func fetchStats(userId: Int) async throws {
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
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today)!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = .current
        
        DispatchQueue.main.async {
            self.todayTasksCount = tasks.filter { task in
                guard task.archived != true else { return false }
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                var isToday = false
                if let startStr = task.start_time, let start = dateFormatter.date(from: startStr) {
                    isToday = calendar.isDate(start, inSameDayAs: today)
                }
                if let deadlineStr = task.deadline, let deadline = dateFormatter.date(from: deadlineStr) {
                    isToday = isToday || calendar.isDate(deadline, inSameDayAs: today)
                }
                return isToday
            }.count
            self.upcomingDeadlinesCount = tasks.filter { task in
                guard let deadlineStr = task.deadline,
                      let deadline = dateFormatter.date(from: deadlineStr) else { return false }
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
                let nextWeek = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: Date()))!
                return deadline > tomorrow && deadline <= nextWeek
            }.count
        }
        // Fetch archived count from backend
        await fetchArchivedCount(userId: userId)
        // Fetch moods and compute average stress
        await fetchMoodsAndComputeAverageStress(userId: userId)
    }

    func fetchArchivedCount(userId: Int) async {
        guard let url = URL(string: "\(baseURL)/tasks/archived_count/?user_id=\(userId)") else { return }
        var request = URLRequest(url: url)
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let count = json["archived_count"] as? Int {
                DispatchQueue.main.async {
                    self.completedTasksCount = count
                }
            }
        } catch {
            print("Failed to fetch archived count: \(error)")
        }
    }

    func fetchMoodsAndComputeAverageStress(userId: Int) async {
        guard let url = URL(string: "\(baseURL)/mood/") else { return }
        var request = URLRequest(url: url)
        if let token = UserDefaults.standard.string(forKey: "authToken") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let moods = json["moods"] as? [[String: Any]] {
                let userMoods = moods.filter { ($0["user_id"] as? Int) == userId }
                let stressLevels = userMoods.compactMap { $0["stress_level"] as? Int }
                let avg = stressLevels.isEmpty ? 0 : Double(stressLevels.reduce(0, +)) / Double(stressLevels.count)
                // Fetch user baseline stress from UserDefaults or set to 5 if not found
                let baseline = UserDefaults.standard.integer(forKey: "stressBaseLevel")
                DispatchQueue.main.async {
                    self.averageStress = avg + Double(baseline)
                }
            }
        } catch {
            print("Failed to fetch moods: \(error)")
        }
    }
}

struct UserHomeView: View {
    @StateObject private var homeService = HomeService()
    // Get user ID from UserDefaults
    private let userId = UserDefaults.standard.integer(forKey: "userId")
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Quick Stats Section
                VStack(spacing: 15) {
                    StatCard(title: "Today's Tasks", value: "\(homeService.todayTasksCount)", icon: "list.bullet")
                    StatCard(title: "Archived Tasks", value: "\(homeService.completedTasksCount)", icon: "archivebox")
                    StatCard(title: "Average Stress", value: String(format: "%.1f", homeService.averageStress), icon: "waveform.path.ecg")
                }
                .padding()
                
                Button("Refresh Stats") {
                    Task {
                        await loadStats()
                    }
                }
                .padding(.bottom)
                
                Spacer()
                
                // Quick Actions
                VStack(spacing: 15) {
                    NavigationLink(destination: TaskInputView()) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Task")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.fikaTeal)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    NavigationLink(destination: ScheduleView()) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("View Schedule")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.fikaTeal.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .padding()
            .navigationTitle("Home")
            .alert("Error", isPresented: .constant(homeService.errorMessage != nil)) {
                Button("OK") { homeService.errorMessage = nil }
            } message: {
                Text(homeService.errorMessage ?? "")
            }
        }
        .task {
            await loadStats()
        }
        .onAppear {
            Task {
                await loadStats()
            }
        }
    }
    
    private func loadStats() async {
        homeService.isLoading = true
        do {
            try await homeService.fetchStats(userId: userId)
        } catch {
            homeService.errorMessage = error.localizedDescription
        }
        homeService.isLoading = false
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.fikaTeal)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    UserHomeView()
}
