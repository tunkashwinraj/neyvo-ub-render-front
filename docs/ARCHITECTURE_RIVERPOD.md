# Flutter UI architecture — Riverpod-first screens

## Route-level rule

Every user-facing **page/screen** under `lib/` must use **`ConsumerWidget`** or **`ConsumerStatefulWidget`** and import `package:flutter_riverpod/flutter_riverpod.dart`. Do not use plain `StatelessWidget` / `StatefulWidget` as the **exported** screen widget for routes.

## State rule

- **Do not use `setState`** for: data loading, selections, filters, pagination, form submission results, API outcomes, or any state that should survive rebuilds or be testable in isolation.
- Put that state in **`@riverpod` classes** (`Notifier`, `AsyncNotifier`, etc.) with `part '*.g.dart'`, following [`lib/core/providers/calls_provider.dart`](../lib/core/providers/calls_provider.dart).
- Run code generation after provider changes:  
  `dart run build_runner build --delete-conflicting-outputs`

## Provider placement

- **Shared / cross-feature** data (account, calls list, billing): `lib/core/providers/`.
- **Feature-local** UI flow state: next to the feature, e.g. `lib/features/<feature>/<feature>_controller.dart` + `.g.dart`.

## Documented exceptions (`setState` / `StatefulWidget` allowed)

Inside a `ConsumerStatefulWidget`’s `State`, you may still use:

1. **`AnimationController`** / `SingleTickerProviderStateMixin` / ticker glue (e.g. loaders).
2. **Ephemeral controllers** with explicit lifecycle in `initState` / `dispose`: `TextEditingController`, `ScrollController`, `FocusNode`.

Mark other rare cases with: `// riverpod-migration-allowed: <reason>`

## Nested widgets

Private helpers may remain `StatelessWidget`. Nested **`StatefulWidget`** for substantial app state should be migrated to Riverpod (see migration phases).

## Testing

Widget tests must wrap the tree with **`ProviderScope`** and override providers when mocking APIs.

## Migration status (snapshot)

**Route roots migrated to `Consumer*` + `@riverpod` for primary UI state** (non-exhaustive): Phase 2 small screens; health / backup / billing subpages; dialer; dev console; voice library & studio; training knowledge; template scripts; studio projects; callbacks; UB onboarding & model overview; main pulse onboarding (`onboarding_flow_provider`); call detail (`call_detail_provider`); phone number routing (`phone_number_routing_provider`).

**Phase 5 flows — partially done:** `onboarding_page.dart` uses `onboarding_flow_provider.dart`. **`business_setup_page.dart`**, **`business_setup_interview_page.dart`**, and **`universal_operator_wizard_screen.dart`** are still root `StatefulWidget` + `setState` for flow/API state; extract flow Notifiers next (same patterns as `onboarding_flow_provider` / `ub_onboarding_provider`).

**Still `StatefulWidget` at file root** (other large surfaces): `analytics_page.dart`, `students_list_page.dart`, `student_detail_page.dart`, `managed_profiles/profile_detail_page.dart`, `raw_assistant_detail_page.dart`, `member_detail_page.dart`, `agent_detail_page.dart`, and other very large detail/list surfaces — follow the same notifier extraction pattern as `call_detail_provider` / `phone_number_routing_provider`.

**Nested `StatefulWidget` inside Consumer pages** (e.g. integrations substacks, students hub tabs, campaign dialogs): migrate incrementally; ephemeral UI may use `// riverpod-migration-allowed:` as above (see `_VoiceCard` hover in `voice_studio_page.dart`).
