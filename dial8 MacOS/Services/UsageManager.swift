/// UsageManager tracks and manages user word usage limits and synchronization.
///
/// This singleton service provides comprehensive usage tracking functionality:
///
/// Core Features:
/// - Weekly word usage tracking
/// - Usage limits based on account type
/// - Server synchronization with threshold-based updates
/// - Automatic weekly usage reset
///
/// Implementation Details:
/// - Local storage using UserDefaults
/// - Server sync every 500 words (configurable threshold)
/// - Maintains usage across app restarts
/// - Handles account status updates
///
/// Synchronization:
/// - Intelligent sync with conflict resolution
/// - Threshold-based server updates
/// - Detailed logging for debugging
/// - Error handling and retry logic
///
/// Account Types:
/// - Basic: 2000 words per week limit
/// - Pro: Unlimited usage
/// - Custom: Configurable limits
///
/// Usage:
/// ```swift
/// let manager = UsageManager.shared
///
/// // Add words to usage count
/// await manager.addWords(100)
///
/// // Check current usage
/// let currentUsage = manager.currentWeekUsage
/// let weeklyLimit = manager.weeklyLimit
/// ```
///
/// Note: This manager maintains data consistency between
/// local storage and server state, with proper conflict
/// resolution for offline usage.

import Foundation

class UsageManager: ObservableObject {
    static let shared = UsageManager()
    
    @Published var currentWeekUsage: Int = 0
    @Published var weeklyLimit: Int = Int.max  // Changed from 2000 to Int.max for unlimited words
    @Published var accountType: String = "basic"
    
    private let defaults = UserDefaults.standard
    private let weeklyUsageKey = "weeklyWordUsage"
    private let lastResetDateKey = "lastUsageResetDate"
    private let authManager = AuthenticationManager.shared
    
    private let syncThreshold = 500 // Words before syncing
    private let syncThresholdKey = "lastSyncThreshold"
    
    init() {
        // First load from local storage
        currentWeekUsage = defaults.integer(forKey: weeklyUsageKey)
        
        // Store this initial local value
        let initialLocalCount = currentWeekUsage
        
        checkAndResetWeeklyUsage()
        
        Task { @MainActor in
            // Pass the initial local count to updateFromAccountStatus
            await updateFromAccountStatus(initialLocalCount: initialLocalCount)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAccountStatusUpdate),
            name: NSNotification.Name("AccountStatusUpdated"),
            object: nil
        )
    }
    
    @objc private func handleAccountStatusUpdate() {
        Task { @MainActor in
            await updateFromAccountStatus(initialLocalCount: currentWeekUsage)
        }
    }
    
    @MainActor
    private func updateFromAccountStatus(initialLocalCount: Int) async {
        if let status = authManager.accountStatus {
            // Only update if server count is higher than both current and initial local counts
            if status.current_usage > currentWeekUsage && status.current_usage > initialLocalCount {
                currentWeekUsage = status.current_usage
                defaults.set(currentWeekUsage, forKey: weeklyUsageKey)
            } else {
                // Keep the higher of current local count and initial local count
                currentWeekUsage = max(currentWeekUsage, initialLocalCount)
                defaults.set(currentWeekUsage, forKey: weeklyUsageKey)
            }
            
            // Update limit based on account type - all accounts now have unlimited words
            weeklyLimit = Int.max  // Set to unlimited for all account types
            
            accountType = status.type
            
            if let periodStart = status.period_start {
                if let date = ISO8601DateFormatter().date(from: periodStart) {
                    defaults.set(date, forKey: lastResetDateKey)
                }
            }
        }
    }
    
    @MainActor
    func addWords(_ count: Int) {
        let previousUsage = currentWeekUsage
        
        // Update local count
        currentWeekUsage += count
        defaults.set(currentWeekUsage, forKey: weeklyUsageKey)
        defaults.set(Date(), forKey: lastResetDateKey)
        
        print("📈 Word count update:")
        print("  Previous usage: \(previousUsage)")
        print("  Added words: \(count)")
        print("  Current usage: \(currentWeekUsage)")
        
        // Calculate which threshold we're at
        let currentThreshold = (currentWeekUsage / syncThreshold) * syncThreshold
        let lastSyncThreshold = defaults.integer(forKey: syncThresholdKey)
        
        print("  Current threshold: \(currentThreshold)")
        print("  Last sync threshold: \(lastSyncThreshold)")
        
        // Sync if we've crossed a new threshold
        if currentThreshold > lastSyncThreshold {
            print("🎯 THRESHOLD CROSSED - Syncing with server")
            print("  From: \(lastSyncThreshold)")
            print("  To: \(currentWeekUsage)")
            
            Task {
                do {
                    try await syncWithServer(wordCount: currentWeekUsage)
                    defaults.set(currentThreshold, forKey: syncThresholdKey)
                    print("✅ Successfully synced usage with server at \(currentWeekUsage) words")
                } catch {
                    print("❌ Failed to sync usage with server: \(error)")
                }
            }
        } else {
            let nextThreshold = lastSyncThreshold + syncThreshold
            let wordsUntilSync = nextThreshold - currentWeekUsage
            print("⏳ Not syncing yet - \(wordsUntilSync) words until next sync at \(nextThreshold)")
        }
    }
    
    private func checkAndResetWeeklyUsage() {
        guard let lastResetDate = defaults.object(forKey: lastResetDateKey) as? Date else {
            resetUsage()
            return
        }
        
        let calendar = Calendar.current
        let currentWeek = calendar.component(.weekOfYear, from: Date())
        let lastWeek = calendar.component(.weekOfYear, from: lastResetDate)
        
        if currentWeek != lastWeek {
            resetUsage()
        }
    }
    
    private func resetUsage() {
        currentWeekUsage = 0
        defaults.set(currentWeekUsage, forKey: weeklyUsageKey)
        defaults.set(Date(), forKey: lastResetDateKey)
        defaults.set(0, forKey: syncThresholdKey) // Reset sync threshold to 0
    }
    
    @MainActor
    private func syncWithServer(wordCount: Int) async throws {
        guard var components = URLComponents(string: "\(AppConfig.BACKEND_API_URL)/api/v1/account/usage/sync") else {
            throw URLError(.badURL)
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConfig.API_KEY, forHTTPHeaderField: "X-API-Key")
        
        let token = try await TokenManager.shared.getValidToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        // Simplified request body with just word_count
        let requestDict = [
            "word_count": wordCount
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestDict)
        
        // Debug: Print the actual JSON string being sent
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 Sending JSON payload:\n\(jsonString)")
        }
        
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        // Add detailed error handling
        guard httpResponse.statusCode == 200 else {
            if let errorResponse = String(data: data, encoding: .utf8) {
                print("❌ Server returned status code: \(httpResponse.statusCode)")
                print("Error response: \(errorResponse)")
            }
            throw URLError(.badServerResponse)
        }
        
        // Update local state from server response
        if let status = try? JSONDecoder().decode(AccountStatus.self, from: data) {
            currentWeekUsage = status.current_usage
            if let limit = status.limit {
                weeklyLimit = limit
            } else if status.type == "pro" {
                weeklyLimit = Int.max  // No limit for pro accounts
            }
            accountType = status.type
        }
    }
}
