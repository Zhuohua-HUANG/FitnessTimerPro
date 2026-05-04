import SwiftUI
import ConfettiSwiftUI

struct CalendarView: View {
    @EnvironmentObject var manager: WorkoutManager
    
    var body: some View {
        NavigationStack(path: $manager.calendarPath) {
            YearView()
                .navigationBarHidden(true)
                .navigationDestination(for: String.self) { _ in
                    MonthView()
                        .navigationBarHidden(true)
                        .background(EnableSwipeBack())
                }
        }
        .overlay(AIInputOverlay())
    }
}

struct MonthView: View {
    @EnvironmentObject var manager: WorkoutManager
    @State private var showEmoji = false
    @State private var emojiScale: CGFloat = 0.01
    @State private var emojiOpacity: Double = 0
    @State private var confettiTrigger: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { 
                    manager.calendarPath = []
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.left")
                        Text(monthString(manager.selectedDate))
                            .font(.title3)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                }
                Spacer()
                
                let isPastDate = manager.selectedDate < Calendar.current.startOfDay(for: Date())
                
                Button(action: { manager.showAddModal = true }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                }
                .opacity(isPastDate ? 0 : 1)
                .disabled(isPastDate)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // Date Strip
            DateStrip()
                .padding(.bottom, 10)
            
            // Sub-header
            HStack {
                Text(fullDateString(manager.selectedDate))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black)
            
            // Exercise List
            let isPastDate = manager.selectedDate < Calendar.current.startOfDay(for: Date())
            let isToday = Calendar.current.isDateInToday(manager.selectedDate)
            ExerciseListView(isPastDate: isPastDate, isToday: isToday)
                .id(manager.selectedDate.timeIntervalSince1970)
        }
        .background(Color.black)
        .overlay(
            Group {
                if let ex = manager.pendingExercise {
                    StandardDialog(
                        title: "切换训练项",
                        message: "确定要开始训练“\(ex.name)”吗？这将会重置当前的“\(manager.selectedExercise?.name ?? "训练")”进度。",
                        primaryTitle: "确定",
                        primaryIsWhite: true,
                        primaryAction: {
                            manager.startExercise(ex)
                            manager.pendingExercise = nil
                        },
                        secondaryTitle: "取消",
                        secondaryAction: { manager.pendingExercise = nil }
                    )
                }

                if let ex = manager.deletingExercise {
                    let daysStr = getRepeatDays(for: ex).joined(separator: "、")
                    StandardDialog(
                        title: "删除重复训练项",
                        message: "该训练项在 \(daysStr) 重复。您确定要删除这个重复训练计划吗？",
                        primaryTitle: "确定",
                        primaryAction: {
                            manager.deleteExercise(id: ex.id)
                            manager.deletingExercise = nil
                        },
                        secondaryTitle: "取消",
                        secondaryAction: { manager.deletingExercise = nil }
                    )
                }
            }
        )
        .confettiCannon(trigger: $confettiTrigger, num: 50, colors: [.red, .orange, .yellow, .green, .blue, .purple], confettiSize: 10, openingAngle: Angle(degrees: 0), closingAngle: Angle(degrees: 360), radius: 250)
        .overlay(
            ZStack {
                if showEmoji {
                    Text("🎉")
                        .font(.system(size: 50))
                        .scaleEffect(emojiScale)
                        .opacity(emojiOpacity)
                }
                
                VStack {
                    if let toast = manager.toastMessage {
                        ToastView(message: toast, style: manager.toastStyle, bottomPadding: 78)
                    }
                }
                .animation(.easeInOut, value: manager.toastMessage)

            }
        )
        .onChange(of: manager.celebrationCounter) { old, new in
            if new > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    // Trigger confetti and emoji simultaneously
                    confettiTrigger += 1
                    
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                        showEmoji = true
                        emojiScale = 1.5
                        emojiOpacity = 1.0
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeIn(duration: 0.5)) {
                            emojiScale = 0.8
                            emojiOpacity = 0
                        }
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        showEmoji = false
                        emojiScale = 0.01
                    }
                }
            }
        }

    }
    
    func monthString(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "M月"
        return fmt.string(from: date)
    }
    
    func fullDateString(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy年M月d日 · EEEE"
        fmt.locale = Locale(identifier: "zh_CN")
        return fmt.string(from: date)
    }

    private func getRepeatDays(for exercise: Exercise) -> [String] {
        guard let rid = exercise.weeklyRepeatId,
              let plan = manager.weeklyRepeatExercises.first(where: { $0.id == rid }) else {
            return []
        }
        
        let weekdayNames = [0: "周日", 1: "周一", 2: "周二", 3: "周三", 4: "周四", 5: "周五", 6: "周六"]
        return plan.repeatDays.sorted().compactMap { weekdayNames[$0] }
    }
}

