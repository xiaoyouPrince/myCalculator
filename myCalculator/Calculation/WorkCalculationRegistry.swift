import Foundation

enum WorkCalculationRegistry {
    // Planned future rules:
    // - dinner-break-v2

    nonisolated private static let legacyTenHourRule = LegacyTenHourRule()

    nonisolated static let all: [any WorkCalculationRule] = [
        legacyTenHourRule
    ]

    nonisolated static let defaultRuleID = WorkCalculationRuleID.default

    nonisolated static func rule(id: String) -> any WorkCalculationRule {
        all.first { $0.id == id } ?? legacyTenHourRule
    }
}
