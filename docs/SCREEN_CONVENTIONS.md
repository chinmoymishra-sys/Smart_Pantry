# Screen implementation conventions

Read this before writing any screen. The foundation (theme, widgets, models,
SQLite, repositories, controllers, router) is in place; screens are Views only.

## Design sources (authoritative)
- Verbatim copy + layout positions per screen: `docs/figma_specs/screen_text/<screen>.txt`
  Format: `y<top> x<left> h<font size px> | text` (coordinates are inside a 402px-wide frame;
  the mobile screen starts at y≈49; status bar "9:41" and the first line — the journey
  label like "05 · Review / before saving" — are Figma annotations, NOT app UI).
- Rendered screens (look at these!): `C:\Users\CHINMO~1\AppData\Local\Temp\claude\7415452d434d6638\928154fe-c3bb-495f-90ac-31d7b011d536\scratchpad\screens\<screen>.png` (402px wide, 1:1 scale; open with the Read tool).
- Some screens also have a detailed style spec in `docs/figma_specs/<screen>.md`.
- Photos are in `assets/images/` (see list there). Use `FoodImage(path: 'assets/images/x.jpg', height: …)`.
- Icons are Lucide: `import 'package:lucide_icons_flutter/lucide_icons.dart';` → `LucideIcons.camera`,
  `imageUp`, `scanBarcode`, `pencilLine`, `chevronRight`, `circleCheck`, `circle`, `info`, `circleAlert`,
  `slidersHorizontal`, `arrowDownWideNarrow`, `arrowRightLeft`, `arrowUpRight`, `minus`, `plus`, `circleMinus`,
  `circlePlus`, `timer`, `pause`, `play`, `rotateCcw`, `list`, `listOrdered`, `utensils`, `trash2`, `zapOff`,
  `zap`, `switchCamera`, `images`, `imagePlus`, `imageOff`, `cameraOff`, `searchX`, `shoppingBasket`,
  `shoppingBag`, `leaf`, `sprout`, `calendarClock`, `heart`, `refreshCw`, `loaderCircle`, `wifiOff`,
  `scanSearch`, `packageCheck`, `search`, `check`, `x`.

## Styling rules
- Never hardcode colours: `final c = context.colors;` (`lib/core/theme/app_colors.dart`) →
  `c.textPrimary`, `c.textMuted`, `c.surface`, `c.surfaceMuted`, `c.border`, `c.primary`, `c.onPrimary`,
  `c.warning`, `c.warningSurface`, `c.danger`, `c.dangerSurface`, `c.cameraSurface`. Dark mode must work.
- Text styles: `AppTypography.*` (`pageTitle` 28, `sectionTitle` 20, `stepTitle` 20 medium, `bodyLarge` 17,
  `title` 15, `titleStrong` 15 semibold, `subtitle` 14, `body` 13, `label` 13 semibold, `caption` 12,
  `overline` 11, `stat` 25, `timer` 38, `amount` 40, `hero` 32). Always `.copyWith(color: c.…)`.
- Spacing/radii: `AppSpacing`, `AppRadii` (`lib/core/theme/app_spacing.dart`).

## Shared widgets (lib/core/widgets) — reuse, don't re-create
- `AppPage(title:, subtitle:, showBack:, onBack:, children: [...])` — every screen. 20px gap between children.
  Tab roots use `showBack: false` (bottom nav comes from the shell).
- `AppButton(label:, icon:, onPressed:, loading:)`, `AppButton.secondary(...)`, `AppButton.danger(...)`.
  `onPressed: null` = muted disabled look. `TextAction(label:, onPressed:, danger:)`. `RoundIconButton(...)`.
- `AppCard(child:, tone: AppCardTone.surface|muted|danger|warning, onTap:, selected:, padding:)`.
- `InfoCallout(title:, body:, tone: CalloutTone.neutral|warning|danger, icon:)`.
- `SectionHeading('Title', action: 'View inventory', onAction: ...)`.
- `DetailRows([('Label', 'Value'), ...])` (140px label column), `Footnote('...')`, `Overline('BREAKFAST')`.
- `StatTile(label:, value:)`.
- `AppChip(label:, selected:, onTap:)`, `ChipWrap(children:)`, `ChoiceChips<T>(...)`, `StatusPill`, `OptionTile`.
- Fields: `LabeledField(label:, helper:, child:)`, `AppTextField(controller:, hint:, keyboardType:, inputFormatters: quantityInputFormatters)`,
  `AppPickerField`, `AppSelectField<T>(value:, options:, labelOf:, onChanged:, title:)`, `AppDateField(value:, onChanged:)`,
  `showOptionSheet<T>(...)`.
- `FoodImage(path:, height:, width:, radius:)` — asset or local file.
- States: `StateCard(overline:, icon:, title:, body:, actions:)`, `LoadingView`, `ErrorStateView(error:, onRetry:)`,
  `showAppSnack(context, msg)`, `showConfirmDialog(context, title:, body:, confirmLabel:, destructive:)`, `friendlyError(e)`.

## Architecture rules (MVC + Riverpod 3)
- Screens are `ConsumerWidget` / `ConsumerStatefulWidget`. `ref.watch(provider)` in build,
  `ref.read(provider.notifier).method()` in handlers. Never import sqflite or repositories in views.
- AsyncValue: use `.when(data:, loading:, error:)` or `.value` (Riverpod 3 — there is no `valueOrNull`).
- Wrap mutations in try/catch; on error `showAppSnack(context, friendlyError(e))`. Guard double taps with a
  local `_saving` flag and pass `loading:` to AppButton. Check `context.mounted` after awaits.
- Navigation: `import 'package:go_router/go_router.dart';` + `lib/core/navigation/routes.dart`.
  `context.push(Routes.item(id))`, `context.pop()`, `context.go(Routes.inventory)` for tab roots.
- Formatting helpers: `formatQuantity(v, unit)`, `formatNumber`, `parseQuantity` (`lib/core/utils/units.dart`);
  `AppDates.long/short/dayMonth/relative/activityStamp/today()` (`lib/core/utils/dates.dart`).
- Enums with `.label`: `lib/core/enums/pantry_enums.dart`. Units: `PantryUnit.selectable`, `unit.dbValue`.

## Product rules you must honour in UI
- Nothing changes inventory until an explicit confirm button; previews show before/after.
- Never invent quantities, dates, quality or safety. Unknown dates show "Not set" / "No date recorded".
  Quality/freshness default "Not assessed". No fake AI recognition and no fake barcode catalog.
- Every visible control must work. If something genuinely can't work offline (photo recognition — there is no
  recognition service in this build), show the honest state from the design and offer the manual path.
- Don't change files outside your assigned folders. If you need a new controller method in a feature you
  don't own, implement the logic locally in your screen via existing public APIs, and mention it in your report.
- Run `flutter analyze lib/features/<yours>` before finishing; zero errors/warnings in your files.
