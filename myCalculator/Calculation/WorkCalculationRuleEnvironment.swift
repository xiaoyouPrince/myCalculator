import SwiftUI

private struct WorkCalculationRuleIDKey: EnvironmentKey {
    static let defaultValue = WorkCalculationRegistry.defaultRuleID
}

extension EnvironmentValues {
    var workCalculationRuleID: String {
        get { self[WorkCalculationRuleIDKey.self] }
        set { self[WorkCalculationRuleIDKey.self] = newValue }
    }
}
