import SwiftUI

struct UserSignUp: View {
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var gender = "Male"
    @State private var birthday = Date()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var navigateToPreferences = false
    
    let genderOptions = ["Male", "Female", "Non-binary", "Other"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Information")) {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section(header: Text("Personal Information")) {
                    TextField("First Name", text: $firstName)
                        .textContentType(.givenName)
                        .autocapitalization(.words)
                    
                    TextField("Last Name", text: $lastName)
                        .textContentType(.familyName)
                        .autocapitalization(.words)
                    
                    Picker("Gender", selection: $gender) {
                        ForEach(genderOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    
                    DatePicker("Birthday",
                             selection: $birthday,
                             displayedComponents: .date)
                }
                
                Section {
                    Button(action: validateAndProceed) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                    }
                    .listRowBackground(Color.fikaTeal)
                }
            }
            .navigationTitle("Create Account")
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Sign Up"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationDestination(isPresented: $navigateToPreferences) {
                UserPreferencesView(
                    username: username,
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName,
                    gender: gender,
                    birthday: birthday
                )
            }
        }
    }
    
    private func validateAndProceed() {
        // Validate inputs
        guard !username.isEmpty else {
            alertMessage = "Please enter a username"
            showingAlert = true
            return
        }
        
        guard !email.isEmpty else {
            alertMessage = "Please enter your email"
            showingAlert = true
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            alertMessage = "Please enter a valid email address"
            showingAlert = true
            return
        }
        
        guard !password.isEmpty else {
            alertMessage = "Please enter a password"
            showingAlert = true
            return
        }
        
        guard password.count >= 8 else {
            alertMessage = "Password must be at least 8 characters long"
            showingAlert = true
            return
        }
        
        guard password == confirmPassword else {
            alertMessage = "Passwords do not match"
            showingAlert = true
            return
        }
        
        guard !firstName.isEmpty else {
            alertMessage = "Please enter your first name"
            showingAlert = true
            return
        }
        
        guard !lastName.isEmpty else {
            alertMessage = "Please enter your last name"
            showingAlert = true
            return
        }
        
        navigateToPreferences = true
    }
}

struct UserPreferencesView: View {
    let username: String
    let email: String
    let password: String
    let firstName: String
    let lastName: String
    let gender: String
    let birthday: Date
    
    @State private var workTimePreference = "Morning"
    @State private var workStylePreference = "long_chunks"
    @State private var goalSleepHours = 8.0
    @State private var goalSleepTime = Date()
    @State private var occupation = ""
    @State private var stressLevel = 5.0
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var navigateToMain = false
    
    let workTimeOptions = ["Morning", "Afternoon", "Night"]
    let workStyleOptions = ["long_chunks", "short_sprints"]
    
