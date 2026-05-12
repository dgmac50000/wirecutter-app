import ExpoModulesCore
import UIKit

public class HapticsAdvancedModule: Module {
    public func definition() -> ModuleDefinition {
        Name("HapticsAdvanced")

        Function("triggerCustomPattern") { (intensity: Double) in
            let generator = UIImpactFeedbackGenerator(
                style: intensity > 0.7 ? .heavy : intensity > 0.4 ? .medium : .light
            )
            generator.prepare()
            generator.impactOccurred(intensity: CGFloat(intensity))
        }

        Function("triggerSelection") {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }

        Function("triggerNotification") { (type: String) in
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            switch type {
            case "success":
                generator.notificationOccurred(.success)
            case "warning":
                generator.notificationOccurred(.warning)
            case "error":
                generator.notificationOccurred(.error)
            default:
                generator.notificationOccurred(.success)
            }
        }
    }
}
