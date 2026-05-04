import Foundation
import GRDB

/// Incremental persistence layer for `Exercise` records using SQLite via GRDB.
/// Each operation (insert, update, delete) directly modifies the database row.
final class ExerciseStore: @unchecked Sendable {
    
    static let shared = ExerciseStore()
    
    private var db: DatabasePool { DatabaseManager.shared.dbPool }
    
    private init() {}
    
    // MARK: - Read
    
    func getAll() -> [Exercise] {
        do {
            return try db.read { db in
                try Exercise.fetchAll(db)
            }
        } catch {
            print("❌ [ExerciseStore] Failed to fetch all: \(error)")
            return []
        }
    }
    
    func get(byId id: String) -> Exercise? {
        do {
            return try db.read { db in
                try Exercise.fetchOne(db, key: id)
            }
        } catch {
            print("❌ [ExerciseStore] Failed to fetch by id: \(error)")
            return nil
        }
    }
    
    func filter(_ predicate: (Exercise) -> Bool) -> [Exercise] {
        return getAll().filter(predicate)
    }
    
    // MARK: - ID Allocation
    
    /// Inserts an empty/dummy record to get an auto-incremented ID, which can be updated later
    func allocateNewId() -> String {
        do {
            return try db.write { db -> String in
                var dummy = Exercise(name: "New Exercise", completed: false, sets: 1, restTime: 1, trainingTime: 1)
                // When insert is called, GRDB uses MutablePersistableRecord's didInsert
                // to populate Dummy's id with the newly generated RowID as a String.
                try dummy.insert(db)
                return dummy.id
            }
        } catch {
            print("❌ [ExerciseStore] allocateNewId failed: \(error)")
            return "9999999\(Int.random(in: 1000...9999))" // Fallback
        }
    }
    
    // MARK: - Insert
    
    func insert(_ exercise: Exercise) {
        do {
            var exerciseCopy = exercise
            try db.write { db in
                try exerciseCopy.insert(db)
            }
            print("✅ [ExerciseStore] Inserted exercise: \(exerciseCopy.name) (\(exerciseCopy.id))")
        } catch {
            print("❌ [ExerciseStore] Insert failed: \(error)")
        }
    }
    
    // MARK: - Update
    
    func update(_ exercise: Exercise) {
        do {
            var exerciseCopy = exercise
            try db.write { db in
                try exerciseCopy.update(db)
            }
            print("✏️ [ExerciseStore] Updated exercise: \(exerciseCopy.name) (\(exerciseCopy.id))")
        } catch {
            print("❌ [ExerciseStore] Update failed: \(error)")
        }
    }
    
    /// Insert or update – useful when you don't know if the record already exists.
    func upsert(_ exercise: Exercise) {
        do {
            var exerciseCopy = exercise
            try db.write { db in
                try exerciseCopy.save(db)
            }
        } catch {
            print("❌ [ExerciseStore] Upsert failed: \(error)")
        }
    }
    
    // MARK: - Delete
    
    @discardableResult
    func delete(byId id: String) -> Bool {
        do {
            try db.write { db in
                _ = try Exercise.deleteOne(db, key: id)
            }
            print("🗑️ [ExerciseStore] Deleted exercise: \(id)")
            return true
        } catch {
            print("❌ [ExerciseStore] Delete failed: \(error)")
            return false
        }
    }
    
    func deleteAll(where predicate: (Exercise) -> Bool) {
        let toRemove = getAll().filter(predicate)
        guard !toRemove.isEmpty else { return }
        do {
            try db.write { db in
                for ex in toRemove {
                    _ = try Exercise.deleteOne(db, key: ex.id)
                }
            }
            print("🗑️ [ExerciseStore] Bulk deleted \(toRemove.count) exercises")
        } catch {
            print("❌ [ExerciseStore] Bulk delete failed: \(error)")
        }
    }
    
    // MARK: - Convenience (no-op for backward compat)
    
    func flushToDisk() {
        // SQLite writes are immediate – this is a no-op retained for API compatibility
    }
}
