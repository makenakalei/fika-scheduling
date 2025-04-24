import SwiftUI

struct ScheduleTask: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let title: String
    let type: String
}

struct ScheduleView: View {
    @State private var goToTaskList = false

    let tasks: [ScheduleTask] = [
        ScheduleTask(startTime: iso("2025-04-24T016:00:00Z"), endTime: iso("2025-04-24T17:00:00Z"), title: "Team Meeting", type: "Fixed"),
        ScheduleTask(startTime: iso("2025-04-24T17:00:00Z"), endTime: iso("2025-04-24T17:30:00Z"), title: "Break", type: "Break"),
        ScheduleTask(startTime: iso("2025-04-24T17:30:00Z"), endTime: iso("2025-04-24T18:00:00Z"), title: "Break", type: "Break"),
        ScheduleTask(startTime: iso("2025-04-24T18:00:00Z"), endTime: iso("2025-04-24T18:45:00Z"), title: "Read AI Paper", type: "Flexible"),
        ScheduleTask(startTime: iso("2025-04-24T18:45:00Z"), endTime: iso("2025-04-24T19:15:00Z"), title: "Go for a walk", type: "Flexible")
    ]
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Text("Today – \(formattedDate(tasks.first?.startTime ?? Date()))")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(tasks) { task in
                            HStack(alignment: .top, spacing: 12) {
                                Text(formattedTime(task.startTime))
                                    .font(.caption)
                                    .frame(width: 60, alignment: .leading)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(task.title)
                                        .font(.headline)
                                    Text(task.type)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(10)
                                .background(task.typeColor)
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }

                Spacer()

                NavigationLink(destination: TaskListView(), isActive: $goToTaskList) {
                    Button("Back to Task List") {
                        goToTaskList = true
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Schedule")
        }
    }

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

}
func fallbackDate(_ label: String) -> Date {
    print("⚠️ Failed to parse date for task labeled '\(label)' — returning Date() instead.")
    return Date()
}
extension ScheduleTask {
    var typeColor: Color {
        switch type {
        case "Fixed": return .blue
        case "Flexible": return .orange
        case "Break": return .gray
        default: return .black
        }
    }
}

func iso(_ str: String) -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(identifier: "America/Los_Angeles") // ← or your local
    return formatter.date(from: str) ?? fallbackDate(str)
}


#Preview {
    ScheduleView()
}
