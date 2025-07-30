import Foundation
import os.log
import SwiftUI

/// Performance monitoring utility for tracking and logging performance metrics
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private let logger = Logger(subsystem: "com.dial8", category: "Performance")
    private var timers: [String: Date] = [:]
    private let queue = DispatchQueue(label: "com.dial8.performanceMonitor", attributes: .concurrent)
    
    private init() {}
    
    /// Start timing an operation
    func startTimer(_ operation: String) {
        queue.async(flags: .barrier) {
            self.timers[operation] = Date()
        }
        logger.debug("⏱️ Started timer for: \(operation)")
    }
    
    /// Stop timing an operation and log the duration
    func stopTimer(_ operation: String, threshold: TimeInterval = 0.1) {
        queue.async(flags: .barrier) {
            guard let startTime = self.timers.removeValue(forKey: operation) else {
                self.logger.warning("⏱️ No timer found for: \(operation)")
                return
            }
            
            let duration = Date().timeIntervalSince(startTime)
            
            if duration > threshold {
                self.logger.warning("⏱️ SLOW: \(operation) took \(String(format: "%.3f", duration))s (threshold: \(threshold)s)")
            } else {
                self.logger.debug("⏱️ \(operation) completed in \(String(format: "%.3f", duration))s")
            }
        }
    }
    
    /// Measure a block of code
    func measure<T>(_ operation: String, threshold: TimeInterval = 0.1, block: () throws -> T) rethrows -> T {
        startTimer(operation)
        defer { stopTimer(operation, threshold: threshold) }
        return try block()
    }
    
    /// Measure an async block of code
    func measureAsync<T>(_ operation: String, threshold: TimeInterval = 0.1, block: () async throws -> T) async rethrows -> T {
        startTimer(operation)
        defer { stopTimer(operation, threshold: threshold) }
        return try await block()
    }
    
    /// Log memory usage
    func logMemoryUsage(_ context: String) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            logger.info("💾 Memory usage (\(context)): \(String(format: "%.1f", memoryMB)) MB")
        }
    }
}

/// Extension for easy performance monitoring in views
extension View {
    func measurePerformance(_ operation: String) -> some View {
        self.onAppear {
            PerformanceMonitor.shared.startTimer("\(operation).appear")
        }
        .onDisappear {
            PerformanceMonitor.shared.stopTimer("\(operation).appear")
        }
    }
}