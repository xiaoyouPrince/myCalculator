# AI Project Context

> This file is the project-specific AI entry point for myCalculator.  
> General AI collaboration rules live in `/Users/quxiaoyou/Documents/AI`.

## Must Read First

1. `/Users/quxiaoyou/Documents/AI/README.md`
2. `/Users/quxiaoyou/Documents/AI/AI协作问题复盘与实践指南.md`
3. `README.md`
4. `docs/help-index.md`
5. `docs/month-view-rendering-postmortem.md` when touching month view, date rendering, SwiftUI identity, or visual state
6. `docs/swiftui-uikit-mental-models.md` when touching complex SwiftUI view identity or lazy containers
7. `docs/browser-extension-autofill.md` when changing export data or browser-extension-related behavior

## Project Shape

myCalculator is a SwiftUI macOS work-hour calendar app. It records work schedules, computes work hours and overtime, persists JSON locally, exports CSV / minimal JSON, and has a browser extension for autofill workflows.

The project intentionally keeps product docs, engineering postmortems, and technical articles under `docs/` and exposes some of them through the App Help menu.

## Build And Verify

Normal local build:

```bash
xcodebuild \
  -project myCalculator.xcodeproj \
  -scheme myCalculator \
  -configuration Debug \
  -derivedDataPath /tmp/myCalculatorDerived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

For UI bug fixes, build success is not enough. Use the real app path from the explicit `-derivedDataPath`, terminate old instances, fresh launch, and verify by screenshot or direct visual inspection.

Recommended UI verification flow:

```bash
pkill -f '/myCalculator.app/Contents/MacOS/myCalculator'
open -n -F /tmp/myCalculatorDerived/Build/Products/Debug/myCalculator.app
```

Then capture the app window, not the full desktop, and compare against the user reproduction path.

## Project-Specific Rules

- UI fixes require real app verification, especially when the user provides a screenshot or exact reproduction steps.
- Be suspicious of SwiftUI `ForEach` using array offsets as identity.
- For `LazyVGrid`, `List`, and `LazyVStack`, check identity, state retention, and semantic `.id(...)` boundaries.
- Month/day display state should be computed from the displayed month context, not only from stale model booleans.
- Keep the graphical date picker behavior unless there is a clear reason to revisit it; compact date input caused year mis-parsing before.
- If a doc is read by the app Help menu, ensure it is also wired into app resources / help index as needed.
- Export format changes can affect the browser extension. Update docs and extension expectations together.

## Important Paths

| Area | Path |
| --- | --- |
| Xcode project | `myCalculator.xcodeproj` |
| App entry | `myCalculator/myCalculatorApp.swift` |
| Main container | `myCalculator/ContentView.swift` |
| Views | `myCalculator/Views/` |
| Models | `myCalculator/Models/WorkScheduleModels.swift` |
| Store | `myCalculator/Stores/WorkScheduleStore.swift` |
| Docs/help index | `docs/help-index.md` |
| Month view postmortem | `docs/month-view-rendering-postmortem.md` |
| SwiftUI/UIKit article | `docs/swiftui-uikit-mental-models.md` |
| Browser extension docs | `docs/browser-extension-autofill.md` |
| Browser extension source | `browser-extension/` |

## Documentation Maintenance

Keep general AI collaboration rules in `/Users/quxiaoyou/Documents/AI`.

Keep this file focused on myCalculator-specific context: SwiftUI UI verification, date/month rendering, work-hour rules, persistence/export behavior, and Help-menu documentation.

After complex bug fixes, add or update a postmortem under `docs/` with reproduction, root cause, fix principles, and verification steps.
