import SwiftUI

struct AddExerciseView: View {
    @EnvironmentObject var manager: WorkoutManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var name: String = ""
    @State private var sets: String = ""
    @State private var rest: String = ""
    @State private var isUnlimited: Bool = false
    @State private var shakeOffset: CGFloat = 0
    @State private var internalTitle: String = ""
    @State private var repeatDays: Set<Int> = []
    @State private var selectedTag: Int? = nil
    
    let allWeekdays = [
        (0, "日"), (1, "一"), (2, "二"), (3, "三"), (4, "四"), (5, "五"), (6, "六")
    ]
    
    enum Field {
        case name
        case sets
    }
    @FocusState private var focusedField: Field?
    
    // Time Picker State
    @State private var trainingMin: Int = 1
    @State private var trainingSec: Int = 0
    @State private var restMin: Int = 1
    @State private var restSec: Int = 0
    
    private var shouldShowNameField: Bool {
        manager.showAddModal || (manager.showEditModal && (!manager.isFreeTrainingMode || manager.editingExercise != nil))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.darkGray.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 2) {
                                            Text("名称").font(.body).fontWeight(.bold).foregroundColor(.gray)
                                            Text("*").font(.body).fontWeight(.bold).foregroundColor(.red)
                                        }
                                        TextField("", text: $name)
                                            .focused($focusedField, equals: .name)
                                            .padding()
                                            .background(Color.black)
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                                    }
                                    .modifier(Shake(animatableData: shakeOffset))

                                    HStack(spacing: 8) {
                                        ForEach(ExerciseTag.allCases, id: \.rawValue) { tag in
                                            Button(action: {
                                                if selectedTag == tag.rawValue {
                                                    selectedTag = nil
                                                } else {
                                                    selectedTag = tag.rawValue
                                                }
                                            }) {
                                                Text(tag.label)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 8)
                                                    .background(selectedTag == tag.rawValue ? AppColors.blue : Color.white.opacity(0.1))
                                                    .foregroundColor(selectedTag == tag.rawValue ? .white : .gray)
                                                    .cornerRadius(20)
                                            }
                                        }
                                    }
                                }
                                .opacity(shouldShowNameField ? 1 : 0)
                                .frame(height: shouldShowNameField ? nil : 0)
                                .clipped()
                                
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("组数").font(.body).fontWeight(.bold).foregroundColor(.gray)
                                        TextField(String(ExerciseDefaults.sets), text: $sets)
                                            .keyboardType(.numberPad)
                                            .padding()
                                            .background(Color.black)
                                            .cornerRadius(12)
                                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                                    }
                                }

                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text("训练时间").font(.body).fontWeight(.bold).foregroundColor(.gray)
                                            Spacer()
                                            Button(action: { isUnlimited.toggle() }) {
                                                Text("不限时")
                                                    .font(.system(size: 14, weight: .black))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(isUnlimited ? AppColors.green : AppColors.darkGray)
                                                    .foregroundColor(isUnlimited ? .white : .gray)
                                                    .cornerRadius(6)
                                            }
                                        }
                                        
                                        ZStack {
                                            TimePickerView(minutes: $trainingMin, seconds: $trainingSec)
                                                .opacity(isUnlimited ? 0 : 1)
                                            
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.black)
                                                .frame(height: 100)
                                                .overlay(
                                                    Text("不限时")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 14))
                                                )
                                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                                                .opacity(isUnlimited ? 1 : 0)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("休息时间").font(.body).fontWeight(.bold).foregroundColor(.gray)
                                        TimePickerView(minutes: $restMin, seconds: $restSec)
                                    }
                                }

                                if !manager.showEditModal || manager.editingExercise != nil {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("每周重复 (可选)").font(.body).fontWeight(.bold).foregroundColor(.gray)
                                        HStack {
                                            Spacer(minLength: 0)
                                            ForEach(allWeekdays, id: \.0) { day in
                                                Button(action: {
                                                    if repeatDays.contains(day.0) {
                                                        repeatDays.remove(day.0)
                                                    } else {
                                                        repeatDays.insert(day.0)
                                                    }
                                                }) {
                                                    let currentWeekday = Calendar.current.component(.weekday, from: Date()) - 1
                                                    Text(day.1)
                                                        .font(.system(size: 15, weight: .bold))
                                                        .frame(width: 40, height: 40)
                                                        .background(repeatDays.contains(day.0) ? AppColors.blue : Color.white.opacity(0.1))
                                                        .foregroundColor(repeatDays.contains(day.0) ? .white : .gray)
                                                        .clipShape(Circle())
                                                        .overlay(
                                                            Circle()
                                                                .strokeBorder(day.0 == currentWeekday ? .white : .clear, lineWidth: 3)
                                                                // .padding(1.5)
                                                        )
                                                }
                                                if day.0 != allWeekdays.last?.0 {
                                                    Spacer(minLength: 0)
                                                }
                                            }
                                            Spacer(minLength: 0)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.horizontal)
                        .padding(.top, 20)
                    }
                }
                
                // 灰色固定空白
                    Rectangle()
                        .fill(AppColors.darkGray)
                        .frame(height: 10)
                    
                    // Buttons at bottom
                    HStack(spacing: 16) {
                        Button(action: {
                            cancel()
                        }) {
                            Text("取消")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "2C2C2E"))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            save()
                        }) {
                            Text("确定")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(internalTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
        .onChange(of: manager.showEditModal) { _, newValue in
            if newValue {
                updateInternalTitle()
                loadEditingData()
            }
        }
        .onChange(of: manager.showAddModal) { _, newValue in
            if newValue {
                updateInternalTitle()
                resetForNewExercise()
            }
        }
        .onAppear {
            updateInternalTitle()
            if manager.showEditModal {
                loadEditingData()
            } else if manager.showAddModal {
                resetForNewExercise()
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    

}

struct TimePickerView: View {
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        HStack {
            Picker("Minutes", selection: $minutes) {
                ForEach(0..<60) { i in
                    Text(String(format: "%02d", i)).tag(i)
                        .foregroundColor(.white)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            
            Text(":")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 2)
            
            Picker("Seconds", selection: $seconds) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { i in
                    Text(String(format: "%02d", i)).tag(i)
                        .foregroundColor(.white)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .background(Color.black)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
        .frame(height: 100)
        .clipped()
    }
}

extension AddExerciseView {
    
    private func cancel() {
        hideKeyboard()

        withAnimation {
            manager.showAddModal = false
            manager.showEditModal = false
            manager.editingExercise = nil
        }
    }
    
    private func updateInternalTitle() {
        if !manager.showEditModal && manager.showAddModal {
            internalTitle = "添加训练计划"
        } else if manager.showEditModal && manager.editingExercise != nil {
            internalTitle = "编辑训练计划"
        } else {
            internalTitle = manager.isFreeTrainingMode ? "编辑自由训练" : "编辑当前训练"
        }
    }
    
    func save() {
        hideKeyboard()
        let setsInt = Int(sets) ?? ExerciseDefaults.sets
        
        let restInt = restMin * 60 + restSec
        
        var trainingTimeInt = -1
        if !isUnlimited {
            trainingTimeInt = trainingMin * 60 + trainingSec
            if trainingTimeInt == 0 { trainingTimeInt = 60 } // Default for error case
        }
        if manager.showEditModal {
            if name.isEmpty && (manager.editingExercise != nil || !manager.isFreeTrainingMode) {
                triggerShake()
                return
            }
            // If it was already a specific exercise, save it
            manager.saveSettings(
                id: (manager.editingExercise?.id ?? manager.selectedExercise?.id) ?? "",
                name: name,
                sets: setsInt,
                rest: restInt,
                trainingTime: trainingTimeInt,
                repeatDays: Array(repeatDays).sorted(),
                tag: selectedTag
            )
        } else {
            if name.isEmpty {
                triggerShake()
                return
            }
            
            if !repeatDays.isEmpty {
                // If repeat days are selected, add as WeeklyRepeat
                manager.addWeeklyRepeat(
                    name: name,
                    sets: setsInt,
                    rest: restInt,
                    trainingTime: trainingTimeInt,
                    repeatDays: Array(repeatDays).sorted(),
                    tag: selectedTag
                )
            } else {
                // Otherwise, add as one-time Exercise
                manager.addExercise(name: name, sets: setsInt, rest: restInt, trainingTime: trainingTimeInt, tag: selectedTag)
            }
        }
        
        manager.showAddModal = false
        manager.showEditModal = false
    }
    
    private func triggerShake() {
        withAnimation(.default) {
            shakeOffset += 1
        }
    }
    
    private func resetForNewExercise() {
        name = ""
        sets = String(ExerciseDefaults.sets)
        isUnlimited = ExerciseDefaults.isUnlimited
        trainingMin = ExerciseDefaults.trainingMin
        trainingSec = ExerciseDefaults.trainingSec
        restMin = ExerciseDefaults.restMin
        restSec = ExerciseDefaults.restSec
        repeatDays = []
        selectedTag = nil
    }
    
    private func loadEditingData() {
        let settings = manager.editingExercise ?? manager.currentSettings
        if let settings = settings {
            if !manager.isFreeTrainingMode || manager.editingExercise != nil {
                 name = settings.name
            }
            sets = String(settings.sets)
            
            if settings.isTrainingTimeUnlimited {
                isUnlimited = true
                trainingMin = 1
                trainingSec = 0
            } else {
                isUnlimited = false
                trainingMin = settings.trainingTime / 60
                let rawSec = settings.trainingTime % 60
                trainingSec = ((rawSec + 2) / 5) * 5
                if trainingSec == 60 { 
                    trainingMin += 1
                    trainingSec = 0
                }
            }
            
            let restTotalSec = settings.restTime
            restMin = restTotalSec / 60
            let rawRestSec = restTotalSec % 60
            restSec = ((rawRestSec + 2) / 5) * 5
            if restSec == 60 {
                restMin += 1
                restSec = 0
            }
            
            if let repeatId = settings.weeklyRepeatId,
               let repeatPlan = manager.weeklyRepeatExercises.first(where: { $0.id == repeatId }) {
                repeatDays = Set(repeatPlan.repeatDays)
                selectedTag = repeatPlan.tag
            } else {
                repeatDays = []
                selectedTag = settings.tag
            }
        }
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
