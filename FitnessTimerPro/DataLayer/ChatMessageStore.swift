import Foundation
import GRDB

/// Persistence layer for `ChatMessage` records.
/// Limits storage to 40 messages, deleting the oldest 20 when exceeded.
final class ChatMessageStore: @unchecked Sendable {
    
    static let shared = ChatMessageStore()
    
    private var db: DatabasePool { DatabaseManager.shared.dbPool }
    
    private init() {}
    
    // MARK: - Read
    
    /// Fetches the latest 20 messages for display.
    func getLatestMessages(limit: Int = 20) -> [ChatMessage] {
        do {
            return try db.read { db in
                try ChatMessage
                    .order(Column("timestamp").desc)
                    .limit(limit)
                    .fetchAll(db)
                    .reversed() // Reverse to get chronological order for UI
            }
        } catch {
            print("❌ [ChatMessageStore] Failed to fetch latest: \(error)")
            return []
        }
    }
    
    // MARK: - Insert
    
    /// Saves a message (Upsert) and handles the 40/20 pruning logic.
    func save(_ message: ChatMessage) {
        do {
            try db.write { db in
                try message.save(db)
            }
            pruneIfNeeded()
        } catch {
            print("❌ [ChatMessageStore] Save failed: \(error)")
        }
    }
    
    /// Updates an existing message (useful for confirming AI actions).
    func update(_ message: ChatMessage) {
        do {
            try db.write { db in
                try message.update(db)
            }
        } catch {
            print("❌ [ChatMessageStore] Update failed: \(error)")
        }
    }
    
    // MARK: - Pruning
    
    /// If messages > 40, delete the oldest 20.
    private func pruneIfNeeded() {
        do {
            try db.write { db in
                let count = try ChatMessage.fetchCount(db)
                if count > 40 {
                    // Find the timestamp of the 21st oldest message
                    // We want to delete everything older than that.
                    // Or more simply, delete all but the newest 20.
                    // But the requirement says "if > 40, delete oldest 20".
                    // That would leave 21+ messages. 
                    
                    let oldest20 = try ChatMessage
                        .order(Column("timestamp").asc)
                        .limit(20)
                        .fetchAll(db)
                    
                    for msg in oldest20 {
                        try ChatMessage.deleteOne(db, key: msg.id)
                    }
                    print("🗑️ [ChatMessageStore] Pruned 20 oldest messages (count was \(count))")
                }
            }
        } catch {
            print("❌ [ChatMessageStore] Pruning failed: \(error)")
        }
    }
    
    // MARK: - Delete All (Optional helper)
    func clearHistory() {
        do {
            try db.write { db in
                _ = try ChatMessage.deleteAll(db)
            }
        } catch {
            print("❌ [ChatMessageStore] Clear failed: \(error)")
        }
    }
}
