# Porting duo-de to android-16.0.0_r4

Decisions are recorded per patch so the next person does not have to rediscover them.
Method: each project is reset to its r4 manifest revision, the patch series is applied in order with
`git am -3`, conflicts are resolved by hand, and the series is regenerated with `git format-patch`.

## patch.sh
Now uses `git am -3`. Several patches only apply on r4 through a 3-way merge (context drift), and a plain
`git am` stops the build on them.

## packages/apps/Launcher3
| Patch | Decision |
|---|---|
| personal 0003 Properly expose GridCustomizationsProvider | **Dropped.** r4 protects the provider with a static `GRID_CONTROL` permission and known signer certs (upstream commits "Use static permission..." and "Enforcing grid customization permission in manifest"). The patch added `android:permission` / read / write permissions to the provider and conflicts with that design. |
| duo 0001 Archfx DUO-DE Launcher3 Modifications | **Ported.** One real hunk in `DeviceProfile.java`: r4 replaced `widthPx` / `heightPx` with `mDeviceProperties.getWidthPx()` / `getHeightPx()`, so the Duo all-apps scaling (0.7, or 0.95 when the width exceeds 2500) is rewritten with those. |
| duo 0002 update-proguard-flags | **Ported.** The patch context expected `-dontwarn com.android.internal.util.**` and the protolog keep rule, which r4's `proguard.flags` no longer has. Kept r4's block and added only the three new keep rules (`ResourceBasedOverride`, `TaskbarModelCallbacksFactory`, `TaskbarViewCallbacksFactory`). |

Not yet build-tested on r4.
