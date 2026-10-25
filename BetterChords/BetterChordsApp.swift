//
//  BetterChordsApp.swift
//  BetterChords
//
//  Created by Brian Mahne on 8/11/26.
//

import SwiftUI

@main
struct BetterChordsApp: App {
    @State private var showingSplash = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                if showingSplash {
                    GeometryReader { geometry in
                        ZStack {
                            Color(red: 0.01, green: 0.02, blue: 0.06)
                            Image("SplashArtwork")
                                .resizable()
                                .scaledToFit()
                                .frame(width: min(geometry.size.width, geometry.size.height) * 0.9)
                                .accessibilityLabel("Better Chords")
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .task {
                guard showingSplash else { return }
                do { try await Task.sleep(for: .seconds(1.2)) } catch { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    showingSplash = false
                }
            }
        }
    }
}
