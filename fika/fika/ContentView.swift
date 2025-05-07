//
//  ContentView.swift
//  fika
//
//  Created by Makena Robison on 2/3/25.
//

import SwiftUI

extension Color {
    static let fikaTeal = Color(red: 17/255, green: 57/255, blue: 57/255)
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