struct YearView: View {
    @EnvironmentObject var manager: WorkoutManager
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 40, pinnedViews: [.sectionHeaders]) {
                        let minYear = getMinYear()
                        let currentYear = Calendar.current.component(.year, from: Date())
                        let targetYears = Array(minYear...(currentYear + 2))
                        
                        ForEach(targetYears, id: \.self) { year in
                            Section(header: Text("\(String(year))年")
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(AppColors.textGray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                                .padding(.vertical, 20)
                                .background(Color.black)
                            ) {
                                let months = monthsInYear(year)
                                ForEach(months, id: \.self) { monthDate in
                                    VStack(alignment: .leading) {
                                        Text(monthTitle(monthDate))
                                            .font(.system(size: 28, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal)
                                            .padding(.bottom, 10)
                                        
                                        // Weekday Header
                                        HStack {
                                            ForEach(weekdays, id: \.self) { day in
                                                Text(day)
                                                    .font(.caption2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.gray)
                                                    .frame(maxWidth: .infinity)
                                            }
                                        }
                                        .padding(.horizontal)
                                        
                                        LazyVGrid(columns: columns, spacing: 10) {
                                            // Padding for the first day of the month
                                            ForEach(0..<firstWeekdayOfMonth(monthDate), id: \.self) { _ in
                                                Color.clear.frame(width: 30, height: 30)
                                            }
                                            
                                            ForEach(daysInMonth(monthDate), id: \.self) { date in
                                                MonthDayCell(date: date)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                    .id(monthDate)
                                    .padding(.bottom, 20)
                                }
                            }
                        }
                    }
                }
                .onChange(of: manager.calendarPath) { oldValue, newValue in
                    // Scroll to selected month whenever enabling year view
                    if newValue.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            scrollToSelectedMonth(proxy: proxy)
                        }
                    }
                }
                .onChange(of: manager.currentView) { oldValue, newValue in
                    // Scroll to selected month when switching back to calendar tab
                    if newValue == .calendar && manager.calendarPath.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            scrollToSelectedMonth(proxy: proxy)
                        }
                    }
                }
                .onAppear {
                    // Initial scroll to selected month (e.g. today) when app launches
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        scrollToSelectedMonth(proxy: proxy)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    Button(action: {
                        scrollToToday(proxy: proxy)
                    }) {
                        Text("今天")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(20)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 24)
                }
            }
            
            // Mask for Dynamic Island area to block scrolling content
            Rectangle()
                .fill(Color.black)
                .frame(height: 0)
                .background(Color.black.ignoresSafeArea(edges: .top))
        }
        .background(Color.black)
    }
    
    private func scrollToSelectedMonth(proxy: ScrollViewProxy) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: manager.selectedDate)
        if let targetMonth = calendar.date(from: components) {
            withAnimation(.spring()) {
                proxy.scrollTo(targetMonth, anchor: .center)
            }
        }
    }
    
    private func scrollToToday(proxy: ScrollViewProxy) {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        if let todayMonth = calendar.date(from: components) {
            withAnimation(.spring()) {
                proxy.scrollTo(todayMonth, anchor: .center)
            }
        }
    }
    
    func firstWeekdayOfMonth(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        let firstOfMonth = calendar.date(from: components)!
        return calendar.component(.weekday, from: firstOfMonth) - 1 // 0 = Sunday
    }
    
    func getMinYear() -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        let years = manager.allExercises.compactMap { ex -> Int? in
            guard let dateStr = ex.date else { return nil }
            return Int(dateStr.prefix(4))
        }
        return Swift.min(currentYear, years.min() ?? currentYear)
    }

    func monthsInYear(_ year: Int) -> [Date] {
        let calendar = Calendar.current
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }
    
    func daysInMonth(_ date: Date) -> [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)!
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
    }
    
    func monthTitle(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "M月"
        return fmt.string(from: date)
    }
    
    func dayString(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "d"
        return fmt.string(from: date)
    }
}

