//
//  BurnoutAnalyzer.swift
//  Ergon
//
//  Created by Raaj  Patkar on 17/04/26.
//

import Foundation
import CoreML
import Observation

// The Core ML model may have additional inputs like Subjective_Score and Baseline_Deltas.
// Defaults are used here until the UI collects them from the user.

@Observable
class BurnoutAnalyzer {
    private var model: BurnoutPredictor?
    var currentRisk: String = "Unknown"
    var isAnalyzing: Bool = false
    
    init() {
        // Load the model once during initialization for better performance
        let config = MLModelConfiguration()
        self.model = try? BurnoutPredictor(configuration: config)
    }
    
    /// Predicts burnout risk based on sleep, HRV, and calendar density.
    /// - Parameters:
    ///   - sleepHours: Hours of sleep (Double)
    ///   - hrv: Heart Rate Variability in ms (Double)
    ///   - calendarDensity: Number of meetings/events (Double)
    @MainActor
    func predictRisk(sleepHours: Double, hrv: Double, calendarDensity: Double, subjectiveScore: Double) async {
        guard let model = model else {
            currentRisk = "Model Error"
            return
        }
        
        isAnalyzing = true
        
        // Simulate a slight delay for better UX and to show the "Analyzing" state
        try? await Task.sleep(for: .seconds(0.8))
        
        do {
            let input = BurnoutPredictorInput(
                Sleep_Hours: sleepHours,
                HRV_ms: hrv,
                Calendar_Density: calendarDensity,
                Subjective_Score: subjectiveScore,
                Baseline_Deltas: 0.0
            )
            
            // Use async prediction if available, otherwise fallback to synchronous
            let prediction = try await model.prediction(input: input)
            currentRisk = prediction.Burnout_Risk
        } catch {
            print("Error making prediction: \(error)")
            currentRisk = "Error"
        }
        
        isAnalyzing = false
    }
}
