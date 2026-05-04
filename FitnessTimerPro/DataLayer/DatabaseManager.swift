import Foundation
import GRDB

/// Central database manager – handles SQLite database initialization and schema setup.
final class DatabaseManager: @unchecked Sendable {
    
    static let shared = DatabaseManager()
    
    /// The database connection pool.
    let dbPool: DatabasePool
    
    private init() {
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let dbURL = docs.appendingPathComponent("fitness_timer.sqlite")
            
            dbPool = try DatabasePool(path: dbURL.path)
            
            // Create tables and indices if they don't exist
            try setupSchema()
            
            print("📂 [DatabaseManager] SQLite database ready at: \(dbURL.path)")
        } catch {
            fatalError("❌ [DatabaseManager] Failed to initialize database: \(error)")
        }
    }
    
    private func setupSchema() throws {
        try dbPool.write { db in
            // exercises table
            try db.create(table: "exercises", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("completed", .boolean).notNull().defaults(to: false)
                t.column("sets", .integer).notNull()
                t.column("restTime", .integer).notNull()
                t.column("trainingTime", .integer).notNull()
                t.column("actualSets", .integer)
                t.column("totalTime", .integer)
                t.column("date", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime)
                t.column("tag", .integer)
                t.column("weeklyRepeatId", .integer)
            }
            
            // weekly_repeat_exercises table
            try db.create(table: "weekly_repeat_exercises", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("sets", .integer).notNull()
                t.column("trainingTime", .integer).notNull()
                t.column("restTime", .integer).notNull()
                t.column("repeatDays", .text).notNull() // comma-separated: "0,1,2" (0=Sun)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime)
                t.column("tag", .integer)
                
                // Day of week flags for fast querying
                t.column("isSun", .boolean).notNull().defaults(to: false)
                t.column("isMon", .boolean).notNull().defaults(to: false)
                t.column("isTue", .boolean).notNull().defaults(to: false)
                t.column("isWed", .boolean).notNull().defaults(to: false)
                t.column("isThu", .boolean).notNull().defaults(to: false)
                t.column("isFri", .boolean).notNull().defaults(to: false)
                t.column("isSat", .boolean).notNull().defaults(to: false)
            }
            
            // chat_messages table
            try db.create(table: "chat_messages", ifNotExists: true) { t in
                t.primaryKey("id", .text).notNull()
                t.column("role", .text).notNull()
                t.column("content", .text)
                t.column("reasoning", .text)
                t.column("toolCallId", .text)
                t.column("toolCallsData", .blob) // Store tool calls as JSON data
                t.column("timestamp", .datetime).notNull()
                t.column("isConfirmed", .boolean)
                t.column("isCancelled", .boolean)
                t.column("showSettingsBtn", .boolean)
                t.column("confirmedPlansData", .blob)
                t.column("toolResultsData", .blob)
            }
            
            // Migration for existing tables to add confirmedPlansData
            if try db.tableExists("chat_messages") {
                let columns = try db.columns(in: "chat_messages")
                if !columns.contains(where: { $0.name == "confirmedPlansData" }) {
                    try db.execute(sql: "ALTER TABLE chat_messages ADD COLUMN confirmedPlansData BLOB")
                }
                if !columns.contains(where: { $0.name == "toolResultsData" }) {
                    try db.execute(sql: "ALTER TABLE chat_messages ADD COLUMN toolResultsData BLOB")
                }
            }
            
            // Indices
            try db.create(index: "index_chat_messages_on_timestamp", on: "chat_messages", columns: ["timestamp"], ifNotExists: true)
            
            // Existing Indices
            try db.create(index: "index_exercises_on_tag", on: "exercises", columns: ["tag"], ifNotExists: true)
            try db.create(index: "index_exercises_on_weeklyRepeatId", on: "exercises", columns: ["weeklyRepeatId"], ifNotExists: true)
            try db.create(index: "index_weekly_repeat_exercises_on_tag", on: "weekly_repeat_exercises", columns: ["tag"], ifNotExists: true)
            try db.create(index: "index_weekly_repeat_exercises_on_repeatDays", on: "weekly_repeat_exercises", columns: ["repeatDays"], ifNotExists: true)
            
            // Weekday indices
            try db.create(index: "idx_wr_isSun", on: "weekly_repeat_exercises", columns: ["isSun"], ifNotExists: true)
            try db.create(index: "idx_wr_isMon", on: "weekly_repeat_exercises", columns: ["isMon"], ifNotExists: true)
            try db.create(index: "idx_wr_isTue", on: "weekly_repeat_exercises", columns: ["isTue"], ifNotExists: true)
            try db.create(index: "idx_wr_isWed", on: "weekly_repeat_exercises", columns: ["isWed"], ifNotExists: true)
            try db.create(index: "idx_wr_isThu", on: "weekly_repeat_exercises", columns: ["isThu"], ifNotExists: true)
            try db.create(index: "idx_wr_isFri", on: "weekly_repeat_exercises", columns: ["isFri"], ifNotExists: true)
            try db.create(index: "idx_wr_isSat", on: "weekly_repeat_exercises", columns: ["isSat"], ifNotExists: true)
        }
    }
}