struct MonthDayCell: View {
    @EnvironmentObject var manager: WorkoutManager
    let date: Date
    
    var body: some View {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: manager.selectedDate)
        let dateStr = manager.dateFormatter(date)
        let isCompleted = manager.completedDateStrings.contains(dateStr)
        let isUncompleted = manager.uncompletedDateStrings.contains(dateStr)
        let isToday = calendar.isDateInToday(date)
        let isPastOrToday = date <= calendar.startOfDay(for: Date())
        
        let fmt = DateFormatter(); fmt.dateFormat = "d"
        let dayString = fmt.string(from: date)
        
        return Text(dayString)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(
                isSelected ? .white : 
                (isPastOrToday && (isCompleted || isUncompleted) ? .white : 
                (isToday ? .white : .gray))
            )
            .frame(width: 30, height: 30)
            .background(
                isSelected ? AppColors.red : 
                (isPastOrToday && isCompleted ? AppColors.green : 
                (isPastOrToday && isUncompleted ? AppColors.darkGray : Color.clear))
            )
            .overlay(
                Group {
                    if isToday {
                        Circle().strokeBorder(.white, lineWidth: 3)
                    }
                }
            )
            .overlay(
                VStack {
                    Spacer()
                    if !isPastOrToday && manager.hasExercisesDateStrings.contains(dateStr) {
                        PlanIndicatorDot(color: isSelected ? .white : .gray)
                            .padding(.bottom, 4)
                    }
                }
            )
            .clipShape(Circle())
            .onTapGesture {
                manager.selectedDate = date
                manager.calendarPath = ["month"]
            }
    }
}

struct DateStrip: View {
    @EnvironmentObject var manager: WorkoutManager
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    let days = daysInMonth(manager.selectedDate)
                    ForEach(days, id: \.self) { date in
                        let dateStr = manager.dateFormatter(date)
                        let isCompleted = manager.completedDateStrings.contains(dateStr)
                        let isUncompleted = manager.uncompletedDateStrings.contains(dateStr)
                        let isToday = Calendar.current.isDateInToday(date)
                        let isPastOrToday = date <= Calendar.current.startOfDay(for: Date())
                        DateCell(
                            date: date, 
                            isSelected: Calendar.current.isDate(date, inSameDayAs: manager.selectedDate),
                            isCompleted: isCompleted,
                            isUncompleted: isUncompleted,
                            isToday: isToday,
                            isPast: isPastOrToday
                        )
                            .id(date)
                            .onTapGesture {
                                manager.selectedDate = date
                                withAnimation {
                                    proxy.scrollTo(date, anchor: .center)
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(Calendar.current.startOfDay(for: manager.selectedDate), anchor: .center)
            }
            .onChange(of: manager.selectedDate) { oldDate, newDate in
                withAnimation {
                    let scrollToDate = Calendar.current.startOfDay(for: newDate)
                    proxy.scrollTo(scrollToDate, anchor: .center)
                }
            }
        }
    }
    
