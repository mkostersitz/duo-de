#!/bin/bash

echo
echo "--------------------------------------"
echo "        DUO-DE AOSP 16.0 Buildbot     "
echo "   based on treble_aosp by ponces     "
echo "--------------------------------------"
echo

set -e

# ---------------------------------------------------------------------------
# Version knobs. Bumping to a newer Android release is mostly a matter of
# changing these values (plus refreshing patches/ and build/default.xml).
# ---------------------------------------------------------------------------
[ -z "$ANDROID_VERSION" ] && ANDROID_VERSION="16.0"
# AOSP tag to sync. Keep it in line with TrebleDroid's treble_manifest
# (https://github.com/TrebleDroid/treble_manifest/blob/android-16.0/replace.xml)
[ -z "$AOSP_TAG" ] && AOSP_TAG="android-16.0.0_r2"
# Release config passed to lunch (A15 QPR2 = bp1a, A16 = bp2a). For a new tag, see
# build/release/release_configs/ in the synced tree
[ -z "$RELEASE_CONFIG" ] && RELEASE_CONFIG="bp2a"
# GitHub repository hosting the releases and the OTA json
[ -z "$GH_REPO" ] && GH_REPO="mkostersitz/duo-de"
# Branch of $GH_REPO whose config/ota.json devices poll for updates
[ -z "$OTA_BRANCH" ] && OTA_BRANCH="main-16"

export BUILD_NUMBER="$(date +%y%m%d)"

[ -z "$BUILD_ROOT" ] && BUILD_ROOT="$PWD/treble_aosp"
[ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="$PWD/duo-de/builds"
[ -z "$KEYS_DIR" ] && KEYS_DIR="$PWD/duo-de-keys"
[ -z "$BUILD_VARIANT" ] && BUILD_VARIANT="$1"

initRepos() {
    echo "--> Initializing workspace"
    repo init -u https://android.googlesource.com/platform/manifest -b "$AOSP_TAG" --git-lfs
    echo

    echo "--> Preparing local manifest"
    mkdir -p .repo/local_manifests
    cp $BUILD_ROOT/build/default.xml .repo/local_manifests/default.xml
    cp $BUILD_ROOT/build/remove.xml .repo/local_manifests/remove.xml
    echo
}

syncRepos() {
    echo "--> Syncing repos"
    # Throw away previously applied patches so they can be re-applied cleanly
    repo forall -c 'git am --abort 2>/dev/null; git checkout -f -q; git clean -fdq' || true
    repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --ignore=2) || repo sync -c --force-sync --no-clone-bundle --no-tags -j$(nproc --ignore=2)
    echo
}

applyPatches() {
    echo "--> Applying TrebleDroid patches"
    bash $BUILD_ROOT/patch.sh $BUILD_ROOT trebledroid
    echo

    echo "--> Applying personal patches"
    bash $BUILD_ROOT/patch.sh $BUILD_ROOT personal
    echo

    echo "--> Applying staging patches"
    bash $BUILD_ROOT/patch.sh $BUILD_ROOT staging
    echo

    echo "--> Applying DUO-DE patches"
    bash $BUILD_ROOT/patch.sh $BUILD_ROOT duo
    echo

    echo "--> Generating makefiles"
    cd device/phh/treble
    sed "s#@GH_REPO@#$GH_REPO#g; s#@OTA_BRANCH@#$OTA_BRANCH#g" $BUILD_ROOT/build/aosp.mk > aosp.mk
    bash generate.sh aosp
    cd ../../..
    echo
}

setupEnv() {
    echo "--> Setting up build environment"
    mkdir -p $OUTPUT_DIR
    if [ ! -f "$KEYS_DIR/releasekey.pk8" ]; then
        echo "--> No release keys in $KEYS_DIR, generating new ones (keep them safe!)"
        bash $BUILD_ROOT/make-keys.sh "$KEYS_DIR" "${KEYS_SUBJECT:-/C=US/ST=WA/L=Redmond/O=duo-de/OU=duo-de/CN=duo-de}"
    fi
    source build/envsetup.sh
    source build/core/build_id.mk
    echo
}

buildTrebleApp() {
    echo "--> Building treble_app"
    cd treble_app
    bash build.sh release
    cp TrebleApp.apk ../vendor/hardware_overlay/TrebleApp/app.apk
    cd ..
    echo
}

buildVariant() {
    echo "--> Building $1"
    lunch "$1"-"$RELEASE_CONFIG"-userdebug
    make -j$(nproc --ignore=2) installclean
    make -j$(nproc --ignore=2) systemimage
    make -j$(nproc --ignore=2) target-files-package otatools
    bash $BUILD_ROOT/sign.sh "$KEYS_DIR" $OUT/signed-target_files.zip
    unzip -joq $OUT/signed-target_files.zip IMAGES/system.img -d $OUT
    mv $OUT/system.img $OUTPUT_DIR/system-"$1".img
    echo "image copied to $OUTPUT_DIR/system-$1.img"
    echo
}

buildVariants() {
    buildVariant treble_arm64_bgN
    buildVariant treble_arm64_bvN
}

generatePackages() {
    echo "--> Generating packages"
    buildDate="$(date +%Y%m%d)"
    find $OUTPUT_DIR/ -name "system-treble_*.img" | while read file; do
        filename="$(basename $file)"
        [[ "$filename" == *"_bvN"* ]] && variant="vanilla" || variant="gapps"
        name="aosp-arm64-ab-${variant}-${ANDROID_VERSION}-$buildDate"
        xz -cv "$file" -T0 > $OUTPUT_DIR/"$name".img.xz
    done
    rm -rf $OUTPUT_DIR/system-*.img
    echo
}

generateOta() {
    echo "--> Generating OTA file"
    version="$(date +v%Y.%m.%d)"
    buildDate="$(date +%Y%m%d)"
    timestamp="$START"
    json="{\"version\": \"$version\",\"date\": \"$timestamp\",\"variants\": ["
    find $OUTPUT_DIR/ -name "aosp-*-${ANDROID_VERSION}-$buildDate.img.xz" | sort | {
        while read file; do
            filename="$(basename $file)"
            [[ "$filename" == *"-vanilla"* ]] && variant="v" || variant="g"
            name="treble_arm64_b${variant}N"
            size=$(wc -c $file | awk '{print $1}')
            url="https://github.com/$GH_REPO/releases/download/$version/$filename"
            json="${json} {\"name\": \"$name\",\"size\": \"$size\",\"url\": \"$url\"},"
        done
        json="${json%?}]}"
        echo "$json" | jq . > $BUILD_ROOT/config/ota.json
    }
    echo
}

uploadOTA() {
    GH_REPO="$GH_REPO" OTA_BRANCH="$OTA_BRANCH" ANDROID_VERSION="$ANDROID_VERSION" OUTPUT_DIR="$OUTPUT_DIR" \
        bash $BUILD_ROOT/upload.sh
}

START=$(date +%s)

# Set SKIP_SYNC=1 to rebuild an already synced and patched tree
if [ -z "$SKIP_SYNC" ]; then
    initRepos
    syncRepos
    applyPatches
fi
setupEnv
buildTrebleApp
[ ! -z "$BUILD_VARIANT" ] && buildVariant "$BUILD_VARIANT" || buildVariants
generatePackages
generateOta
# Set UPLOAD=1 to publish a GitHub release (needs an authenticated `gh`)
[ ! -z "$UPLOAD" ] && uploadOTA

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Buildbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
