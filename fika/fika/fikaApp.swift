//
//  fikaApp.swift
//  fika
//
//  Created by Makena Robison on 2/3/25.
//

import SwiftUI

struct WelcomeView: View {
    @State private var navigateToLogin = false
    @State private var navigateToSignUp = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Welcome Text
                VStack(spacing: 10) {
                    Text("Welcome to Fika")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 0) {
                        Text("Your")
                        Text("Mental Health")
                        Text("and")
                        Text("Productivity Assistant")
                    }
                    .font(.title3)
                    .foregroundColor(.fikaTeal)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Buttons
                VStack(spacing: 20) {
                    NavigationLink(destination: LoginView()) {
                        Text("Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    NavigationLink(destination: UserSignUp()) {
                        Text("Sign Up")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .navigationBarBackButtonHidden(true)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }
                .tag(0)
            
            TaskListView()
                .tabItem {
                    Label("Tasks", systemImage: "list.bullet")
                }
                .tag(1)
            
            TaskInputView()
                .tabItem {
                    Label("Add Task", systemImage: "plus.circle.fill")
                }
                .tag(2)
            
            UserHomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(3)
        }
    }
}

@main
struct fikaApp: App {
    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
    }
}
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView()
    }
}