    func daysInMonth(_ date: Date) -> [Date] {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: date)!
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: startOfMonth) }
    }
}

struct DateCell: View {
    @EnvironmentObject var manager: WorkoutManager
    let date: Date
    let isSelected: Bool
    let isCompleted: Bool
    let isUncompleted: Bool
    let isToday: Bool
    let isPast: Bool
    
    var body: some View {
        VStack {
            Text(weekdayString(date))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isSelected ? .white : .gray)
            
            ZStack {
                // Priority: Selected > Completed Past > Uncompleted Past > Today
                if isSelected {
                    Circle()
                        .fill(AppColors.red)
                } else if isPast && isCompleted {
                    Circle()
                        .fill(AppColors.green)
                } else if isPast && isUncompleted {
                    Circle()
                        .fill(AppColors.darkGray)
                }
                
                if isToday {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)
                }
                
                let dateStr = manager.dateFormatter(date)
                if !isPast && manager.hasExercisesDateStrings.contains(dateStr) {
                    VStack {
                        Spacer()
                        PlanIndicatorDot(color: isSelected ? .white : .gray)
                            .padding(.bottom, 6)
                    }
                }
                
                Text(dayString(date))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(
                        isSelected ? .white : 
                        (isPast && (isCompleted || isUncompleted) ? .white : 
                        (isToday ? .white : .gray))
                    )
            }
            .frame(width: 40, height: 40)
        }
    }
    
    func weekdayString(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "E" // Mon, Tue
        fmt.locale = Locale(identifier: "zh_CN")
        let str = fmt.string(from: date)
        return str.replacingOccurrences(of: "周", with: "")
    }
    
    func dayString(_ date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "d"
        return fmt.string(from: date)
    }
}

struct PlanIndicatorDot: View {
    var color: Color = .white
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
    }
}


struct ExerciseRow: View {
    let exercise: Exercise
    let isPastDate: Bool
    let isToday: Bool
    @EnvironmentObject var manager: WorkoutManager
    
    @State private var iconScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0
    @State private var isVisuallyCompleted: Bool = false
    
