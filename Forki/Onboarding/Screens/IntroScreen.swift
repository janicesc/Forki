//
//  IntroScreen.swift
//  Forki
//
//  Created by Janice C on 9/23/25.
//

import SwiftUI
import AVKit

struct IntroScreen: View {
    @Binding var currentScreen: Int
    @ObservedObject var userData: UserData

    // State
    @State private var showConfetti: Bool = false

    var body: some View {
        ZStack {
            ForkiTheme.background
                .ignoresSafeArea()
            
            VStack(spacing: 28) {
                headerBranding
                
                Spacer()
                    .frame(height: 8)
                
                // Avatar View - Square frame with avatar stage styling
                ZStack {
                    // Avatar stage background - same as HomeScreen
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(ForkiTheme.avatarStageBackground)
                        .overlay(
                            // Pixelated starfield effect
                            ZStack {
                                // Small white stars
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 3, height: 3)
                                    .offset(x: -60, y: -80)
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 3, height: 3)
                                    .offset(x: 80, y: -60)
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 2, height: 2)
                                    .offset(x: -40, y: 100)
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 3, height: 3)
                                    .offset(x: 100, y: 80)
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 2, height: 2)
                                    .offset(x: -20, y: -40)
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 3, height: 3)
                                    .offset(x: 60, y: 40)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color(hex: "#7B68C4"), lineWidth: 4) // Purple border - border-4
                        )
                        .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 14)
                    
                    // Avatar video view - square, clean, centered
                    AvatarVideoView(videoName: "forki_intro")
                        .aspectRatio(1, contentMode: .fill)
                        .frame(width: min(UIScreen.main.bounds.width - 88, 300), 
                               height: min(UIScreen.main.bounds.width - 88, 300))
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .frame(width: min(UIScreen.main.bounds.width - 88, 300), 
                       height: min(UIScreen.main.bounds.width - 88, 300))
                .padding(.horizontal, 16)
                
                VStack(spacing: 12) {
                    Text("Welcome to Forki")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Your small daily habits become big progress — with a pet that grows stronger as you do.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(ForkiTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .lineSpacing(4)
                }
                .padding(.top, 8)
                
                VStack(spacing: 16) {
                    Button {
                        withAnimation(.easeInOut) { currentScreen = 1 }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                            Text("Let's Get Started!")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                        }
                        .frame(width: min(UIScreen.main.bounds.width - 88, 300))
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#8DD4D1"), Color(hex: "#6FB8B5")], // Mint gradient - same as Log Food button
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color(hex: "#7AB8B5"), lineWidth: 4) // Border color for mint button
                                )
                        )
                        .foregroundColor(.white) // White text - same as Log Food button
                        .shadow(color: ForkiTheme.actionShadow, radius: 10, x: 0, y: 6)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text("Join thousands of students boosting their habits with joy.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(ForkiTheme.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 40)
            
            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
    }


    // MARK: - Branding
    private var headerBranding: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("FORKI")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(ForkiTheme.logo)
                    .shadow(color: ForkiTheme.logoShadow.opacity(0.35), radius: 6, x: 0, y: 4)
                Text("NUTRITION PET")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                    .tracking(1.6)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("Made with love,")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                Text("by Forki")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
            }
        }
    }
}


// MARK: - Confetti
struct ConfettiView: View {
    @State private var particles: [UUID] = (0..<30).map { _ in UUID() }
    var body: some View {
        GeometryReader { geo in
            ForEach(particles, id: \.self) { _ in
                Circle()
                    .fill([Color.red, .yellow, .green, .blue, .pink, .purple].randomElement()!)
                    .frame(width: 8, height: 8)
                    .position(x: .random(in: 0..<geo.size.width),
                              y: .random(in: 0..<geo.size.height/2))
            }
        }
    }
}


// MARK: - Avatar Video View
struct AvatarVideoView: View {
    let videoName: String
    @State private var player: AVPlayer?
    
    init(videoName: String = "forki_intro") {
        self.videoName = videoName
    }
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(contentMode: .fill)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                // Fallback placeholder while video loads
                Color.clear
            }
        }
        .onAppear {
            setupVideo()
        }
    }
    
    private func setupVideo() {
        guard let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            print("Could not find \(videoName).mp4")
            return
        }
        
        // Clean up previous player and observers
        if let existingPlayer = player {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: existingPlayer.currentItem)
        }
        
        let newPlayer = AVPlayer(url: url)
        newPlayer.actionAtItemEnd = .none
        
        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        self.player = newPlayer
        newPlayer.play()
    }
}

#Preview {
    IntroScreen(currentScreen: .constant(0), userData: UserData())
}

