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

## TrebleDroid patches dropped for the Duo (20)
These conflict on r4 and are not needed on a Surface Duo. They are removed from `patches/trebledroid`; a future TrebleDroid sync
may re-add them, and they will conflict again.

| Group | Patches | Why they are not needed |
|---|---|---|
| Other-OEM hardware | frameworks/base 0029 (Samsung SehSysInputDev), 0031 (MediaTek touch hints), 0032 (Moto dynamic hardware), 0037 and 0044 (FOD / in-display fingerprint), 0042 and 0043 (Samsung brightness / sysinput), 0049 (try/catch around the dynamic UDFPS position added by the FOD patches); frameworks/native 0008 (FOD), 0009 (MTK GED KPI); packages/modules/Bluetooth 0005 (Samsung audio HAL) | The Duo has none of this hardware. The Duo 2 reader is a side-mounted power-button sensor, not UDFPS. |
| microG | frameworks/base 0048, 0053 | Signature spoofing for microG. Not used by duo-de. |
| BPF-less / old kernel | packages/modules/Connectivity 0002, 0003, 0005, 0006; system/bpf 0001, 0002 | Both Duo kernels have BPF on: `CONFIG_BPF_SYSCALL`, `CGROUP_BPF`, `BPF_JIT`, `NETFILTER_XT_MATCH_BPF` = y in Microsoft's Duo 2 (5.4, `gki_defconfig`) and Duo 1 (4.14, `surfaceduo-perf_defconfig`) kernel sources. |
| Old sepolicy | system/sepolicy 0001 (restore 28.0 compat) | Duo vendors declare sepolicy 29.0 or 30.0, and r4 still ships both. |

## Deferred patches (15) and the product drop
To get an end-to-end r4 build and boot test quickly, the 15 patches that still conflict on r4 are moved to `patches/_deferred/`
(`patch.sh` does not read that folder). They still need porting.

| Patch | Why it matters |
|---|---|
| ~~trebledroid frameworks/av 0001 APM: Restore S, R and Q behavior for telephony audio~~ | **Ported (2026-10-16), compiles, call test pending.** Two conflicts in `AudioPolicyManager.cpp`: r4 removed the `fix_call_audio_patch()` flag (kept the plain `else`), and uses `std::set` instead of `SortedVector`. Added: the HW bridging patches are also released when a call ends (r4 only disconnects the source clients). |
| trebledroid frameworks/opt/telephony 0004 (TelephonyMetrics.writeRilSendSms), 0007 (UiccSlot logging) | Old-RIL compatibility. 0007 is close to the dual SIM / eSIM slot code. |
| trebledroid frameworks/base 0003 (ANDROID_STORAGE empty string), 0011 (work profile count), 0026 (FDE methods in StorageManager), 0050 (sysui media animation prop) | Generic compatibility. |
| trebledroid frameworks/native 0011 (Increase SW_MAX) | Input switch codes. |
| trebledroid system/core 0004 (panic into recovery rather than bootloader), ~~0028 (libfiemap loop mapping)~~ | 0004 changes where a fatal init error goes (recovery instead of bootloader). 0028 enables DSU on old kernels. 0028 is ported (2026-10-16): r4 now validates device-mapper and always uses dm-linear, the port restores the loop-device fallback when /data is not on device-mapper; compiles (libfs_mgr, gsid, phh-ota), needs an OTA test. The Duo 2 /data is on dm-50, so it does not need it. |
| personal frameworks/base 0002 (default permission updates tied to version incremental), 0003 (SystemUI Style.SPRITZ default), 0004 (SenseProvider for FaceSense), 0005 (OmniJaws keyguard slice provider) | 0004 and 0005 are the framework side of face unlock and weather. |
| personal packages/apps/ThemePicker 0001 (Override WallpaperCropper) | Wallpaper cropping. |

Because the SenseProvider and OmniJaws framework patches are deferred, `vendor/ponces` no longer ships **ParanoidSense** or **OmniJaws**
in the product (new duo patch `vendor_ponces/0001`: removes the packages, `ro.face.sense_service` and the face feature file).
Restore them when 0004 and 0005 are ported.

## HIDL clean-up fallout
| Change | Why |
|---|---|
| duo `device_phh_treble` 0006: drop the `vibrator-lge` helper binary | It links `vendor.lge.hardware.vibrator@1.0`, which needs the HIDL interface `android.hardware.vibrator@1.0`. r4 removed that interface, and Soong fails analysis ("depends on undefined module"). No product installs the binary. |
| duo `vendor_interfaces` 0001: remove `vendor/lge/hardware/vibrator` | Same missing dependency. A Surface Duo has no LG vibrator HAL. |

