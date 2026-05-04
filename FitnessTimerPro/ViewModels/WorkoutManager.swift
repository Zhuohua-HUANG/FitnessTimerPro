import SwiftUI
import Combine
import AudioToolbox
import AVFoundation

enum ToastStyle {
    case info    // Gray background
    case success // Green background
    case error   // Red background
}

class WorkoutManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = WorkoutManager()
    
    @Published var selectedDate: Date = Calendar.current.startOfDay(for: Date()) {
        didSet { saveState() }
    }
    @Published var showAddModal: Bool = false
    @Published var showEditModal: Bool = false
    @Published var pendingExercise: Exercise? = nil
    @Published var deletingExercise: Exercise? = nil
    @Published var editingExercise: Exercise? = nil
    @Published var isAIExpanded: Bool = true

    
    @Published var allExercises: [Exercise] = [] {
        didSet { 
            updateCaches()
        }
    }
    
    @Published var weeklyRepeatExercises: [WeeklyRepeatExercise] = [] {
        didSet {
            updateCaches()
        }
    }
    
    // Free Training State
    @Published var isFreeTrainingMode: Bool = true
    @Published var freeTrainingSettings: Exercise = Exercise(id: "free", name: "自由训练", completed: false, sets: 4, restTime: 60, trainingTime: -1) // -1 for unlimited
    @Published var freeTrainingProgress = WorkoutState(currentSet: 1, totalSets: 4, status: .prepare, timeLeft: 5.0, isActive: false)
    @Published var freeTrainingStartTime: Date? = nil
    
    // Selected Exercise State
    @Published var selectedExercise: Exercise? = nil
    @Published var exerciseProgress = WorkoutState(currentSet: 1, totalSets: 0, status: .prepare, timeLeft: 5.0, isActive: false)
    @Published var exerciseStartTime: Date? = nil
    
    // Performance Caching
    @Published var cachedCompletedDates: Set<String> = []
    @Published var cachedUncompletedDates: Set<String> = []
    @Published var cachedHasExercisesDates: Set<String> = []
    
    private var timerCancellable: AnyCancellable?
    private var foregroundObserver: Any?
    @Published var calendarPath: [String] = [] {
        didSet { saveState() }
    }
    @Published var settingsPath: [SettingsDestination] = []
    
    var calendarMode: CalendarMode {
        calendarPath.isEmpty ? .year : .month
    }
    
    private var audioPlayer: AVAudioPlayer?
    private var silentPlayer: AVAudioPlayer?
    private var currentlyPlayingSoundName: String? = nil
    
    @Published var currentView: AppView = .timer {
        didSet { saveState() }
    }
    
    @Published var celebrationCounter: Int = 0
    @Published var isMuted: Bool = false {
        didSet {
            UserDefaults.standard.set(isMuted, forKey: isMutedKey)
            saveState()
            if isMuted {
                audioPlayer?.stop()
                currentlyPlayingSoundName = nil
            } else {
                // If unmuting while active and in the last 3 seconds, resume countdown
                if activeProgress.isActive {
                    checkAndResumeCountdown()
                }
            }
        }
    }
    @Published var timerFontName: String = "BebasNeue-Regular" {
        didSet {
            UserDefaults.standard.set(timerFontName, forKey: timerFontNameKey)
            saveState()
        }
    }
    
    let availableFonts = [
        "BebasNeue-Regular",
        "SF Pro",
        "SF Rounded",
        "SF Compact",
        "Oswald-Regular"
    ]
    
    @Published var justCompletedId: String? = nil
    @Published var scrollTargetId: String? = nil
    @Published var toastMessage: String? = nil
    @Published var toastStyle: ToastStyle = .info

    
    private let calendarModeKey = "FitnessTimerPro_calendarMode"
    private let selectedDateKey = "FitnessTimerPro_selectedDate"
    private let currentViewKey = "FitnessTimerPro_currentView"
    private let freeTrainingKey = "FitnessTimerPro_freeTrainingSettings"
    private let isMutedKey = "FitnessTimerPro_isMuted"
    private let timerFontNameKey = "FitnessTimerPro_timerFontName"
    
    override init() {
        super.init()
        // Load Saved State
        if let modeStr = UserDefaults.standard.string(forKey: calendarModeKey),
           let mode = CalendarMode(rawValue: modeStr) {
            self.calendarPath = mode == .month ? ["month"] : []
        }
        
        if let viewStr = UserDefaults.standard.string(forKey: currentViewKey),
           let view = AppView(rawValue: viewStr) {
            self.currentView = view
        }
        
        self.isMuted = UserDefaults.standard.bool(forKey: isMutedKey)
        self.timerFontName = UserDefaults.standard.string(forKey: timerFontNameKey) ?? "BebasNeue-Regular"
        
        let savedTimestamp = UserDefaults.standard.double(forKey: selectedDateKey)
        if savedTimestamp > 0 {
            self.selectedDate = Date(timeIntervalSince1970: savedTimestamp)
        }
        
        // Apply Restart Logic: Always default to Today for positioning/selection
        self.selectedDate = Calendar.current.startOfDay(for: Date())
        
        // Load Free Training Settings
        if let data = UserDefaults.standard.data(forKey: freeTrainingKey) {
            do {
                self.freeTrainingSettings = try JSONDecoder().decode(Exercise.self, from: data)
                self.freeTrainingProgress.totalSets = self.freeTrainingSettings.sets
            } catch {
                print("Failed to decode free training settings: \(error)")
            }
        }
        
        // Load from data stores (SQLite)
        self.allExercises = ExerciseStore.shared.getAll()
        self.weeklyRepeatExercises = WeeklyRepeatStore.shared.getAll()
        
        updateCaches()
        
        setupAudioSession()
        setupNotificationObservers()
        setupAudioNotifications()
        startTimer()
    }
    
    // MARK: - Weekly Repeat CRUD
    
    func addWeeklyRepeat(name: String, sets: Int, rest: Int, trainingTime: Int, repeatDays: [Int], tag: Int? = nil) {
        let newRepeat = WeeklyRepeatExercise(
            id: WeeklyRepeatStore.shared.allocateNewId(),
            name: name,
            sets: sets,
            trainingTime: trainingTime,
            restTime: rest,
            repeatDays: repeatDays,
            createdAt: Date(),
            updatedAt: Date(),
            tag: tag
        )
        weeklyRepeatExercises.append(newRepeat)
        WeeklyRepeatStore.shared.update(newRepeat)
    }
    
    private func setupNotificationObservers() {
        foregroundObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.manageSilentAudio() // Re-check audio state when returning
        }
    }
    
    private func setupAudioNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        
        if type == .began {
            print("Audio interrupted (began)")
        } else if type == .ended {
            print("Audio interruption ended")
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    manageSilentAudio()
                }
            }
        }
    }
    
    private func setupAudioSession() {
        do {
            // Default: Mix with others, do NOT duck by default. We only duck when playing the alert.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
    }
    
    
    private func saveState() {
        let modeToSave: CalendarMode = calendarPath.isEmpty ? .year : .month
        UserDefaults.standard.set(modeToSave.rawValue, forKey: calendarModeKey)
        UserDefaults.standard.set(selectedDate.timeIntervalSince1970, forKey: selectedDateKey)
        UserDefaults.standard.set(currentView.rawValue, forKey: currentViewKey)
    }
    
    // MARK: - Exercise CRUD (via ExerciseStore)
    
    private func saveFreeTrainingSettings() {
        do {
            let data = try JSONEncoder().encode(freeTrainingSettings)
            UserDefaults.standard.set(data, forKey: freeTrainingKey)
        } catch {
            print("Failed to encode free training settings: \(error)")
        }
    }
    
    // MARK: - Computeds
    
    var activeProgress: WorkoutState {
        isFreeTrainingMode ? freeTrainingProgress : exerciseProgress
    }
    
    var currentSettings: Exercise? {
        isFreeTrainingMode ? freeTrainingSettings : selectedExercise
    }
    
    func exercisesForSelectedDate(_ date: Date? = nil) -> [Exercise] {
        let targetDate = date ?? selectedDate
        let dateStr = dateFormatter.string(from: targetDate)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: targetDate) - 1
        
        // 1. Get actual exercises for this date
        var exercises = allExercises.filter { $0.date == dateStr }
        
        // 2. Get projections from weekly repeats
        let projections = weeklyRepeatExercises.filter { repeatEx in
            let start = calendar.startOfDay(for: repeatEx.createdAt)
            let current = calendar.startOfDay(for: targetDate)
            
            // Must repeat on this weekday, targetDate >= repeatEx.createdAt
            let isActive = current >= start
            
            return repeatEx.repeatDays.contains(weekday) && isActive
        }
        
        for repeatEx in projections {
            // Check if we already have an actual exercise linked to this repeat for this date
            if !exercises.contains(where: { $0.weeklyRepeatId == repeatEx.id }) {
                // If not, add a virtual one
                let virtual = Exercise(
                    id: "repeat-\(repeatEx.id)-\(dateStr)",
                    name: repeatEx.name,
                    completed: false,
                    sets: repeatEx.sets,
                    restTime: repeatEx.restTime,
                    trainingTime: repeatEx.trainingTime,
                    date: dateStr,
                    createdAt: repeatEx.createdAt,
                    tag: repeatEx.tag,
                    weeklyRepeatId: repeatEx.id
                )
                exercises.append(virtual)
            }
        }
        
        return exercises.sorted { ($0.createdAt) < ($1.createdAt) }
    }
    
    private func updateCaches() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .month, value: -1, to: today)!
        
        // Calculate the end of the next-next year to match YearView coverage
        let currentYear = calendar.component(.year, from: today)
        var components = DateComponents()
        components.year = currentYear + 2
        components.month = 12
        components.day = 31
        let end = calendar.date(from: components)!
        
        // Optimization: Group actual exercises once
        let groupedExercises = Dictionary(grouping: allExercises) { $0.date ?? "" }
        
        var completed = Set<String>()
        var uncompleted = Set<String>()
        var hasEx = Set<String>()
        
        var d = start
        while d <= end {
            let dateStr = dateFormatter.string(from: d)
            let weekday = calendar.component(.weekday, from: d) - 1
            
            // 1. Get actual exercises
            var dayExes = groupedExercises[dateStr] ?? []
            
            // 2. Add potential repeats
            let projections = weeklyRepeatExercises.filter { repeatEx in
                let start = calendar.startOfDay(for: repeatEx.createdAt)
                let current = calendar.startOfDay(for: d)
                let isActive = current >= start
                return repeatEx.repeatDays.contains(weekday) && isActive
            }
            
            for repeatEx in projections {
                if !dayExes.contains(where: { $0.weeklyRepeatId == repeatEx.id }) {
                    // Equivalent to adding a virtual exercise
                    // We only care if it's there and if it's completed (virtual is never completed)
                    // So we can just say this day has uncompleted exercises
                    dayExes.append(Exercise(id: "v", name: "", completed: false, sets: 0, restTime: 0, trainingTime: 0))
                }
            }
            
            if !dayExes.isEmpty {
                hasEx.insert(dateStr)
                if dayExes.allSatisfy({ $0.completed }) {
                    completed.insert(dateStr)
                } else {
                    uncompleted.insert(dateStr)
                }
            }
            d = calendar.date(byAdding: .day, value: 1, to: d)!
        }
        
        cachedCompletedDates = completed
        cachedUncompletedDates = uncompleted
        cachedHasExercisesDates = hasEx
    }
    
    var completedDateStrings: Set<String> { cachedCompletedDates }
    var uncompletedDateStrings: Set<String> { cachedUncompletedDates }
    var hasExercisesDateStrings: Set<String> { cachedHasExercisesDates }
    
    // MARK: - Actions

    func saveSettings(id: String, name: String, sets: Int, rest: Int, trainingTime: Int, repeatDays: [Int]? = nil, tag: Int? = nil, date: String? = nil) {
        if isFreeTrainingMode && id.isEmpty {
             let timeChanged = (freeTrainingSettings.trainingTime != trainingTime) || (freeTrainingSettings.restTime != rest)
             
             freeTrainingSettings.sets = sets
             freeTrainingSettings.restTime = rest
             freeTrainingSettings.trainingTime = trainingTime
             freeTrainingSettings.updatedAt = Date()
             
             freeTrainingProgress.totalSets = sets
             
             if timeChanged && freeTrainingProgress.status != .prepare && freeTrainingProgress.status != .restEnd {
                  freeTrainingProgress.isActive = false
                  if freeTrainingProgress.status == .work {
                      freeTrainingProgress.timeLeft = Double(trainingTime == -1 ? 0 : trainingTime)
                  } else if freeTrainingProgress.status == .rest {
                      freeTrainingProgress.timeLeft = Double(rest)
                  }
                  updateReferenceDate(state: &freeTrainingProgress)
                  freeTrainingProgress.hasPlayedCountdown = false
                  
                  audioPlayer?.stop()
                  currentlyPlayingSoundName = nil
             }
             saveFreeTrainingSettings()
             return
        }

        // --- Planned Exercises (by ID) ---
        // Fetch source data directly by the provided ID
        var editingExResource: Exercise? = ExerciseStore.shared.get(byId: id)
        
        // Handle virtual/recurring ID mapping (repeat-{id} or repeat-{id}-{date})
        if editingExResource == nil && id.hasPrefix("repeat-") {
            let parts = id.components(separatedBy: "-")
            if parts.count >= 2 {
                let planId = parts[1]
                if let plan = WeeklyRepeatStore.shared.get(byId: planId) {
                    let dateStr = parts.count >= 5 ? "\(parts[2])-\(parts[3])-\(parts[4])" : dateFormatter.string(from: selectedDate)
                    editingExResource = Exercise(
                        id: id,
                        name: plan.name,
                        completed: false,
                        sets: plan.sets,
                        restTime: plan.restTime,
                        trainingTime: plan.trainingTime,
                        date: dateStr,
                        createdAt: plan.createdAt,
                        tag: plan.tag,
                        weeklyRepeatId: plan.id
                    )
                }
            }
        }
        
        // Secondary fallback: check local list if DB fetch failed (might match a volatile selectedExercise)
        if editingExResource == nil && !id.isEmpty {
            editingExResource = allExercises.first(where: { $0.id == id })
        }

        guard let editingEx = editingExResource else {
            print("❌ [WorkoutManager] saveSettings: Record not found for ID: \(id)")
            return
        }

        let wasRecurring = editingEx.weeklyRepeatId != nil
        let wantsRecurring = (repeatDays != nil && !repeatDays!.isEmpty)
        let isCompleted = editingEx.completed

        // ── Case A: Was recurring, stays recurring → update plan in place
        if wasRecurring && wantsRecurring {
            if let repeatId = editingEx.weeklyRepeatId {
                if var plan = WeeklyRepeatStore.shared.get(byId: repeatId) {
                    plan.name = name
                    plan.sets = sets
                    plan.trainingTime = trainingTime
                    plan.restTime = rest
                    plan.repeatDays = repeatDays!
                    plan.updatedAt = Date()
                    plan.tag = tag
                    
                    WeeklyRepeatStore.shared.update(plan)
                    if let idx = weeklyRepeatExercises.firstIndex(where: { $0.id == plan.id }) {
                        weeklyRepeatExercises[idx] = plan
                    }
                    // Update active selectedExercise if it's derived from this plan
                    if let sel = selectedExercise, sel.weeklyRepeatId == plan.id {
                        var updatedSel = sel
                        updatedSel.name = name
                        updatedSel.sets = sets
                        updatedSel.trainingTime = trainingTime
                        updatedSel.restTime = rest
                        updatedSel.tag = tag
                        selectedExercise = updatedSel
                        exerciseProgress.totalSets = sets
                    }
                }
            }
        }

        // ── Case B: Was recurring → convert to one-time
        if wasRecurring && !wantsRecurring {
            let repeatId = editingEx.weeklyRepeatId

            // Unlink any session exercise for today targeting this plan
            if let rid = repeatId {
                let todayStr = dateFormatter.string(from: Date())
                let existingRecord = ExerciseStore.shared.filter { $0.weeklyRepeatId == rid && $0.date == todayStr }.first
                if var record = existingRecord {
                    record.weeklyRepeatId = nil
                    record.updatedAt = Date()
                    ExerciseStore.shared.update(record)
                    if let i = allExercises.firstIndex(where: { $0.id == record.id }) {
                        allExercises[i] = record
                    }
                }
            }

            // Purge the recurring plan
            if let rid = repeatId {
                WeeklyRepeatStore.shared.delete(byId: rid)
                weeklyRepeatExercises.removeAll(where: { $0.id == rid })
            }

            if isCompleted {
                if var record = ExerciseStore.shared.get(byId: editingEx.id) {
                    record.name = name
                    record.sets = sets
                    record.restTime = rest
                    record.trainingTime = trainingTime
                    record.updatedAt = Date()
                    record.tag = tag
                    record.weeklyRepeatId = nil
                    ExerciseStore.shared.update(record)
                    if let i = allExercises.firstIndex(where: { $0.id == record.id }) {
                        allExercises[i] = record
                    }
                }
            } else {
                allExercises.removeAll(where: { $0.id == editingEx.id })
                if !editingEx.id.hasPrefix("repeat-") {
                     ExerciseStore.shared.delete(byId: editingEx.id)
                }
                
                let dateStr = dateFormatter.string(from: selectedDate)
                let newEx = Exercise(
                    id: ExerciseStore.shared.allocateNewId(),
                    name: name,
                    completed: false,
                    sets: sets,
                    restTime: rest,
                    trainingTime: trainingTime,
                    date: dateStr,
                    createdAt: Date(),
                    tag: tag
                )
                allExercises.append(newEx)
                // Use update instead of insert because allocateNewId already performed a dummy insert
                ExerciseStore.shared.update(newEx)
            }

            editingExercise = nil
            return
        }

        // ── Case C: Was one-time → convert to recurring
        if !wasRecurring && wantsRecurring {
            let newRepeat = WeeklyRepeatExercise(
                id: WeeklyRepeatStore.shared.allocateNewId(),
                name: name,
                sets: sets,
                trainingTime: trainingTime,
                restTime: rest,
                repeatDays: repeatDays!,
                createdAt: editingEx.createdAt,
                updatedAt: Date(),
                tag: tag
            )
            weeklyRepeatExercises.append(newRepeat)
            WeeklyRepeatStore.shared.update(newRepeat)

            if isCompleted {
                if var record = ExerciseStore.shared.get(byId: editingEx.id) {
                    record.name = name
                    record.sets = sets
                    record.restTime = rest
                    record.trainingTime = trainingTime
                    record.updatedAt = Date()
                    record.tag = tag
                    record.weeklyRepeatId = newRepeat.id
                    ExerciseStore.shared.update(record)
                    if let i = allExercises.firstIndex(where: { $0.id == record.id }) {
                        allExercises[i] = record
                    }
                }
            } else {
                allExercises.removeAll(where: { $0.id == editingEx.id })
                ExerciseStore.shared.delete(byId: editingEx.id)
            }

            editingExercise = nil
            return
        }

        // ── Case D: Was one-time, stays one-time
        if !wasRecurring && !wantsRecurring {
            if var record = ExerciseStore.shared.get(byId: editingEx.id) {
                let isActiveEx = (selectedExercise?.id == record.id)
                let timeChanged = (record.trainingTime != trainingTime) || (record.restTime != rest)
                
                record.name = name
                record.sets = sets
                record.restTime = rest
                record.trainingTime = trainingTime
                record.updatedAt = Date()
                record.tag = tag
                if let d = date {
                    record.date = d
                }
                
                ExerciseStore.shared.update(record)
                if let i = allExercises.firstIndex(where: { $0.id == record.id }) {
                    allExercises[i] = record
                }
                
                if isActiveEx {
                    selectedExercise = record
                    exerciseProgress.totalSets = sets
                    if timeChanged && exerciseProgress.status != .prepare && exerciseProgress.status != .restEnd {
                        exerciseProgress.isActive = false
                        if exerciseProgress.status == .work {
                            exerciseProgress.timeLeft = Double(trainingTime == -1 ? 0 : trainingTime)
                        } else if exerciseProgress.status == .rest {
                            exerciseProgress.timeLeft = Double(rest)
                        }
                        updateReferenceDate(state: &exerciseProgress)
                        exerciseProgress.hasPlayedCountdown = false
                        audioPlayer?.stop()
                        currentlyPlayingSoundName = nil
                    }
                }
            }
        }
        
        editingExercise = nil
    }
    
    /// Requests to start an exercise, showing a confirmation if another exercise is already active.
    func requestStartExercise(_ ex: Exercise) {
        if !ex.completed {
            if selectedExercise?.id == ex.id {
                // Already selected, just switch to it and show the timer
                isFreeTrainingMode = false
                withAnimation(.easeInOut(duration: 0.4)) {
                    currentView = .timer
                }
            } else if selectedExercise == nil {
                startExercise(ex)
            } else {
                // Show confirmation dialog (handled by overlay in views)
                pendingExercise = ex
            }
        }
    }
    
    func startExercise(_ ex: Exercise) {
        AudioServicesPlaySystemSound(1057) // "Ding" for starting
        selectedExercise = ex
        exerciseStartTime = Date()
        exerciseProgress = WorkoutState(currentSet: 1, totalSets: ex.sets, status: .prepare, timeLeft: 5, isActive: false)
        
        // Pause free training if active
        if isFreeTrainingMode {
            freeTrainingProgress.isActive = false
        }
        
        isFreeTrainingMode = false
        updateReferenceDate(state: &exerciseProgress)
        withAnimation(.easeInOut(duration: 0.4)) {
            currentView = .timer
        }
    }
    
    func toggleFreeTraining() {
        if isFreeTrainingMode {
            // Switch to Selected
            if selectedExercise != nil {
                freeTrainingProgress.isActive = false
                isFreeTrainingMode = false
            }
        } else {
            // Switch to Free
            exerciseProgress.isActive = false
            isFreeTrainingMode = true
            if freeTrainingStartTime == nil {
                freeTrainingStartTime = Date()
            }
        }
    }
    
    func togglePlayPause() {
        if isFreeTrainingMode {
            if freeTrainingProgress.status == .restEnd {
                moveToNextPhase()
                return
            }
            if freeTrainingStartTime == nil { freeTrainingStartTime = Date() }
            freeTrainingProgress.isActive.toggle()
            updateReferenceDate(state: &freeTrainingProgress)
            if !freeTrainingProgress.isActive {
                audioPlayer?.stop()
                currentlyPlayingSoundName = nil
            } else {
                // Resume countdown if within 3s window
                checkAndResumeCountdown()
            }
        } else {
            if exerciseProgress.status == .restEnd {
                moveToNextPhase()
                return
            }
            exerciseProgress.isActive.toggle()
            updateReferenceDate(state: &exerciseProgress)
            if !exerciseProgress.isActive {
                audioPlayer?.stop()
                currentlyPlayingSoundName = nil
            } else {
                // Resume countdown if within 3s window
                checkAndResumeCountdown()
            }
        }
        
        manageSilentAudio()
    }
    private func checkAndResumeCountdown() {
        guard let settings = currentSettings else { return }
        let progress = activeProgress
        
        if progress.timeLeft > 0 && progress.timeLeft <= 3.0 && progress.status != .restEnd && !(progress.status == .work && settings.isTrainingTimeUnlimited) {
            
            // Re-mark as having played so we don't trigger again in timer update
            if isFreeTrainingMode {
                freeTrainingProgress.hasPlayedCountdown = true
            } else {
                exerciseProgress.hasPlayedCountdown = true
            }
            
            if progress.status == .prepare || progress.status == .work {
                self.playEndCountingWithEndStateSound()
            } else {
                self.playEndCountingSound()
            }
        }
    }
    
    func stopWorkout() {
        let today = Date()
        let todayStr = dateFormatter.string(from: today)
        
        if isFreeTrainingMode {
            let duration = freeTrainingStartTime != nil ? Int(today.timeIntervalSince(freeTrainingStartTime!)) : 0
            let newRecord = Exercise(
                id: "free-\(today.timeIntervalSince1970)",
                name: "自由训练",
                completed: true,
                sets: freeTrainingSettings.sets,
                restTime: freeTrainingSettings.restTime,
                trainingTime: freeTrainingSettings.trainingTime,
                actualSets: freeTrainingProgress.currentSet,
                totalTime: duration,
                date: todayStr
            )
            allExercises.append(newRecord)
            justCompletedId = newRecord.id
            
            // Reset
            freeTrainingProgress = WorkoutState(currentSet: 1, totalSets: freeTrainingSettings.sets, status: .prepare, timeLeft: 5.0, isActive: false)
            freeTrainingStartTime = nil
            
        } else if let ex = selectedExercise {
            let duration = exerciseStartTime != nil ? Int(today.timeIntervalSince(exerciseStartTime!)) : 0
            
            if ex.id.hasPrefix("repeat-"), let repeatId = ex.weeklyRepeatId {
                // This was a virtual exercise from a weekly repeat.
                // Insert it as a REAL exercise into allExercises.
                let newRecord = Exercise(
                    id: ExerciseStore.shared.allocateNewId(),
                    name: ex.name,
                    completed: true,
                    sets: ex.sets,
                    restTime: ex.restTime,
                    trainingTime: ex.trainingTime,
                    actualSets: exerciseProgress.currentSet,
                    totalTime: duration,
                    date: todayStr,
                    createdAt: ex.createdAt,
                    updatedAt: Date(),
                    tag: ex.tag,
                    weeklyRepeatId: repeatId
                )
                allExercises.append(newRecord)
                ExerciseStore.shared.update(newRecord)
                justCompletedId = newRecord.id
            } else if let index = allExercises.firstIndex(where: { $0.id == ex.id }) {
                var updated = allExercises[index]
                updated.completed = true
                updated.actualSets = exerciseProgress.currentSet
                updated.totalTime = duration
                allExercises[index] = updated
                ExerciseStore.shared.update(updated)
                justCompletedId = updated.id
            }
            
            exerciseProgress.isActive = false
            selectedExercise = nil
            isFreeTrainingMode = true
        }

        // Notify AI to close chat if it's open
        AIService.shared.shouldCloseChat = true
        
        // Auto-select today so the user sees their freshly saved workout
        selectedDate = Calendar.current.startOfDay(for: today)
        calendarPath = ["month"]
        currentView = .calendar
        
        // Trigger celebration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.celebrationCounter += 1
        }
        
        // Clear justCompletedId after some time so animation doesn't repeat on every scroll
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.justCompletedId = nil
        }
        
        manageSilentAudio()
        audioPlayer?.stop()
    }
    
    func moveToNextPhase(autoStart: Bool = true, isManual: Bool = true) {
        guard let settings = currentSettings else { return }
        
        if isManual {
            audioPlayer?.stop()
            currentlyPlayingSoundName = nil
        }
        
        let updateFn: (WorkoutState) -> WorkoutState = { prev in
            if prev.status == .prepare {
                let tTime = settings.isTrainingTimeUnlimited ? 0.0 : Double(settings.trainingTime)
                return WorkoutState(currentSet: prev.currentSet, totalSets: prev.totalSets, status: .work, timeLeft: tTime, isActive: autoStart)
            } else if prev.status == .work {
                return WorkoutState(currentSet: prev.currentSet, totalSets: prev.totalSets, status: .rest, timeLeft: Double(settings.restTime), isActive: autoStart)
            } else if prev.status == .rest {
                // Return to RestEnd
                if autoStart {
                    self.playRestEndSound()
                }
                return WorkoutState(currentSet: prev.currentSet, totalSets: prev.totalSets, status: .restEnd, timeLeft: 0.0, isActive: false)
            } else {
                // restEnd -> next set prepare (No start sound for prepare phase)
                let nextSet = prev.currentSet + 1
                return WorkoutState(currentSet: nextSet, totalSets: prev.totalSets, status: .prepare, timeLeft: 5.0, isActive: autoStart)
            }
        }
        
        if isFreeTrainingMode {
            freeTrainingProgress = updateFn(freeTrainingProgress)
            updateReferenceDate(state: &freeTrainingProgress)
        } else {
            exerciseProgress = updateFn(exerciseProgress)
            updateReferenceDate(state: &exerciseProgress)
        }
        manageSilentAudio()
    }

    func moveToPreviousPhase() {
        guard let settings = currentSettings else { return }
        audioPlayer?.stop()
        
        let currentState = activeProgress
        let isUnlimited = (currentState.status == .work && settings.isTrainingTimeUnlimited)
        
        // Determine if we've started the current phase (threshold of 0.1s to avoid tiny jitters)
        let hasStarted: Bool
        switch currentState.status {
        case .prepare:
            hasStarted = currentState.timeLeft < 4.9
        case .work:
            hasStarted = isUnlimited ? (currentState.timeLeft > 0.1) : (currentState.timeLeft < Double(settings.trainingTime) - 0.1)
        case .rest:
            hasStarted = currentState.timeLeft < Double(settings.restTime) - 0.1
        case .restEnd:
            hasStarted = false // RestEnd is a momentary state
        }
        
        if hasStarted {
            // Logic 1: Midway -> Reset current phase and pause
            resetTimer()
            return
        }
        
        // Logic 2: At start -> Jump to previous logical phase
        let updateFn: (WorkoutState) -> WorkoutState = { prev in
            var newState = prev
            newState.isActive = false // Always pause when jumping back
            
            switch prev.status {
            case .prepare:
                if prev.currentSet > 1 {
                    // Back to previous set's RestEnd
                    return WorkoutState(currentSet: prev.currentSet - 1, totalSets: prev.totalSets, status: .restEnd, timeLeft: 0.0, isActive: false)
                }
                // At very first set start, just reset to start of Prepare
                newState.timeLeft = 5.0
            case .work:
                // Work -> Prepare
                newState.status = .prepare
                newState.timeLeft = 5.0
            case .rest:
                // Rest -> Work
                newState.status = .work
                newState.timeLeft = settings.isTrainingTimeUnlimited ? 0.0 : Double(settings.trainingTime)
            case .restEnd:
                // RestEnd -> Rest
                newState.status = .rest
                newState.timeLeft = Double(settings.restTime)
            }
            newState.hasPlayedCountdown = false
            return newState
        }
        
        if isFreeTrainingMode {
            freeTrainingProgress = updateFn(freeTrainingProgress)
            updateReferenceDate(state: &freeTrainingProgress)
        } else {
            exerciseProgress = updateFn(exerciseProgress)
            updateReferenceDate(state: &exerciseProgress)
        }
        manageSilentAudio()
    }
    
    func resetTimer() {
        guard let settings = currentSettings else { return }
        let resetFn: (WorkoutState) -> WorkoutState = { prev in
            var newState = prev
            newState.isActive = false
            switch prev.status {
            case .prepare:
                newState.timeLeft = 5.0
            case .work:
                newState.timeLeft = settings.isTrainingTimeUnlimited ? 0.0 : Double(settings.trainingTime)
            case .rest:
                newState.timeLeft = Double(settings.restTime)
            case .restEnd:
                newState.timeLeft = 0.0
            }
            newState.hasPlayedCountdown = false
            self.audioPlayer?.stop()
            self.currentlyPlayingSoundName = nil
            return newState
        }
        if isFreeTrainingMode {
            freeTrainingProgress = resetFn(freeTrainingProgress)
            updateReferenceDate(state: &freeTrainingProgress)
        } else {
            exerciseProgress = resetFn(exerciseProgress)
            updateReferenceDate(state: &exerciseProgress)
        }
    }
    
    // MARK: - Helpers
    private var dateFormatter: DateFormatter {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        // Ensure consistent locale to avoid unexpected format changes
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        return fmt
    }
    
    func dateFormatter(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }

    func addExercise(name: String, sets: Int, rest: Int, trainingTime: Int, tag: Int? = nil, date: String? = nil) {
        let dateStr = date ?? dateFormatter.string(from: selectedDate)
        print("Adding Exercise: \(name) for date: \(dateStr)")
        let newEx = Exercise(id: ExerciseStore.shared.allocateNewId(), name: name, completed: false, sets: sets, restTime: rest, trainingTime: trainingTime, date: dateStr, tag: tag)
        allExercises.append(newEx)
        
        // Trigger scroll to the new item
        self.scrollTargetId = newEx.id
        
        // Clear scroll target after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.scrollTargetId == newEx.id {
                self.scrollTargetId = nil
            }
        }
        
        // Persist to database (store handles coalesced writes internally)
        ExerciseStore.shared.update(newEx)
    }
    
    func deleteExercise(id: String) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if id.hasPrefix("repeat-") {
            // Robustly extract the repeatId. Format can be "repeat-{id}" or "repeat-{id}-YYYY-MM-DD"
            let repeatId = id.replacingOccurrences(of: "repeat-", with: "").components(separatedBy: "-").first ?? ""
            
            if !repeatId.isEmpty, let idx = weeklyRepeatExercises.firstIndex(where: { $0.id == repeatId }) {
                let plan = weeklyRepeatExercises[idx]
                weeklyRepeatExercises.remove(at: idx)
                WeeklyRepeatStore.shared.delete(byId: plan.id)
            }
        } else {
            // Check if it has a weeklyRepeatId (actual exercise linked to a plan)
            if let exercise = allExercises.first(where: { $0.id == id }),
               let repeatId = exercise.weeklyRepeatId {
                
                // When deleting an actual instance that came from a plan, 
                // we now directly delete the whole recurring plan.
                if let idx = weeklyRepeatExercises.firstIndex(where: { $0.id == repeatId }) {
                    let plan = weeklyRepeatExercises[idx]
                    weeklyRepeatExercises.remove(at: idx)
                    WeeklyRepeatStore.shared.delete(byId: plan.id)
                }
            }
            
            withAnimation(.easeInOut) {
                allExercises.removeAll { $0.id == id }
            }
            ExerciseStore.shared.delete(byId: id)
        }
    }
    
    // MARK: - Timer Logic
    private func startTimer() {
        timerCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        var finished = false
        
        // Update whichever is active
        if isFreeTrainingMode && freeTrainingProgress.isActive {
            finished = updateProgress(state: &freeTrainingProgress, settings: freeTrainingSettings)
        } else if !isFreeTrainingMode && exerciseProgress.isActive, let settings = selectedExercise {
            finished = updateProgress(state: &exerciseProgress, settings: settings)
        }
        
        if finished {
            self.moveToNextPhase(isManual: false)
        }
    }
    
    @discardableResult
    private func updateProgress(state: inout WorkoutState, settings: Exercise) -> Bool {
        guard state.isActive, let refDate = state.referenceDate else { return false }
        
        let elapsed = Date().timeIntervalSince(refDate)
        let isInfinite = state.status == .work && settings.isTrainingTimeUnlimited
        
        if isInfinite {
            // Count up
            state.timeLeft = state.startTimeLeft + elapsed
            return false
        } else {
            // Count down
            let newTimeLeft = max(0, state.startTimeLeft - elapsed)
            state.timeLeft = newTimeLeft
            
            if newTimeLeft <= 0 {
                // Time is up - Transition immediately to next phase
                state.isActive = false
                state.referenceDate = nil
                
                return true
            } else if !state.hasPlayedCountdown && newTimeLeft <= 3.0 && state.status != .restEnd && !(state.status == .work && settings.isTrainingTimeUnlimited) {
                // Play countdown hint 3 seconds before ending
                state.hasPlayedCountdown = true
                if state.status == .prepare || state.status == .work {
                    self.playEndCountingWithEndStateSound()
                } else {
                    self.playEndCountingSound()
                }
            }
            return false
        }
    }
    
    private func updateReferenceDate(state: inout WorkoutState) {
        if state.isActive {
            state.referenceDate = Date()
            state.startTimeLeft = state.timeLeft
        } else {
            state.referenceDate = nil
        }
    }
    

    
    
    private func playRestEndSound() {
        playInternalSound(name: "timer_finish", shouldDuck: true, volume: 1.2)
    }

    private func playEndCountingWithEndStateSound() {
        let offset = max(0, 3.0 - activeProgress.timeLeft)
        playInternalSound(name: "end_counting_end_state", shouldDuck: true, startTime: offset, volume: 1.2)
    }
    
    private func playEndCountingSound() {
        let offset = max(0, 3.0 - activeProgress.timeLeft)
        playInternalSound(name: "end_counting", shouldDuck: true, startTime: offset, volume: 1.2)
    }
    
    private func playFinishSound() {
        playInternalSound(name: "finish_sound", shouldDuck: true, volume: 0.7)
    }
    

    private func playInternalSound(name: String, shouldDuck: Bool, startTime: TimeInterval = 0, volume: Float = 1.0) {
        // Only skip non-silent loop sounds if muted
        if isMuted && name != "silent_loop" {
            return
        }
        
        // 1. Check for sound file existence first
        var soundUrl: URL?
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3") { soundUrl = url }
        else if let url = Bundle.main.url(forResource: name, withExtension: "caf") { soundUrl = url }
        else if let url = Bundle.main.url(forResource: name, withExtension: "wav") { soundUrl = url }
        
        guard let url = soundUrl else {
            print("Audio file '\(name)' not found in Bundle. Please add it to the Xcode project.")
            return
        }
        
        // 2. Configure session
        do {
            let options: AVAudioSession.CategoryOptions = shouldDuck ? [.duckOthers] : [.mixWithOthers]
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: options)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        // 3. Play sound immediately (or with delay if ducking needs time to settle)
        DispatchQueue.main.asyncAfter(deadline: .now()) { [weak self] in
            guard let self = self else { return }
            do {
                self.currentlyPlayingSoundName = name
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.volume = volume // Max relative to media volume
                
                if startTime > 0 {
                    self.audioPlayer?.currentTime = startTime
                }
                
                self.audioPlayer?.play()
            } catch {
                print("Failed to play media sound: \(error)")
                self.restoreAudioSession()
            }
        }
    }
    
    // AVAudioPlayerDelegate
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if player === audioPlayer {
             currentlyPlayingSoundName = nil
        }
        restoreAudioSession()
    }
    
    private func restoreAudioSession() {
        // Restore to mix without ducking
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to restore audio session: \(error)")
        }
    }
    
    // MARK: - Silent Audio
    func manageSilentAudio() {
        let shouldPlaySilent = activeProgress.isActive || activeProgress.status == .restEnd
        
        if shouldPlaySilent {
            if silentPlayer == nil || !silentPlayer!.isPlaying {
                playSilentAudio()
            }
        } else {
            // We should NOT be playing audio (e.g. paused)
            if silentPlayer?.isPlaying == true {
                silentPlayer?.stop()
                print("Silent background audio stopped (intentional)")
            }
        }
    }
    
    private func playSilentAudio() {
        let soundName = "silent_loop"
        var soundUrl: URL?
        
        if let url = Bundle.main.url(forResource: soundName, withExtension: "mp3") { soundUrl = url }
        else if let url = Bundle.main.url(forResource: soundName, withExtension: "wav") { soundUrl = url }
        else if let url = Bundle.main.url(forResource: soundName, withExtension: "caf") { soundUrl = url }

        guard let url = soundUrl else {
            print("Silent loop file '\(soundName)' not found in Bundle.")
            return
        }
        
        do {
            silentPlayer = try AVAudioPlayer(contentsOf: url)
            silentPlayer?.numberOfLoops = -1 // Infinite loop
            silentPlayer?.volume = 0.01 // Effectively silent but active
            silentPlayer?.play()
            print("Silent background audio started")
        } catch {
            print("Failed to play silent audio: \(error)")
        }
    }
    
    func showToast(_ message: String, style: ToastStyle = .info) {
        self.toastStyle = style
        self.toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.toastMessage == message {
                withAnimation {
                    self.toastMessage = nil
                }
            }
        }
    }
}

