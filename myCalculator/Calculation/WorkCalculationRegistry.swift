import Foundation

enum WorkCalculationRegistry {
    // Planned future rules:
    // - dinner-break-v2
    // - compensatory-leave

    nonisolated private static let legacyTenHourRule = LegacyTenHourRule()
    nonisolated private static let restDayOvertimeRule = RestDayOvertimeRule()

    nonisolated static let all: [any WorkCalculationRule] = [
        legacyTenHourRule,
        restDayOvertimeRule
    ]

    nonisolated static let defaultRuleID = WorkCalculationRuleID.default

    nonisolated static func rule(id: String) -> any WorkCalculationRule {
        all.first { $0.id == id } ?? legacyTenHourRule
    }
}
