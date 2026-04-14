# Issues Log

## [FIXED] Ability Unlock Toast — Blank Solid Block, No Text

**Status:** Fixed  
**Introduced:** commit `f460b42` (add 6 more abilities / refactor abilities)  
**Fixed:** commit after `a74c316`

### Symptom
When an ability was unlocked the toast notification slid in from the top but appeared as a solid dark block with no visible text, icons, slot chip, or coloured left border content. The background container rendered but all content was invisible.

### Root Cause (two parts)

**Part 1 — Missing inherited widget scope**  
`OverlayEntry` builders run in the root overlay context, which sits above `MaterialApp`'s `Theme`, `MediaQuery`, and `Directionality` wrappers in the widget tree. Without these, `Text` widgets have no font metrics or text direction and render as empty/invisible.

**Part 2 — `Material(color: Colors.transparent)` computes black text**  
Even after adding the Theme/MediaQuery/Directionality wrappers (attempted fix in `a74c316`), the toast still showed a blank block because `Material(color: Colors.transparent)` internally computes a `DefaultTextStyle` colour by checking the colour's brightness. `Colors.transparent` has no luminance so Flutter falls back to `Colors.black` — invisible against the dark `AppTheme.surface` (`0xFF0D0D1A`) card background.

### Fix

**File:** `lib/widgets/abilities/ability_unlock_toast.dart`

1. In `AbilityUnlockToast.show()`, capture all four inherited values from the caller's context before creating the `OverlayEntry`:
   ```dart
   final themeData = Theme.of(context);
   final mediaQueryData = MediaQuery.of(context);
   final textDirection = Directionality.of(context);
   final defaultTextStyle = themeData.textTheme.bodyMedium ?? const TextStyle();
   ```
   Then wrap the entry content in `Directionality → MediaQuery → Theme → DefaultTextStyle`.

2. In `_ToastOverlay.build`, change:
   ```dart
   // Before
   Material(color: Colors.transparent, child: _ToastCard(...))
   // After
   Material(type: MaterialType.transparency, child: _ToastCard(...))
   ```
   `MaterialType.transparency` skips the colour-brightness text-colour computation and inherits text colour from the ambient `DefaultTextStyle`.

### Verification
Run the app, trigger an ability unlock, confirm the toast shows the lock icon, "ABILITY UNLOCKED" header, ability name, slot chip, and description with the correct coloured left border.

---

## [FIXED] Ability Unlock Toast — Rendering Crash: borderRadius with non-uniform Border colors

**Status:** Fixed  
**Introduced:** commit `a74c316` (added more abilities / abilities unlock toast overlay)  
**Fixed:** after `a74c316`

### Symptom
When an ability was unlocked the toast crashed at paint time with:
> `A borderRadius can only be given on borders with uniform colors.`
> `The following is not uniform: BorderSide.color`

The app logged the exception from `ability_unlock_toast.dart:167` (the `_ToastCard` `Container`).

### Root Cause
`_ToastCard.build` used a `BoxDecoration` with both `borderRadius: BorderRadius.circular(14)` and a `Border(...)` whose left side had a different color (`slotColor`) from the other three sides (`AppTheme.border`). Flutter's `BoxBorder.paint` asserts that rounded-corner borders must have uniform side colors — it cannot interpolate corner arcs across a color boundary.

### Fix

**File:** `lib/widgets/abilities/ability_unlock_toast.dart` — `_ToastCard.build`

Replace the non-uniform `Border(...)` with a `ClipRRect` + `Stack` approach:
- Outer `ClipRRect(borderRadius: BorderRadius.circular(14))` clips all children to the rounded rect.
- Inner `Container` uses `Border.all(color: AppTheme.border)` (uniform) for the card outline.
- A `Positioned(left:0, top:0, bottom:0)` child `Container(width:3, color:slotColor)` renders the left accent bar, clipped by the `ClipRRect` so it doesn't bleed past the corners.

### Verification
Run the app, trigger an ability unlock, confirm:
- No rendering exception in the console.
- Toast card has a visible colored left accent bar matching the ability slot.
- Rounded corners are preserved on all four sides.
