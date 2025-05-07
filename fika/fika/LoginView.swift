import SwiftUI

struct LoginView: View {
    @State private var usernameOrEmail = ""
    @State private var password = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @State private var navigateToMain = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Login")) {
                    TextField("Username or Email", text: $usernameOrEmail)
                        .textContentType(.username)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: login) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Login")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                        }
                    }
                    .listRowBackground(Color.fikaTeal)
                    .disabled(isLoading)
                }
                
                Section {
                    NavigationLink(destination: UserSignUp()) {
                        Text("Don't have an account? Sign Up")
                            .foregroundColor(.fikaTeal)
                    }
                }
            }
            .navigationTitle("Login")
            .alert(isPresented: $showingAlert) {
                Alert(
                    title: Text("Login"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationDestination(isPresented: $navigateToMain) {
                MainTabView()
            }
        }
    }
    
    private func login() {
        // Validate inputs
        guard !usernameOrEmail.isEmpty else {
            alertMessage = "Please enter your username or email"
            showingAlert = true
            return
        }
        
        guard !password.isEmpty else {
            alertMessage = "Please enter your password"
            showingAlert = true
            return
        }
        
        isLoading = true
        
        // Create login request
        let loginData = [
            "username_or_email": usernameOrEmail,
            "password": password
        ]
        
        guard let url = URL(string: "http://localhost:8000/login") else {
            alertMessage = "Invalid server URL"
            showingAlert = true
            isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: loginData)
        } catch {
            alertMessage = "Error preparing login request"
            showingAlert = true
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    alertMessage = "Network error: \(error.localizedDescription)"
                    showingAlert = true
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    alertMessage = "Invalid server response"
                    showingAlert = true
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    alertMessage = "Login failed: Invalid credentials"
                    showingAlert = true
                    return
                }
                
                guard let data = data else {
                    alertMessage = "No data received from server"
                    showingAlert = true
                    return
                }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let token = json["token"] as? String,
                       let userId = json["user_id"] as? Int {
                        // Store the token and user ID securely
                        UserDefaults.standard.set(token, forKey: "authToken")
                        UserDefaults.standard.set(userId, forKey: "userId")
                        // Fetch first name after login
                        fetchAndStoreFirstName(userId: userId, token: token)
                        // Navigate to main tab view
                        navigateToMain = true
                    } else {
                        alertMessage = "Invalid response format"
                        showingAlert = true
                    }
                } catch {
                    alertMessage = "Error processing server response"
                    showingAlert = true
                }
            }
        }.resume()
    }
    
    // Add this function to fetch the user's first name after login
    private func fetchAndStoreFirstName(userId: Int, token: String) {
        guard let url = URL(string: "http://localhost:8000/user/\(userId)") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let firstName = json["first_name"] as? String else { return }
            UserDefaults.standard.set(firstName, forKey: "firstName")
        }.resume()
    }
}

#Preview {
    LoginView()
}
