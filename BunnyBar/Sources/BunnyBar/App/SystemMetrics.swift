//
//  SystemMetrics.swift
//  BunnyBar
//
//  Small, dependency-free system metrics sampler. Keeping the mapping separate
//  from AppKit/SpriteKit makes the behaviour easy to reason about and test.
//

import Darwin
import Foundation

struct SystemMetricsSnapshot {
    let cpuPercent: Double
    let memoryPercent: Double?
}

/// Converts machine load into the deliberately gentle motion used by BunnyBar.
/// A busy Mac makes the rabbit move more quickly, echoing the connection
/// between activity and motion without turning the overlay into a benchmark.
struct RabbitPerformance: Equatable {
    let cpuPercent: Double
    let animationSpeed: CGFloat
    let status: String

    init(cpuPercent: Double) {
        let clamped = Self.clamp(cpuPercent)
        self.cpuPercent = clamped
        self.animationSpeed = Self.speed(for: clamped)
        self.status = Self.status(for: clamped)
    }

    static func speed(for cpuPercent: Double) -> CGFloat {
        let normalized = clamp(cpuPercent) / 100
        // Keep the gait in a natural range. Load changes the tempo, but does
        // not turn the rabbit into a perpetually fast animation.
        return CGFloat(0.75 + normalized * 0.90)
    }

    static func status(for cpuPercent: Double) -> String {
        switch clamp(cpuPercent) {
        case ..<20: return "Calm"
        case ..<50: return "Active"
        case ..<80: return "Busy"
        default: return "Zooming"
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, 0), 100)
    }
}

final class SystemMetricsSampler {
    private var previousCPU: (user: UInt64, system: UInt64, nice: UInt64, idle: UInt64)?

    func sample() -> SystemMetricsSnapshot {
        let cpu = sampleCPU()
        return SystemMetricsSnapshot(cpuPercent: cpu, memoryPercent: sampleMemory())
    }

    private func sampleCPU() -> Double {
        var load = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &load) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }

        let current = (
            user: UInt64(load.cpu_ticks.0),
            system: UInt64(load.cpu_ticks.1),
            nice: UInt64(load.cpu_ticks.2),
            idle: UInt64(load.cpu_ticks.3)
        )
        defer { previousCPU = current }
        guard let previousCPU else { return 0 }

        let user = current.user &- previousCPU.user
        let system = current.system &- previousCPU.system
        let nice = current.nice &- previousCPU.nice
        let idle = current.idle &- previousCPU.idle
        let total = user &+ system &+ nice &+ idle
        guard total > 0 else { return 0 }
        return min(100, Double(user &+ system &+ nice) / Double(total) * 100)
    }

    private func sampleMemory() -> Double? {
        var statistics = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let used = Double(statistics.active_count + statistics.wire_count + statistics.compressor_page_count)
        let available = used + Double(statistics.free_count + statistics.inactive_count)
        guard available > 0 else { return nil }
        return min(100, max(0, used / available * 100))
    }
}
