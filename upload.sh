#!/bin/bash

echo
echo "--------------------------------------"
echo "        DUO-DE AOSP Uploadbot         "
echo "                  by                  "
echo "                ArchFX                "
echo "--------------------------------------"
echo

set -e

[ -z "$GH_REPO" ] && GH_REPO="mkostersitz/duo-de"
[ -z "$OTA_BRANCH" ] && OTA_BRANCH="main-16"
[ -z "$ANDROID_VERSION" ] && ANDROID_VERSION="16.0"
[ -z "$BUILD_ROOT" ] && BUILD_ROOT="$PWD/treble_aosp"
[ -z "$OUTPUT_DIR" ] && OUTPUT_DIR="$PWD/duo-de/builds"
TAG="$(date +v%Y.%m.%d)"

SKIPOTA=false
if [ "$1" == "--skip-ota" ]; then
    SKIPOTA=true
fi

createRelease() {
    echo "--> Creating release $TAG"
    gh release create "$TAG" --repo "$GH_REPO" --title "$TAG" --draft --notes "Android $ANDROID_VERSION build $TAG"
    echo
}

uploadAssets() {
    buildDate="$(date +%Y%m%d)"
    find $OUTPUT_DIR/ -name "aosp-*-${ANDROID_VERSION}-$buildDate.img.xz" | while read file; do
        echo "--> Uploading $(basename $file)"
        gh release upload "$TAG" "$file" --repo "$GH_REPO"
        echo
    done
}

updateOta() {
    cd $BUILD_ROOT
    echo "--> Updating OTA file"
    git add config/ota.json
    git commit -m "build: Bump OTA to $TAG"
    git push origin HEAD:$OTA_BRANCH
    echo
    cd - >/dev/null
}

START=$(date +%s)

createRelease
uploadAssets
[ "$SKIPOTA" = false ] && updateOta

END=$(date +%s)
ELAPSEDM=$(($(($END-$START))/60))
ELAPSEDS=$(($(($END-$START))-$ELAPSEDM*60))

echo "--> Uploadbot completed in $ELAPSEDM minutes and $ELAPSEDS seconds"
echo
