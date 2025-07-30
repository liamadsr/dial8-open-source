import Foundation

// MARK: - Date Formatting Utilities
struct DateFormatters {
    
    // Helper function to convert date to relative "Yesterday" or specific date format
    static func relativeDateString(from date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    // Helper function to format relative date with time
    static func relativeDateTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        
        let timeAgo = formatter.localizedString(for: date, relativeTo: Date())
        
        // For recent dates, use the relative format, otherwise use exact date
        if date.timeIntervalSinceNow > -60*60*24*7 { // Less than a week ago
            return timeAgo
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: date)
        }
    }
    
    // Format duration as readable string
    static func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
    
    // Format timestamp for timeline display
    static func formatTimestamp(_ timestamp: Date, relativeTo startTime: Date?) -> String {
        guard let startTime = startTime else {
            // If no start time provided, show as 0:00 (beginning of audio)
            return "0:00"
        }
        
        // Calculate relative time from recording start
        let relativeSeconds = timestamp.timeIntervalSince(startTime)
        
        // Ensure we don't show negative times
        let adjustedSeconds = max(0, relativeSeconds)
        
        // Format as MM:SS
        let minutes = Int(adjustedSeconds) / 60
        let seconds = Int(adjustedSeconds) % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }
}