Found by the first r4 build attempt (5 Soong errors, all from this one directory).

## Session keyring workaround reverts (dropped)
| Patch | Why dropped |
|---|---|
| trebledroid `system/vold` 0006 and `system/core` 0027: "Revert ... remove session keyring workaround for old kernels" | Both bring back a dependency on `libkeyutils`, which r4 removed together with the workaround (Soong: `"libvold" depends on undefined module "libkeyutils"`). The workaround targets kernels older than the Duo kernels (4.14 and 5.4). |

Found by the second r4 build attempt.

## sepolicy 28.0 (dropped as a pair)
| Patch | Why dropped |
|---|---|
| trebledroid `build` "Include vndk v28 sepolicy support" | Adds `28.0` to `PLATFORM_SEPOLICY_COMPAT_VERSIONS` in `core/config.mk`, so Soong expects the 28.0 compat modules (`28.0_compat_test` needs `plat_28.0.cil`, ...). Those come from the sepolicy 28.0 revert that was already dropped (no Duo vendor is older than sepolicy 29.0). The two patches must be kept or dropped together. |

Found by the third r4 build attempt (6 Soong errors, all from `28.0_compat_test`).

## Samsung radio libraries in framework-internal-utils (dropped)
| Patch | Why dropped |
|---|---|
| trebledroid `frameworks/base` 0046 (`vendor.samsung.hardware.radio.network-V1-java`) and 0047 (`vendor.samsung.hardware.radio-V2.2-java`) | They add vendor Samsung HAL libraries to `framework-internal-utils`. r4 refuses to put non-generic modules in the generic system image (Soong: `module "aosp_shared_system_image" ... includes non-generic modules: "vendor.samsung.hardware.radio-V2.2-java" from "framework-internal-utils"`). Archfx a16-dev had already removed the matching `frameworks/opt/telephony` Samsung patches (0008, 0009). |

The remaining Samsung patches (camera ids, light HAL, power HAL) apply and were not flagged. Revisit if a later check objects.
Found by the fourth r4 build attempt.

## Compile fixes
| Change | Why |
|---|---|
| duo `frameworks/native` 0001: remove `failToLoadFromDriverSuffixProperty` from `opengl/libs/EGL/Loader.cpp` | TrebleDroid's "Fix loading unnamed GLES" (0010) simplifies the fallback condition, which removes the only read of the variable. clang in r4 then fails the build: `variable 'failToLoadFromDriverSuffixProperty' set but not used [-Werror,-Wunused-but-set-variable]`. |

Found by the fifth r4 build attempt (first compile error, after Soong analysis passed).

| duo `Launcher3` 0001, `ActivityOptionsWrapper.java` | The Duo patch reads `DeviceProfile.isTablet` and `DeviceProfile.widthPx`. r4 moved these into `DeviceProperties`, so javac failed (`cannot find symbol`). Now `getDeviceProfile().getDeviceProperties().isTablet()` and `.getWidthPx()`. Only the `DeviceProfile.java` hunk had conflicted textually, so this was missed in the first port. |

Found by the sixth r4 build attempt (javac error in `Launcher3QuickStepLib`).

## Cosmetic
| Change | Why |
|---|---|
| duo `Settings` 0001 "gsi info added": `System Image` row now reads `ARCHFX/DUO-DE A16 (archfx.me/duo-de)` | The string was written during the A15 work (`A15b`) and carried into the A16 branch unchanged, so the About screen showed the wrong Android version. Takes effect on the next full patch run (resource only). |

## Weather: the Settings half is deferred with the framework half
`personal/platform_packages_apps_Settings` 0002 ("LockScreen: Add pixel style lockscreen weather based on OmniJaws") imports
`com.android.internal.util.crdroid`, which is added by the deferred `personal/platform_frameworks_base` 0005 (OmniJaws keyguard slice provider).
With only the Settings half applied, `Settings-core` fails to compile (`package com.android.internal.util.crdroid does not exist` in
`LockScreenWeatherPreferenceController.java` and `LockscreenDashboardFragment.java`). Both halves must be applied together, so the Settings patch
is now in `patches/_deferred/` too. Restore both when the framework patch is ported.

Found by the seventh r4 build attempt (2 javac failures).

| duo `vendor_magisk` 0001: replace `__BIONIC_ALIGN` in `Magisk/native/jni/systemproperties/prop_area.cpp` with the equivalent round-up expression | bionic in r4 no longer defines `__BIONIC_ALIGN`, so `resetprop_phh` fails to compile (`use of undeclared identifier '__BIONIC_ALIGN'`). `resetprop_phh` is used by `phh-prop-handler.sh` to override a few audio and Bluetooth properties. |