    var body: some View {
        let isCompleted = isVisuallyCompleted
        let isDisabled = isPastDate && !exercise.completed
        
        rowContent
            .padding()
            .background(
                ZStack {
                    let isFuture = !isPastDate && !isToday
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDisabled ? AppColors.disabledCardBg : AppColors.cardBg)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCompleted ? AppColors.green.opacity(0.3) : (isDisabled ? Color.gray.opacity(0.3) : Color.white.opacity(0.05)), lineWidth: 1)
                    
                    if isPastDate && exercise.completed {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.4))
                    }
                }
            )
            .opacity(isPastDate && !(exercise.completed) ? 0.6 : 1.0)
            .grayscale(isPastDate && !(exercise.completed) ? 1.0 : 0.0)
            .contentShape(Rectangle())
            .onTapGesture {
                if !exercise.completed && isToday {
                    manager.requestStartExercise(exercise)
                } else if isPastDate {
                    manager.showToast("训练时间已过，仅可查看")
                } else if !isToday {
                    manager.showToast("未到训练时间，还不能开始哦")
                }
            }
            .onAppear {
                if manager.justCompletedId == exercise.id {
                    let isFreeTraining = exercise.name.contains("自由训练")
                    if isFreeTraining {
                        // Free training: start green, just trigger celebration
                        isVisuallyCompleted = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            triggerCelebrationIfNeeded()
                        }
                    } else {
                        // Planned exercise: blue to green transition
                        isVisuallyCompleted = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isVisuallyCompleted = true
                            }
                            // 手动延迟 0.1 秒，等动画结束
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                triggerCelebrationIfNeeded()
                            }
                        }
                    }
                } else {
                    isVisuallyCompleted = exercise.completed
                }
            }
            .onChange(of: manager.justCompletedId) { _, newId in
                if newId == exercise.id {
                    let isFreeTraining = exercise.name.contains("自由训练")
                    if isFreeTraining {
                        // Free training: start green, just trigger celebration
                        isVisuallyCompleted = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            triggerCelebrationIfNeeded()
                        }
                    } else {
                        // Planned exercise: blue to green transition
                        isVisuallyCompleted = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.1)) {
                                isVisuallyCompleted = true
                            }
                            // 手动延迟 0.1 秒，等动画结束
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                triggerCelebrationIfNeeded()
                            }
                        }
                    }
                }
            }
    }
    
    private func triggerCelebrationIfNeeded() {
        if manager.justCompletedId == exercise.id {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Trigger attention animation
                withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) {
                    iconScale = 1.3
                }
                
                // Wobble sequence
                let wobble = Animation.easeInOut(duration: 0.08).repeatCount(5, autoreverses: true)
                withAnimation(wobble.delay(0.2)) {
                    iconRotation = 8
                }
                
                // Return to normal
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        iconScale = 1.0
                        iconRotation = 0
                    }
                }
            }
        }
    }
    
    private var rowContent: some View {
        let isCompleted = isVisuallyCompleted
        let isDisabled = isPastDate && !exercise.completed
        
        return HStack {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isDisabled ? AppColors.disabledCardBg : AppColors.cardBg)

                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCompleted ? AppColors.green.opacity(0.4) : (isDisabled ? Color.gray.opacity(0.1) : AppColors.blue.opacity(0.2)), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isCompleted ? AppColors.green.opacity(0.2) : (isDisabled ? Color.gray.opacity(0.05) : AppColors.blue.opacity(0.1)))
                    )
                
                Image(systemName: isCompleted ? "checkmark" : "dumbbell.fill")
                    .foregroundColor(isCompleted ? AppColors.green : (isDisabled ? .gray : AppColors.blue))
            }
            .frame(width: 48, height: 48)
            .cornerRadius(12)
            .scaleEffect(iconScale)
            .rotationEffect(.degrees(iconRotation))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        
                    Image("icon_copy")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                        .foregroundColor(.gray)
                        .padding(4)
                        .contentShape(Rectangle())
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                UIPasteboard.general.string = exercise.name
                                manager.showToast("已复制：\(exercise.name)")
                            }
                        )
                    
                    if exercise.weeklyRepeatId != nil {
                        Text("重复")
                            .font(.system(size: 12))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(AppColors.blue.opacity(0.15))
                            .foregroundColor(AppColors.blue)
                            .cornerRadius(4)
                    }
                }
                .foregroundColor(isCompleted ? AppColors.green : (isDisabled ? .gray : .white))
                
                if isCompleted {
                    Text("已完成 \(exercise.actualSets ?? 0) 组 · 用时 \(formatTime(exercise.totalTime ?? 0))")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else {
                    let trainText = exercise.isTrainingTimeUnlimited ? "∞" : formatTime(exercise.trainingTime)
                    Text("\(exercise.sets) 组 · 训练 \(trainText) 休息 \(formatTime(exercise.restTime))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Check circle
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.green)
                    .font(.title3)
            } else {
                let isFuture = !isPastDate && !isToday
                if !isFuture {
                    Circle()
                        .stroke(isDisabled ? Color.gray.opacity(0.2) : Color.gray.opacity(0.5), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
        }
    }
    
    func formatTime(_ seconds: Int) -> String {
        if seconds == 0 { return "0s" }
        let m = seconds / 60
        let s = seconds % 60
        var result = ""
        if m > 0 {
            result += "\(m)m"
        }
        if s > 0 {
            result += "\(s)s"
        }
        return result
    }
}

struct ExerciseListView: View {
    @EnvironmentObject var manager: WorkoutManager
    let isPastDate: Bool
    let isToday: Bool
    @AppStorage("isAICreatorEnabled") private var isAICreatorEnabled = true

    
    // Represents a group of exercises (by tag or ungrouped)
    private struct ExerciseGroup: Identifiable {
        let id: String
        let tag: ExerciseTag?
        let exercises: [Exercise]
    }
    
    private func groupedExercises() -> [ExerciseGroup] {
        let exercises = manager.exercisesForSelectedDate()
        var groups: [ExerciseGroup] = []
        var tagGroups: [Int: [Exercise]] = [:]
        var tagOrder: [Int] = []
        var untagged: [Exercise] = []
        
        // Separate tagged and untagged exercises
        for ex in exercises {
            if let tag = ex.tag {
                if tagGroups[tag] == nil {
                    tagOrder.append(tag)
                }
                tagGroups[tag, default: []].append(ex)
            } else {
                untagged.append(ex)
            }
        }
        
        var result: [ExerciseGroup] = []
        
        // Untagged exercises first
        for ex in untagged {
            result.append(ExerciseGroup(id: ex.id, tag: nil, exercises: [ex]))
        }
        
        // Then tagged groups
        for tag in tagOrder {
            if let grouped = tagGroups[tag] {
                result.append(ExerciseGroup(
                    id: "tag-\(tag)",
                    tag: ExerciseTag(rawValue: tag),
                    exercises: grouped
                ))
            }
        }
        
        return result
    }
    
    var body: some View {
        let groups = groupedExercises()
        let lastUntaggedGroupId = groups.last(where: { $0.tag == nil })?.id
        
        ScrollViewReader { proxy in
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(Array(group.exercises.enumerated()), id: \.element.id) { index, ex in
                            exerciseRow(ex)
                                // .padding(.bottom, (group.id == lastUntaggedGroupId && index == group.exercises.count - 1) ? 34 : 0)
                        }
                    } header: {
                        if let tag = group.tag {
                            Text(tag.label)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(AppColors.blue)
                                .textCase(nil)
                                .padding(.top, 0)
                                .padding(.bottom, -4)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isAICreatorEnabled {
                    Color.clear.frame(height: 65)
                }
            }


            .listStyle(.plain)
            .listSectionSpacing(0)
            .scrollContentBackground(.hidden)
            .background(AppColors.blackBg)
            .onChange(of: manager.justCompletedId) { oldId, newId in
                if let targetId = newId {
                    scrollToTarget(targetId, proxy: proxy)
                }
            }
            .onChange(of: manager.scrollTargetId) { oldId, newId in
                if let targetId = newId {
                    scrollToTarget(targetId, proxy: proxy)
                }
            }
            .onAppear {
                if let targetId = manager.justCompletedId {
                    scrollToTarget(targetId, proxy: proxy)
                }
                if let targetId = manager.scrollTargetId {
                    scrollToTarget(targetId, proxy: proxy)
                }
            }
        }
    }
    
    @ViewBuilder
    private func exerciseRow(_ ex: Exercise) -> some View {
        ExerciseRow(exercise: ex, isPastDate: isPastDate, isToday: isToday)
            .id(ex.id)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                 if !isPastDate {
                     if ex.weeklyRepeatId != nil {
                         Button {
                             manager.deletingExercise = ex
                         } label: {
                             Image(systemName: "trash")
                         }
                         .tint(.red)
                     } else {
                         Button(role: .destructive) {
                             manager.deleteExercise(id: ex.id)
                         } label: {
                             Image(systemName: "trash")
                         }
                     }
                     
                     Button {
                         manager.editingExercise = ex
                         manager.showEditModal = true
                     } label: {
                         Image(systemName: "square.and.pencil")
                     }
                     .tint(AppColors.darkGray)
                 }
            }
    }
    
    private func scrollToTarget(_ targetId: String, proxy: ScrollViewProxy) {
        // Small delay to ensure the list has finished reloading with new data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                proxy.scrollTo(targetId, anchor: .center)
            }
        }
    }
}

