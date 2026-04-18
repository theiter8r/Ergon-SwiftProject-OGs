import Foundation
import HealthKit

class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    // The data types we want to read
    let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    
    func requestAuthorization() async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKitManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device."])
        }
        
        let typesToRead: Set<HKObjectType> = [sleepType, hrvType]
        let typesToWrite: Set<HKSampleType> = [sleepType, hrvType]
        
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
        return true
    }
    
    // MARK: - Dummy Data Generation
    func generateRealisticDummyData() async throws {
        _ = try await requestAuthorization()
        
        var samplesToSave: [HKSample] = []
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Realistic Sleep Data (~7.5 hours from 11:30 PM last night to 7:00 AM today)
        let thisMorning = calendar.startOfDay(for: now).addingTimeInterval(7 * 3600) // 7:00 AM
        let lastNight = thisMorning.addingTimeInterval(-7.5 * 3600) // 11:30 PM
        
        let sleepSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: lastNight,
            end: thisMorning
        )
        samplesToSave.append(sleepSample)
        
        // 2. Realistic HRV Data (A few readings averaging ~65ms)
        let hrvUnit = HKUnit.secondUnit(with: .milli)
        let hrvValues = [58.0, 65.0, 72.0] // Realistic HRV readings in ms
        
        for (index, value) in hrvValues.enumerated() {
            let sampleTime = thisMorning.addingTimeInterval(TimeInterval(index * 3600)) // Hourly readings starting at 7 AM
            let quantity = HKQuantity(unit: hrvUnit, doubleValue: value)
            let hrvSample = HKQuantitySample(
                type: hrvType,
                quantity: quantity,
                start: sampleTime,
                end: sampleTime
            )
            samplesToSave.append(hrvSample)
        }
        
        // Save everything to HealthKit
        try await healthStore.save(samplesToSave)
    }
    
    func fetchLastNightSleep() async throws -> Double {
        // Look at data from the past 24 hours
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .hour, value: -24, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        // Sort by end date descending
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0.0) // No data
                    return
                }
                
                // Calculate total sleep time (Asleep stages)
                var totalSleepSeconds: TimeInterval = 0
                for sample in sleepSamples {
                    // In iOS 16+, sleep analysis has multiple stages. We count anything that isn't .awake or .inBed (which is just time in bed, not necessarily asleep)
                    if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                        totalSleepSeconds += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }
                
                let hours = totalSleepSeconds / 3600.0
                continuation.resume(returning: hours)
            }
            healthStore.execute(query)
        }
    }
    
    func fetchTodayHRV() async throws -> Double {
        // Look at data from the start of today
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            // Use statistics query to get the average HRV for today
            let query = HKStatisticsQuery(quantityType: hrvType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let averageQuantity = result?.averageQuantity() else {
                    continuation.resume(returning: 0.0) // No data
                    return
                }
                
                // HRV is typically measured in milliseconds (ms)
                let hrvValue = averageQuantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: hrvValue)
            }
            healthStore.execute(query)
        }
    }
}
