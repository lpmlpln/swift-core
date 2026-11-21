# MealPlanner Core

Pure Swift shared domain package used by the Vapor API and the iOS app.

## Modules

- `Domain` — `CalendarDate`, `Recipe`, `Ingredient`, `Plan`, `PlanRules`, units
- `Planning` — deterministic `MealPlanGenerator` with rules, locks and batch cooking
- `Shopping` — `IngredientAggregator`, unit conversion and categorization
- `CRDT` — HLC, LWW registers/maps, tombstones, plan and shopping documents
- `Import` — URL normalization and imported recipe validation
- `Contract` — shared DTOs, error codes and mappers

## Commands

```bash
swift build
swift test
```

Requires Swift 6.0 or newer. The package is the single source of truth for
planning and CRDT behavior; keep the backend and iOS on the same tagged version.
