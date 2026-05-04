import Foundation
import GRDB

/// Incremental persistence layer for `WeeklyRepeatExercise` records using SQLite via GRDB.
/// Each operation (insert, update, delete) directly modifies the database row.
final class WeeklyRepeatStore: @unchecked Sendable {
    
    static let shared = WeeklyRepeatStore()
    
    private var db: DatabasePool { DatabaseManager.shared.dbPool }
    
    private init() {}
    
    // MARK: - Read
    
    func getAll() -> [WeeklyRepeatExercise] {
        do {
            return try db.read { db in
                try WeeklyRepeatExercise.fetchAll(db)
            }
        } catch {
            print("❌ [WeeklyRepeatStore] Failed to fetch all: \(error)")
            return []
        }
    }
    
    func get(byId id: String) -> WeeklyRepeatExercise? {
        do {
            return try db.read { db in
                try WeeklyRepeatExercise.fetchOne(db, key: id)
            }
        } catch {
            print("❌ [WeeklyRepeatStore] Failed to fetch by id: \(error)")
            return nil
        }
    }
    
    func filter(_ predicate: (WeeklyRepeatExercise) -> Bool) -> [WeeklyRepeatExercise] {
        return getAll().filter(predicate)
    }
    
    // MARK: - ID Allocation
    
    func allocateNewId() -> String {
        do {
            return try db.write { db -> String in
                var dummy = WeeklyRepeatExercise(name: "New Plan", sets: 1, trainingTime: 1, restTime: 1, repeatDays: [], createdAt: Date(), tag: nil)
                try dummy.insert(db)
                return dummy.id
            }
        } catch {
            print("❌ [WeeklyRepeatStore] allocateNewId failed: \(error)")
            return "8888888\(Int.random(in: 1000...9999))"
        }
    }
    
    // MARK: - Insert
    
    func insert(_ plan: WeeklyRepeatExercise) {
        do {
            var planCopy = plan
            try db.write { db in
                try planCopy.insert(db)
            }
            logPlan("Inserted", planCopy)
        } catch {
            print("❌ [WeeklyRepeatStore] Insert failed: \(error)")
        }
    }
    
    // MARK: - Update
    
    func update(_ plan: WeeklyRepeatExercise) {
        do {
            var planCopy = plan
            try db.write { db in
                try planCopy.update(db)
            }
            logPlan("Updated", planCopy)
        } catch {
            print("❌ [WeeklyRepeatStore] Update failed: \(error)")
        }
    }
    
    /// Insert or update – useful when you don't know if the record already exists.
    func upsert(_ plan: WeeklyRepeatExercise) {
        do {
            var planCopy = plan
            try db.write { db in
                try planCopy.save(db)
            }
        } catch {
            print("❌ [WeeklyRepeatStore] Upsert failed: \(error)")
        }
    }
    
    // MARK: - Delete
    
    @discardableResult
    func delete(byId id: String) -> Bool {
        do {
            try db.write { db in
                _ = try WeeklyRepeatExercise.deleteOne(db, key: id)
            }
            print("🗑️ [WeeklyRepeatStore] Deleted plan: \(id)")
            return true
        } catch {
            print("❌ [WeeklyRepeatStore] Delete failed: \(error)")
            return false
        }
    }
    
    func deleteAll(where predicate: (WeeklyRepeatExercise) -> Bool) {
        let toRemove = getAll().filter(predicate)
        guard !toRemove.isEmpty else { return }
        do {
            try db.write { db in
                for plan in toRemove {
                    _ = try WeeklyRepeatExercise.deleteOne(db, key: plan.id)
                }
            }
            print("🗑️ [WeeklyRepeatStore] Bulk deleted \(toRemove.count) plans")
        } catch {
            print("❌ [WeeklyRepeatStore] Bulk delete failed: \(error)")
        }
    }
    
    // MARK: - Convenience (no-op for backward compat)
    
    func flushToDisk() {
        // SQLite writes are immediate – this is a no-op retained for API compatibility
    }
    
    // MARK: - Logging
    
    private func logPlan(_ action: String, _ plan: WeeklyRepeatExercise) {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let days = plan.repeatDays.sorted().map { String($0) }.joined(separator: ",")
        let created = df.string(from: plan.createdAt)
        let updated = plan.updatedAt != nil ? df.string(from: plan.updatedAt!) : "nil"
        let tagLabel = plan.tag != nil ? (ExerciseTag(rawValue: plan.tag!)?.label ?? "Unknown(\(plan.tag!))") : "nil"
        
        print("""
        📋 [WeeklyRepeatStore] \(action):
          ID: \(plan.id)
          Name: \(plan.name)
          Tag: \(tagLabel)
          Sets: \(plan.sets)
          Training: \(plan.trainingTime == -1 ? "Unlimited" : "\(plan.trainingTime)s")
          Rest: \(plan.restTime)s
          RepeatDays: [\(days)] (0=Sun...6=Sat)
          CreatedAt: \(created)
          UpdatedAt: \(updated)
        """)
    }
}
