import Foundation

enum TDNStylePreset: String, CaseIterable, Identifiable {
    case clearTouches
    case presentationTrail
    case recordingGuide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clearTouches: return "Clear Touches"
        case .presentationTrail: return "Presentation Trail"
        case .recordingGuide: return "Recording Guide"
        }
    }

    var subtitle: String {
        switch self {
        case .clearTouches: return "26 pt teal dots. Clear taps with no trail."
        case .presentationTrail: return "28 pt blue brush. Make swipe directions easy to follow."
        case .recordingGuide: return "30 pt teal markers with a soft trail. Only while recording."
        }
    }

    var symbol: String {
        switch self {
        case .clearTouches: return "smallcircle.filled.circle"
        case .presentationTrail: return "scribble.variable"
        case .recordingGuide: return "record.circle"
        }
    }

    private var values: [String: Any] {
        var values: [String: Any] = [
            "isRecordingOnly": false,
            "fillColorString": "13,148,136,0.3",
            "borderColorString": "13,148,136",
            "alpha": 0.85,
            "fillSize": 26.0,
            "borderWidth": 2.0,
            "cornerRadius": 30.0,
            "animationDuration": 0.3,
            "liftScale": 1.5,
            "useMorphEffect": false,
            "useTrackingEffect": false,
            "useQuickPathEffect": false,
            "useImageEffect": false,
            "quickPathFillColorString": "13,148,136,0.3",
            "trackingFillColorString": "13,148,136,0.12",
            "trackingBorderColorString": "13,148,136,0.3",
        ]
        switch self {
        case .clearTouches:
            break
        case .presentationTrail:
            values.merge([
                "fillSize": 28.0,
                "fillColorString": "37,99,235,0.3",
                "borderColorString": "37,99,235",
                "quickPathFillColorString": "37,99,235,0.35",
                "trackingFillColorString": "37,99,235,0.12",
                "trackingBorderColorString": "37,99,235,0.3",
                "animationDuration": 0.5,
                "liftScale": 1.6,
                "useQuickPathEffect": true,
            ]) { _, newValue in newValue }
        case .recordingGuide:
            values.merge([
                "isRecordingOnly": true,
                "fillSize": 30.0,
                "alpha": 0.9,
                "borderWidth": 2.5,
                "animationDuration": 0.4,
                "liftScale": 1.8,
                "useTrackingEffect": true,
            ]) { _, newValue in newValue }
        }
        return values
    }

    func apply(to defaults: TDNUserDefaults) {
        defaults.beginUpdates()
        defer { defaults.endUpdates() }

        // Preserve the master switch and saved images while replacing the visual style.
        for (key, value) in values {
            defaults.set(value, forKey: key)
        }
    }
}