Found by the eighth r4 build attempt (late in the compile, at 84%).

## BPF loader: why r4 and stock A17 reboot at about 25 seconds (and why dropping the BPF patches was wrong)
The first r4 image boot-looped at the Surface logo, like the stock A17 GSI. Both loaders have a fatal path:
`NetBpfLoad.cpp` ("DO NOT EXPECT SYSTEM TO BOOT SUCCESSFULLY", `sleep(20)`, `return 38`) and `system/bpf` `Loader.cpp`
(`sleep(20); exit(121)`), and `netbpfload.35rc` has `reboot_on_failure reboot,bpfloader-failed`. The 20 second sleep matches the observed timing.

Earlier in this port the six "BPF-less / old kernel" TrebleDroid patches were dropped on the grounds that both Duo kernels have BPF enabled in
their defconfigs. **That reasoning was wrong**: enabled does not mean every program Android loads will pass the verifier on a 5.4 kernel.
Those patches turn exactly these fatal paths into non-fatal ones, which is why r2 booted.

| Change | Purpose |
|---|---|
| duo `Connectivity` 0001: comment out `reboot_on_failure reboot,bpfloader-failed` in `netbpfload.35rc` | Debug step recommended by the AOSP rc comments: boot anyway, then read `adb logcat -s 'bpfloader:*' 'LibBpfLoader:*' 'NetBpfLoad:*' 'NetBpfLoader:*'` to find the BPF program that fails on the Duo kernel. A permanent fix should address that program (or tolerate it) rather than hide it. |

## BPF: restoring the TrebleDroid BPF-tolerance set (root cause of the r4 boot hang)
**Root cause.** android-16.0.0_r4 (25Q4) added a hard gate in the Mainline `NetBpfLoad`: `Android 25Q4 requires kernel 5.10` (`return 7`).
The Surface Duo 2 kernel is 5.4.233, so `netbpfload` exits at once and never reaches the platform bpfloader hand-off, so the final `netbpfload done` step never sets
`bpf.progs_loaded=1`. Services that wait for that property never start, and the device sits on the boot animation with no `system_server` and
no USB. With `reboot_on_failure reboot,bpfloader-failed` it instead reboots after about 25 seconds. The stock Android 17 GSI fails the same way.
Earlier in this port the six BPF-less TrebleDroid patches were dropped because the Duo kernel configs have BPF enabled. That was wrong: the gate is on kernel *version*.

**What was done.** The TrebleDroid set is restored and ported (they turn the version gates and load failures into non-fatal `failed = true`).

| Patch | Decision |
|---|---|
| `Connectivity` 0001, 0004, 0007, 0008, 0009 | Applied unchanged (they were never dropped). |
| `Connectivity` 0002 "Support non-working BPF maps" | **Ported.** `NetBpfLoad.cpp`: every hard `return N` in `doLoad` becomes `failed = true` (15 hunks, including r4's new 25Q4 gate and the 6.13+ userspace gate), the 20 s sleep is removed, and a summary is logged. `NetworkStatsService.java`: BPF map fields become non-final and null-initialized, with r4's key types (`S64`, `S32`). The rest of the patch applied by 3-way merge and still needs a compile check. |
| `Connectivity` 0003 "traffic indicators for legacy devices" | **Ported.** r4's stats struct is kept and the patch's `/proc/net/xt_qtaguid` constants are added; the three stats entry points fall back to parsing `/proc` when BPF stats fail. |
| `Connectivity` 0005 "netd: remove <4.14 restrictions" | **Ported.** The 4.9 and 4.14 kernel checks in `BpfHandler.cpp` are removed (the Duo passes them either way). |
| `Connectivity` 0006 "More bpf errors ignore" | **Dropped.** Its effect (non-fatal sysctl write failures) is already covered by 0002's `failed = true` conversion. |
| `system/bpf` 0001 "Support no-bpf usecase" | **Ported.** r4's `vendorBpfLoader()` no longer aborts when `/vendor/etc/bpf` objects fail to load: it logs and carries on to the final "done" re-exec. |
| `system/bpf` 0002 "Additional bpf-less handling" | **Dropped.** It edits `createBpfFsSubDirectories()`, which no longer exists in r4 (that logic moved into `NetBpfLoad.cpp`, covered by Connectivity 0002). |
| `system/bpf` 0003 | Applied unchanged. |

The duo `Connectivity` 0001 (no `reboot_on_failure` in `netbpfload.35rc`) stays for bring-up. Revisit once the system boots with the tolerance patches.
**Caveat for Archfx/TrebleDroid:** on a 5.4 kernel this means r4 runs with little or no BPF. Data-usage accounting, per-UID firewall rules and tethering offload may be degraded.
