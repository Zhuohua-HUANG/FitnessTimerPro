import Foundation
import GRDB

enum TimerStatus: String, Codable {
    case rest = "休息"
    case work = "训练"
    case prepare = "准备"
    case restEnd = "休息结束"
}

enum AppView: String {
    case calendar
    case timer
    case settings
}

enum CalendarMode: String {
    case month
    case year
}

struct WorkoutState {
    var currentSet: Int
    var totalSets: Int
    var status: TimerStatus
    var timeLeft: Double
    var isActive: Bool
    
    // For precise synchronization
    var startTimeLeft: Double = 0
    var referenceDate: Date? = nil
    var hasPlayedCountdown: Bool = false
}

enum ExerciseTag: Int, Codable, CaseIterable {
    case chest = 1    // 胸
    case back = 2     // 背
    case legs = 3     // 腿
    case shoulders = 4 // 肩
    case arms = 5     // 手臂
    case abs = 6      // 腹
    
    var label: String {
        switch self {
        case .chest: return "胸"
        case .back: return "背"
        case .legs: return "腿"
        case .shoulders: return "肩"
        case .arms: return "手臂"
        case .abs: return "腹"
        }
    }
}

struct Exercise: Identifiable, Codable, Sendable, FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "exercises"
    
    var id: String
    var name: String
    var completed: Bool
    var sets: Int
    var restTime: Int // seconds
    var trainingTime: Int // seconds, -1 for unlimited
    
    var actualSets: Int?
    var totalTime: Int? // seconds
    var date: String? // YYYY-MM-DD
    var createdAt: Date = Date()
    var updatedAt: Date?
    var tag: Int? // ExerciseTag raw value
    
    // New fields for recurring items
    var weeklyRepeatId: String? // Links to WeeklyRepeatExercise
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = String(inserted.rowID)
    }
    
    init(id: String = "", name: String, completed: Bool = false, sets: Int, restTime: Int, trainingTime: Int, actualSets: Int? = nil, totalTime: Int? = nil, date: String? = nil, createdAt: Date = Date(), updatedAt: Date? = nil, tag: Int? = nil, weeklyRepeatId: String? = nil) {
        self.id = id
        self.name = name
        self.completed = completed
        self.sets = sets
        self.restTime = restTime
        self.trainingTime = trainingTime
        self.actualSets = actualSets
        self.totalTime = totalTime
        self.date = date
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tag = tag
        self.weeklyRepeatId = weeklyRepeatId
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, completed, sets, restTime, trainingTime, actualSets, totalTime, date, createdAt, updatedAt, tag, weeklyRepeatId
    }
    
    init(row: Row) {
        let dbId: UInt64 = row["id"]
        id = String(dbId)
        name = row["name"]
        completed = row["completed"]
        sets = row["sets"]
        restTime = row["restTime"]
        trainingTime = row["trainingTime"]
        actualSets = row["actualSets"]
        totalTime = row["totalTime"]
        date = row["date"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]
        tag = row["tag"]
        let wrId: UInt64? = row["weeklyRepeatId"]
        weeklyRepeatId = wrId.map(String.init)
    }
    
    func encode(to container: inout PersistenceContainer) {
        if let intId = UInt64(id), intId > 0 {
            container["id"] = intId
        } else {
            container["id"] = nil // For autoincrement
        }
        container["name"] = name
        container["completed"] = completed
        container["sets"] = sets
        container["restTime"] = restTime
        container["trainingTime"] = trainingTime
        container["actualSets"] = actualSets
        container["totalTime"] = totalTime
        container["date"] = date
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
        container["tag"] = tag
        if let wrId = weeklyRepeatId, let intWrId = UInt64(wrId) {
            container["weeklyRepeatId"] = intWrId
        } else {
            container["weeklyRepeatId"] = nil
        }
    }
}

struct WeeklyRepeatExercise: Identifiable, Codable, Sendable, FetchableRecord, MutablePersistableRecord {
    nonisolated static let databaseTableName = "weekly_repeat_exercises"
    
    var id: String
    var name: String
    var sets: Int
    var trainingTime: Int
    var restTime: Int
    var repeatDays: [Int] // 0 (Sunday) to 6 (Saturday)
    var createdAt: Date
    var updatedAt: Date?
    var tag: Int? // ExerciseTag raw value
    
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = String(inserted.rowID)
    }
    
    // Codable keys (exclude databaseTableName)
    enum CodingKeys: String, CodingKey {
        case id, name, sets, trainingTime, restTime, repeatDays
        case createdAt, updatedAt, tag
    }
    
    // Explicit memberwise init
    init(id: String = "", name: String, sets: Int, trainingTime: Int, restTime: Int,
         repeatDays: [Int], createdAt: Date, updatedAt: Date? = nil,
         tag: Int? = nil) {
        self.id = id
        self.name = name
        self.sets = sets
        self.trainingTime = trainingTime
        self.restTime = restTime
        self.repeatDays = repeatDays
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tag = tag
    }
    
    // MARK: - GRDB FetchableRecord
    // repeatDays is stored as comma-separated string (e.g. "1,3,5") in SQLite
    nonisolated init(row: Row) {
        let dbId: UInt64 = row["id"]
        id = String(dbId)
        name = row["name"]
        sets = row["sets"]
        trainingTime = row["trainingTime"]
        restTime = row["restTime"]
        createdAt = row["createdAt"]
        updatedAt = row["updatedAt"]
        tag = row["tag"]
        
        let daysStr: String = row["repeatDays"] ?? ""
        repeatDays = daysStr.split(separator: ",").compactMap { Int($0) }
    }
    
    // MARK: - GRDB PersistableRecord
    nonisolated func encode(to container: inout PersistenceContainer) {
        if let intId = UInt64(id), intId > 0 {
            container["id"] = intId
        } else {
            container["id"] = nil // Autoincrement
        }
        container["name"] = name
        container["sets"] = sets
        container["trainingTime"] = trainingTime
        container["restTime"] = restTime
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
        container["tag"] = tag
        container["repeatDays"] = repeatDays.map { String($0) }.joined(separator: ",")
        
        // Populate weekday flags for SQLite indexing
        container["isSun"] = repeatDays.contains(0)
        container["isMon"] = repeatDays.contains(1)
        container["isTue"] = repeatDays.contains(2)
        container["isWed"] = repeatDays.contains(3)
        container["isThu"] = repeatDays.contains(4)
        container["isFri"] = repeatDays.contains(5)
        container["isSat"] = repeatDays.contains(6)
    }
}

// Helper to handle "unlimited" training time
extension Exercise {
    var isTrainingTimeUnlimited: Bool {
        return trainingTime == -1
    }
}
