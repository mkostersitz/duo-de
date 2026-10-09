# Building DUO-DE

DUO-DE is not a device tree. It is a GSI (generic system image) built from plain AOSP with three
layers of patches, plus a few Surface Duo specific repositories:

| Layer | Where | Source |
|-------|-------|--------|
| TrebleDroid patches (GSI compatibility with old vendors and kernels) | `patches/trebledroid` | [TrebleDroid](https://github.com/TrebleDroid) through [ponces/treble_aosp](https://github.com/ponces/treble_aosp) |
| ponces patches (gapps, face unlock, ThemePicker, ...) | `patches/personal`, `patches/staging` | [ponces/treble_aosp](https://github.com/ponces/treble_aosp) |
| DUO-DE patches (posture engine, dual-screen launcher, pen charger, ...) | `patches/duo` | this repository |
| Duo overlays, vendor blobs, PostureProcessor, Treble app | `build/default.xml` | `mkostersitz/duoOverlays`, `duoVendor`, `duoPosture`, `duoTreble` (forks of the `Archfx/*` repos) |

`patch.sh` maps each patch folder to a path in the AOSP tree (`platform_frameworks_base` goes to
`frameworks/base`, and so on) and applies the patches with `git am`, in this order:
trebledroid, personal, staging, duo.

## Current target

| Setting | Value |
|---------|-------|
| Android | 16 (`ANDROID_VERSION=16.0`) |
| AOSP tag | `android-16.0.0_r2` (`AOSP_TAG`), which is the tag TrebleDroid's `android-16.0` manifest is based on |
| Release config | `bp2a` (`RELEASE_CONFIG`), so lunch targets are `treble_arm64_bgN-bp2a-userdebug` |
| Variants | `treble_arm64_bgN` (gapps) and `treble_arm64_bvN` (vanilla) |

All of these can be overridden with environment variables when you run `build.sh`.

## Requirements

- Linux x86_64 with about 400 GB of free disk space, 32 GB of RAM or more (64 GB recommended), and several hours of build time.
- The packages listed in `build/Dockerfile`, or use the Docker image.
- Release keys (see below).

## Preparing the build machine

`setup-host.sh` checks the CPU, RAM, disk, OS, packages and network, and with `--install`
installs everything that is missing (it uses `sudo`):

```shell
curl -sfLO https://raw.githubusercontent.com/mkostersitz/duo-de/main-16/setup-host.sh
bash setup-host.sh ~/aosp             # check only
bash setup-host.sh --install ~/aosp   # install packages, repo, git-lfs and fix the sandbox setting
```

## Building

```shell
mkdir aosp && cd aosp
git clone https://github.com/mkostersitz/duo-de treble_aosp   # the scripts expect this folder name
bash treble_aosp/build.sh
```

The first run syncs about 150 GB of sources. If `KEYS_DIR` has no keys yet, it also generates a new
set of release keys (see below).

Useful variables:

| Variable | Default | Meaning |
|----------|---------|---------|
| `BUILD_VARIANT` (or first argument) | both variants | e.g. `treble_arm64_bvN` |
| `JOBS` | all threads (all but 2 above 8 threads) | parallel make jobs |
| `SKIP_SYNC` | unset | `1` skips `repo init/sync`, patching and `installclean`, so it also resumes an interrupted build |
| `KEYS_DIR` | `$PWD/duo-de-keys` | release keys used by `sign.sh`. They are generated when missing |
| `KEYS_SUBJECT` | `/C=US/.../CN=duo-de` | certificate subject for generated keys |
| `OUTPUT_DIR` | `$PWD/duo-de/builds` | where the `.img.xz` files end up |
| `GH_REPO` | `mkostersitz/duo-de` | repository used in OTA URLs and releases |
| `OTA_BRANCH` | `main-16` | branch whose `config/ota.json` devices poll for updates |
| `UPLOAD` | unset | `1` creates a GitHub release with `gh` and pushes the new `ota.json` |

With Docker:

```shell
docker build -f build/Dockerfile --target treblebuild -t duo-de/build .
mkdir -p work && sudo chown 1000:1000 work   # the container runs as the `ubuntu` user (uid 1000)
docker run --rm -it -v $PWD/work:/work/src -w /work/src -e BUILD_ROOT=/work/treble_aosp duo-de/build
```

The AOSP tree, the keys (`work/duo-de-keys`) and the images (`work/duo-de/builds`) stay in `./work`.

## Notes from a first build on Ubuntu 26.04

- Ubuntu 26.04 needed no package renames, `setup-host.sh --install` works as is.
- `setup-host.sh` reports a FAIL below 8 threads. That only warns about build time: a 4-core EPYC built the vanilla
  variant in about 8.5 hours after the sync.
- Run the build in `tmux` (or another detached session) so it survives a closed terminal.
- `OmniJaws` (lockscreen weather) is not built: its Android.bp needs modules that are not in any public repository
  (`ax_compose`, `com.crdroid.apps.resources`), and Soong fails with "depends on undefined module" if it is left in.
  `ParanoidSense` (face unlock) comes from the PixelOS fork for the same reason, see `build/default.xml` and
  `patches/duo/vendor_ponces`.

## Release keys

`sign.sh` re-signs the target-files package with the keys in `KEYS_DIR`. The platform keys are
required (`releasekey`, `platform`, `shared`, `media`, `networkstack`, `sdk_sandbox`, `bluetooth`,
`nfc`). APEX keys are optional: `sign.sh` only re-signs the APEXes that have a key in `KEYS_DIR`.
Generate them with `make-keys.sh` (add `--with-apex` for APEX keys).

Keep the keys private and backed up. Devices only take an OTA update that is signed with the
same keys as the build they already run, so a build signed with new keys needs a clean flash.
The CI workflow reads the keys from a private repository (`vars.KEYS_REPO` and `secrets.KEYS_TOKEN`).

## What changed for Android 16

- `build.sh`: `android-16.0.0_r2`, `bp2a` lunch targets, a staging patch step, and the sync and patch
  steps are enabled again. It also takes the version, keys and repository from variables.
- `build/default.xml`: all TrebleDroid and ponces repositories moved to their `android-16.0` or `16.0`
  branches. `ponces/android_packages_apps_ParanoidSense` is no longer public, and the AOSPA repo
  (`AOSPA/android_packages_apps_ParanoidSense`) lacks the face libraries it needs (`vendor.aospa.biometrics.face.impl`
  and `.required`), so it now uses `PixelOS-AOSP/packages_apps_ParanoidSense` (`sixteen`, pinned to a commit), which ships
  them. Note that these are closed-source Megvii binaries. The private `vendor/ponces-priv` project is not used.
- OmniJaws (lockscreen weather) is left out on purpose: `crdroidandroid/android_packages_services_OmniJaws@16.0` now needs
  modules that are not in any public repo (`ax_compose`, `com.crdroid.apps.resources`). A `patches/duo/vendor_ponces` patch
  removes it from `PRODUCT_PACKAGES`, and the two ponces patches that wire it into SystemUI and Settings are removed.
- `patches/trebledroid`, `patches/personal`, `patches/staging`: copied from `ponces/treble_aosp@android-16.0`.
- `patches/duo/device_phh_treble/0001`: rebased because `sepolicy/service.te` changed upstream.
- `patches/duo/platform_packages_apps_Launcher3/0001`: in Android 16, `LauncherAppState` became a small Kotlin
  Dagger class. The "restart launcher" broadcast receiver (`com.thain.duo.LAUNCHER_RESTART`, sent by
  PostureProcessor) moved to `model/ModelInitializer.kt`. The DUO-DE strings were moved to the new end of `strings.xml`.
- The frameworks_base, Settings and sepolicy DUO-DE patches apply unchanged.
- `sign.sh` also signs APEXes when keys are available. `build/remove.xml` and `build/Dockerfile` (Ubuntu 24.04) were updated from ponces.

The patches were checked with `git am` against TrebleDroid's `android-16.0.0_r2-td` forks of
frameworks/base, packages/apps/Settings and system/sepolicy, TrebleDroid's `device_phh_treble@android-16.0`,
and the Android 16 (25Q2) Launcher3 sources. Only a real build proves that they compile, so the
first build may still need fixes. The most likely places are the Launcher3 patch and the
PostureProcessor app (`duoPosture`), which uses hidden platform APIs.

## Moving to the next Android version (A16 QPR / A17 / ...)

1. **Check that the GSI base exists.** Look for a new branch in
   [TrebleDroid/treble_manifest](https://github.com/TrebleDroid/treble_manifest) (for example `android-17.0`) or new
   `-td` tags in its `replace.xml`, and in [ponces/treble_aosp](https://github.com/ponces/treble_aosp). Without
   TrebleDroid's patches, a new AOSP will generally not boot on the Duo's Android 11/12 vendor and its 4.14/5.4 kernels.
   If ponces stops updating, `sync.sh` regenerates `patches/trebledroid` directly from TrebleDroid.
2. **Bump the knobs** in `build.sh`: `ANDROID_VERSION`, `AOSP_TAG` and `RELEASE_CONFIG`. The release config is the
   prefix of the build ID, for example `BP1A` for 15 QPR2 and `BP2A` for 16.0. You can check it in
   `build/release/release_configs/` of the new tree.
3. **Update `build/default.xml`**: move the `android-X.0` branches (device_phh_treble, vendor_interfaces,
   vendor_ponces, vendor_gapps), the OmniJaws branch and the ParanoidSense codename.
4. **Refresh patches**: copy `patches/trebledroid`, `patches/personal` and `patches/staging` from the new
   upstream branch. The sync workflow does this. Point its `ref:` at the new branch.
5. **Rebase `patches/duo`**: sync the tree, then run `patch.sh` for trebledroid, personal and staging. For each duo
   patch that fails, fix it in place and regenerate the patch with `git format-patch`. Frameworks and Launcher3 are
   the ones that usually break.
6. **Update `sign.sh`**: add new APEXes and APKs from ponces' `sign.sh` for that version.
7. Create the `main-XX` branch for the new OTA channel and set `OTA_BRANCH`.
