import UIKit

enum Haptics {
    static func light() {
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func medium() {
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }

    static func heavy() {
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #endif
    }

    static func success() {
        #if !targetEnvironment(simulator)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func error() {
        #if !targetEnvironment(simulator)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