    var body: some View {
        Form {
            Section(header: Text("Work Preferences")) {
                Picker("Work Time Preference", selection: $workTimePreference) {
                    ForEach(workTimeOptions, id: \.self) { option in
                        Text(option)
                    }
                }
                
                Picker("Work Style", selection: $workStylePreference) {
                    Text("Long Focused Blocks").tag("long_chunks")
                    Text("Short Sprints").tag("short_sprints")
                }
                
                TextField("Occupation", text: $occupation)
                    .textContentType(.jobTitle)
            }
            
            Section(header: Text("Sleep Goals")) {
                VStack {
                    Text("Goal Sleep Hours: \(Int(goalSleepHours))")
                    Slider(value: $goalSleepHours, in: 4...12, step: 1)
                }
                
                DatePicker("Goal Sleep Time",
                          selection: $goalSleepTime,
                          displayedComponents: .hourAndMinute)
            }
            
            Section(header: Text("Current Status")) {
                VStack {
                    Text("Current Stress Level: \(Int(stressLevel))")
                    Slider(value: $stressLevel, in: 1...10, step: 1)
                }
            }
            
            Section {
                Button(action: completeSignUp) {
                    Text("Complete Sign Up")
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                }
                .listRowBackground(Color.fikaTeal)
            }
        }
        .navigationTitle("Preferences")
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Sign Up"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationDestination(isPresented: $navigateToMain) {
            MainTabView()
        }
    }
    
    private func completeSignUp() {
        guard !occupation.isEmpty else {
            alertMessage = "Please enter your occupation"
            showingAlert = true
            return
        }
        
        // Format the birthday as YYYY-MM-DD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let birthdayString = dateFormatter.string(from: birthday)
        
        // Format sleep time as HH:00
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: goalSleepTime)
        let sleepTimeString = String(format: "%02d:00", hour)
        
        // Map gender string to integer
        let genderMap = ["Male": 0, "Female": 1, "Non-binary": 2, "Other": 3]
        let genderValue = genderMap[gender] ?? 0
        
        // Map work time preference to integer
        let timePrefMap = ["Morning": 0, "Afternoon": 1, "Night": 2]
        let timePrefValue = timePrefMap[workTimePreference] ?? 0
        
        // Map work style preference to string
        let workStyleMap = ["long_chunks": "Long Focused Blocks", "short_sprints": "Short Sprints"]
        let workStyleValue = workStyleMap[workStylePreference] ?? "Long Focused Blocks"
        
        // First, create the initial signup request
        let initialSignupData: [String: Any] = [
            "username": username,
            "email": email,
            "password": password,
            "firstName": firstName,
            "lastName": lastName,
            "gender": genderValue,
            "birthday": birthdayString,
            "time_pref": timePrefValue,
            "work_pref": workStyleValue,
            "stress_base": Int(stressLevel)
        ]
        
        guard let initialUrl = URL(string: "http://localhost:8000/signup/initial") else {
            alertMessage = "Invalid server URL"
            showingAlert = true
            return
        }
        
        var initialRequest = URLRequest(url: initialUrl)
        initialRequest.httpMethod = "POST"
        initialRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            initialRequest.httpBody = try JSONSerialization.data(withJSONObject: initialSignupData)
        } catch {
            alertMessage = "Error preparing signup request"
            showingAlert = true
            return
        }
        
        URLSession.shared.dataTask(with: initialRequest) { [self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    alertMessage = "Network error: \(error.localizedDescription)"
                    showingAlert = true
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    alertMessage = "No data received from server"
                    showingAlert = true
                }
                return
            }
            
            // Print the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Server response: \(responseString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let userId = json["user_id"] as? Int,
                   let token = json["token"] as? String {
                    // Store the token and user ID immediately
                    UserDefaults.standard.set(userId, forKey: "userId")
                    UserDefaults.standard.set(token, forKey: "authToken")
                    UserDefaults.standard.set(firstName, forKey: "firstName")
                    
                    // Now complete the signup with preferences
                    let preferencesData: [String: Any] = [
                        "workTimePreference": workTimePreference,
                        "workStylePreference": workStylePreference,
                        "goalSleepHours": Int(goalSleepHours),
                        "goalSleepTime": sleepTimeString,
                        "occupation": occupation,
                        "stressBaseLevel": Int(stressLevel)
                    ]
                    
                    guard let preferencesUrl = URL(string: "http://localhost:8000/signup/preferences/\(userId)") else {
                        DispatchQueue.main.async {
                            alertMessage = "Invalid server URL"
                            showingAlert = true
                        }
                        return
                    }
                    
                    var preferencesRequest = URLRequest(url: preferencesUrl)
                    preferencesRequest.httpMethod = "POST"
                    preferencesRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    preferencesRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    
                    do {
                        preferencesRequest.httpBody = try JSONSerialization.data(withJSONObject: preferencesData)
                    } catch {
                        DispatchQueue.main.async {
                            alertMessage = "Error preparing preferences request"
                            showingAlert = true
                        }
                        return
                    }
                    
                    URLSession.shared.dataTask(with: preferencesRequest) { data, response, error in
                        if let error = error {
                            DispatchQueue.main.async {
                                alertMessage = "Network error: \(error.localizedDescription)"
                                showingAlert = true
                            }
                            return
                        }
                        
                        if let httpResponse = response as? HTTPURLResponse {
                            if httpResponse.statusCode == 500 {
                                if let data = data,
                                   let errorString = String(data: data, encoding: .utf8) {
                                    print("Server error details: \(errorString)")
                                }
                            }
                        }
                        
                        if let httpResponse = response as? HTTPURLResponse,
                           (200...299).contains(httpResponse.statusCode) {
                            // Navigate to main view since we already stored the token
                            DispatchQueue.main.async {
                                navigateToMain = true
                            }
                        } else {
                            DispatchQueue.main.async {
                                alertMessage = "Failed to complete signup"
                                showingAlert = true
                            }
                        }
                    }.resume()
                } else {
                    DispatchQueue.main.async {
                        alertMessage = "Invalid response from server"
                        showingAlert = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    alertMessage = "Error processing server response: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }.resume()
    }
}

#Preview {
    UserSignUp()
}
