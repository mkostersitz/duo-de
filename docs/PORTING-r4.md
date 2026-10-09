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

## VNDK (packages/modules/vndk, build/make, manifest)
**Why:** the Surface Duo 2 vendor is VNDK 30 (`ro.vndk.version=30`, sepolicy 30.0) and the Duo 1 vendor is VNDK 29.
AOSP removed the v30 snapshot in September 2025 ("The latest Android does not support the v30 vendor image"), and v29 before that.
Without the apex the vendor libraries have no VNDK namespace to link against.

| Change | Decision |
|---|---|
| `packages/modules/vndk` apex/Android.bp | **New duo patches** that revert "Remove vndk snapshot v30" and "Removing vndk apex v29" (restores the `com.android.vndk.v30` and `.v29` apexes). |
| `build/make` target/product/gsi/Android.bp, gsi_release.mk | **New duo patch** that reverts "Remove vndk snapshot v30" (adds v30 back to the GSI apex list and to `PRODUCT_EXTRA_VNDK_VERSIONS`). |
| `build/default.xml` | **Added** `prebuilts/vndk/v30` at `5f9884aa352825291757dfd6694b874ad8c1805e` (the revision the working android-16.0.0_r2 tree used). v28 and v29 were already pinned. |
| trebledroid `platform_packages_modules_vndk` 0001 (v29) and 0002 (v28) | **Removed from the tree.** They no longer apply on r4 (they expected the v30 block to exist, and r4 deleted it). v29 is covered by the new duo patch. v28 is not needed: no Duo vendor is older than VNDK 29. A future TrebleDroid sync may re-add these two files, and they will conflict again. |

Not yet build-tested on r4.
