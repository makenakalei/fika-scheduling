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
    @State private var routeToTasks = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Get user ID from UserDefaults or your auth system
    private let userId = UserDefaults.standard.integer(forKey: "userId")
    
    let categories = ["Work", "Personal", "Health", "Finance", "Other"]
    let priorities = ["Low", "Medium", "High", "Extra High"]
    
    var body: some View {
        NavigationStack {
            VStack {
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
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Add to list!")
                                    .frame(maxWidth: .infinity)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.fikaTeal)
                        .cornerRadius(8)
                        .disabled(isLoading || taskName.isEmpty)
                    }
                }
                
                NavigationLink(destination: TaskListView(), isActive: $routeToTasks) {
                    EmptyView()
                }
                .hidden()
            }
            .navigationTitle("Add a New Task!")
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    struct TaskData: Codable {
        let name: String
        let category: String
        let description: String
        let start_time: String
        let deadline: String
        let estimated_time: Int
        let priority: String
        let fixed_time: Bool
        let user_id: Int
        let end_time: String?
        let divided: Bool
        let archived: Bool
        let stress_entry: Int?
    }
    
    func saveTask() {
        guard !taskName.isEmpty else {
            errorMessage = "Please enter a task name"
            return
        }
        
        // Get the auth token
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            errorMessage = "Not authenticated. Please log in again."
            return
        }
        
        // Get the user ID
        let userId = UserDefaults.standard.integer(forKey: "userId")
        guard userId != 0 else {
            errorMessage = "Invalid user ID. Please log in again."
            return
        }
        
        isLoading = true
        
        // Format dates in ISO8601 format
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        
        let task = TaskData(
            name: taskName,
            category: category,
            description: description,
            start_time: dateFormatter.string(from: startDate),
            deadline: dateFormatter.string(from: deadline),
            estimated_time: estimatedMinutes,
            priority: priority,
            fixed_time: fixedTime,
            user_id: userId,
            end_time: nil, // Always include, even if nil
            divided: !fixedTime, // true if not a fixed time block
            archived: false, // always false on creation
            stress_entry: nil // Always include, even if nil
        )
        
        guard let url = URL(string: "http://localhost:8000/tasks/") else {
            errorMessage = "Invalid backend URL"
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONEncoder().encode(task)
            request.httpBody = jsonData
            
            // Print the request body for debugging
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("Request body: \(jsonString)")
            }
        } catch {
            errorMessage = "Failed to encode task: \(error.localizedDescription)"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    errorMessage = "Error sending task: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessage = "Invalid server response"
                    return
                }
                
                if httpResponse.statusCode == 401 {
                    errorMessage = "Authentication failed. Please log in again."
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    if let data = data,
                       let errorString = String(data: data, encoding: .utf8) {
                        errorMessage = "Server error: \(errorString)"
                    } else {
                        errorMessage = "Server error: \(httpResponse.statusCode)"
                    }
                    return
                }
                
                if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    print("Server response: \(responseString)")
                }
                
                routeToTasks = true
            }
        }.resume()
    }
}

struct TaskInputView_Previews: PreviewProvider {
    static var previews: some View {
        TaskInputView()
    }
}
