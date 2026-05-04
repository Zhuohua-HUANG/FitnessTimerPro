import SwiftUI

struct TimerView: View {
    @EnvironmentObject var manager: WorkoutManager
    @State private var showFinishAlert: Bool = false
    var body: some View {
        let progress = manager.activeProgress
        let settings = manager.currentSettings
        
        let screenWidth = UIScreen.main.bounds.width
        let mainVStackSpacing: Double = {
            if manager.timerFontName == "Oswald-Regular" { return 4 }
            if manager.timerFontName == "SF Pro" { return 26 }
            return 20
        }()
        
        VStack(spacing: 0) {
            // Header Area
            VStack(spacing: 16) {
                // Row 1: Icons and Title
                ZStack {
                    HStack {
                        // Left: Edit Button
                        Button(action: { manager.showEditModal = true }) {
                            Image(systemName: "square.and.pencil")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                        }
                        
                        Spacer()
                        
                        // Right: Finish Button
                        Button(action: { showFinishAlert = true }) {
                            Text("完成")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .textCase(.uppercase)
                                .padding(8)
                        }
                    }
                    
                    // Center title
                    Text(manager.isFreeTrainingMode ? "自由训练" : (manager.selectedExercise?.name ?? ""))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .overlay(
                            Group {
                                if manager.selectedExercise != nil {
                                    Button(action: { manager.toggleFreeTraining() }) {
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Color.white.opacity(0.1))
                                            .clipShape(Circle())
                                    }
                                    .offset(x: -44)
                                }
                            },
                            alignment: .leading
                        )
                }
                .padding(.horizontal)
                
                // Row 2: Stats (Training Time and Rest Time)
                HStack(spacing: 12) {
                    Label {
                        Text(settings?.isTrainingTimeUnlimited == true ? "训练 ∞" : "训练\(formatDisplayTime(settings?.trainingTime ?? 0))")
                    } icon: {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.gray)
                    }
                    
                    Circle().fill(Color.gray).frame(width: 3, height: 3)
                    
                    Label {
                         Text("休息\(formatDisplayTime(settings?.restTime ?? 0))")
                    } icon: {
                        Image(systemName: "cup.and.saucer.fill")
                            .foregroundColor(.gray)
                    }
                }
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundColor(.gray)
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
            .background(Color.black.ignoresSafeArea(edges: .top))
            
            // Timer Area
            ZStack {
                // Background Status Color
                statusColor(progress.status)
                    .ignoresSafeArea()
                    .animation(.easeInOut, value: progress.status)
                
                VStack(spacing: mainVStackSpacing) {
                    VStack(spacing: 16) {
                        Text("第 \(progress.currentSet) / \(progress.totalSets) 组")
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundColor(progress.status == .restEnd ? .black.opacity(0.6) : .white.opacity(0.6))
                            .tracking(2)
                        
                        Text(progress.status.rawValue)
                            .font(.system(size: min(60, screenWidth * 0.16)))
                            .fontWeight(.black)
                            .foregroundColor(progress.status == .restEnd ? .black : .white)
                            .textCase(.uppercase)
                            .shadow(radius: progress.status == .restEnd ? 0 : 10)
                    }
                    
                    if progress.status != .restEnd {
                        let fontMultiplier: Double = {
                            if manager.timerFontName == "BebasNeue-Regular" { return 1.4 }
                            if manager.timerFontName == "Oswald-Regular" { return 1.2 }
                            if manager.timerFontName == "SF Compact" { return 1.3 }
                            return 1.0
                        }()
                        
                        // Proportional sizing based on screen width
                        // 4 digits + 1 colon should fit within ~90% of screen width
                        let availableWidth = screenWidth * 0.9
                        let digitWidth = availableWidth * 0.22
                        let colonWidth = availableWidth * 0.12
                        let baseFontSize = digitWidth * 1.5
                        let fontSize = baseFontSize * fontMultiplier
                        let baselineOffset = fontSize * 0.15
                        
                        HStack(spacing: 0) {
                            let isCountUp = progress.status == .work && (manager.isFreeTrainingMode ? manager.freeTrainingSettings.isTrainingTimeUnlimited : (manager.selectedExercise?.isTrainingTimeUnlimited ?? true))
                            let timeStr = formatTime(progress.timeLeft, isCountUp: isCountUp)
                            let chars = Array(timeStr)
                            ForEach(0..<chars.count, id: \.self) { i in
                                let char = chars[i]
                                Text(String(char))
                                    .font({
                                        if manager.timerFontName == "SF Pro" {
                                            return .system(size: fontSize, weight: .bold, design: .default)
                                        } else if manager.timerFontName == "SF Compact" {
                                            return .system(size: fontSize, weight: .bold, design: .default).width(.condensed)
                                        } else if manager.timerFontName == "SF Mono" {
                                            return .system(size: fontSize, design: .monospaced)
                                        } else if manager.timerFontName == "SF Rounded" {
                                            return .system(size: fontSize, weight: .bold, design: .rounded)
                                        } else {
                                            return .custom(manager.timerFontName, size: fontSize)
                                        }
                                    }())
                                    .foregroundColor(progress.status == .restEnd ? .black : .white)
                                    .baselineOffset(char == ":" ? baselineOffset : 0)
                                    .frame(width: char == ":" ? colonWidth : digitWidth)
                            }
                        }
                        .shadow(radius: 10)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Mute Button in Top-Right
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            manager.isMuted.toggle()
                        }) {
                            ZStack {
                                Image(systemName: manager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(progress.status == .restEnd ? .black : .white)
                                    .animation(nil, value: manager.isMuted)
                            }
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(progress.status == .restEnd ? 0.05 : 0.15))
                            .clipShape(Circle())
                        }
                        .padding(.top, 24)
                        .padding(.trailing, 24)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Controls
            HStack {
                // Previous / Reset
                Button(action: { manager.moveToPreviousPhase() }) {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color(hex: "222222"))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                // Play/Pause
                Button(action: { manager.togglePlayPause() }) {
                    let isUnlimitedWork = progress.status == .work && (settings?.isTrainingTimeUnlimited ?? false)
                    Image(systemName: (progress.status == .restEnd || (!progress.isActive && (progress.timeLeft > 0 || isUnlimitedWork))) ? "play.fill" : "pause.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.black)
                        .contentTransition(.identity)
                        .frame(width: 100, height: 100)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                        .animation(nil, value: progress.isActive)
                        .animation(nil, value: progress.status)
                }
                
                Spacer()
                
                // Next
                Button(action: { manager.moveToNextPhase(autoStart: false) }) {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(Color(hex: "222222"))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 40)
            .background(Color.black)
        }
        .overlay(
            Group {
                if showFinishAlert {
                    StandardDialog(
                        title: "完成训练？",
                        primaryTitle: "完成",
                        primaryAction: {
                            manager.stopWorkout()
                            showFinishAlert = false
                        },
                        secondaryTitle: "取消",
                        secondaryAction: { showFinishAlert = false }
                    )
                }
            }
        )
    }
    
    func formatTime(_ timeLeft: Double, isCountUp: Bool) -> String {
        let seconds = isCountUp ? Int(timeLeft) : Int(ceil(timeLeft))
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    func statusColor(_ status: TimerStatus) -> Color {
        switch status {
        case .prepare: return Color.orange
        case .work: return Color(hex: "028a0f") // Greenish
        case .rest: return Color(hex: "1C1C1E")
        case .restEnd: return Color.white
        }
    }
    
    func formatDisplayTime(_ seconds: Int) -> String {
        if seconds == 0 { return "0s" }
        let m = seconds / 60
        let s = seconds % 60
        var result = ""
        if m > 0 {
            result += " \(m) m"
        }
        if s > 0 {
            result += " \(s) s"
        }
        return result
    }
}
