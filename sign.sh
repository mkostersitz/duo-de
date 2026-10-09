#!/bin/bash

# Signs the target-files package with release keys.
#
# KEYSDIR must contain at least the platform keys (releasekey, platform, shared,
# media, networkstack, ...) generated with development/tools/make_key.
# APEX keys (<apex>.x509.pem/<apex>.pk8 container key + <apex>.pem payload key)
# are optional: APEXes without a key in KEYSDIR keep their default signature.
# See BUILDING.md for how to generate them.

KEYSDIR="$1"
OUTFILE="$2"

if [ -z "$KEYSDIR" ]; then
    KEYSDIR="$HOME/.android-certs"
fi

if [ -z "$OUTFILE" ]; then
    OUTFILE="signed-target_files.zip"
fi

APEXES=(
    com.android.adbd
    com.android.adservices
    com.android.adservices.api
    com.android.appsearch
    com.android.appsearch.apk
    com.android.art
    com.android.bluetooth
    com.android.btservices
    com.android.cellbroadcast
    com.android.compos
    com.android.configinfrastructure
    com.android.connectivity.resources
    com.android.conscrypt
    com.android.devicelock
    com.android.extservices
    com.android.graphics.pdf
    com.android.hardware.authsecret
    com.android.hardware.biometrics.face.virtual
    com.android.hardware.biometrics.fingerprint.virtual
    com.android.hardware.boot
    com.android.hardware.cas
    com.android.hardware.neuralnetworks
    com.android.hardware.rebootescrow
    com.android.hardware.wifi
    com.android.healthfitness
    com.android.hotspot2.osulogin
    com.android.i18n
    com.android.ipsec
    com.android.media
    com.android.media.swcodec
    com.android.mediaprovider
    com.android.nearby.halfsheet
    com.android.networkstack.tethering
    com.android.neuralnetworks
    com.android.nfcservices
    com.android.ondevicepersonalization
    com.android.os.statsd
    com.android.permission
    com.android.profiling
    com.android.resolv
    com.android.rkpd
    com.android.runtime
    com.android.safetycenter.resources
    com.android.scheduling
    com.android.sdkext
    com.android.support.apexer
    com.android.telephony
    com.android.telephonymodules
    com.android.tethering
    com.android.tzdata
    com.android.uwb
    com.android.uwb.resources
    com.android.virt
    com.android.vndk.current
    com.android.vndk.current.on_vendor
    com.android.wifi
    com.android.wifi.dialog
    com.android.wifi.resources
    com.google.pixel.camera.hal
    com.google.pixel.vibrator.hal
    com.qorvo.uwb
)

EXTRA_ARGS=()
for apex in "${APEXES[@]}"; do
    if [ -f "$KEYSDIR/$apex.pem" ] && [ -f "$KEYSDIR/$apex.pk8" ]; then
        EXTRA_ARGS+=(--extra_apks "$apex.apex=$KEYSDIR/$apex")
        EXTRA_ARGS+=(--extra_apex_payload_key "$apex.apex=$KEYSDIR/$apex.pem")
    fi
done

sign_target_files_apks -o -d $KEYSDIR \
    --extra_apks AdServicesApk.apk=$KEYSDIR/releasekey \
    --extra_apks FederatedCompute.apk=$KEYSDIR/releasekey \
    --extra_apks HalfSheetUX.apk=$KEYSDIR/releasekey \
    --extra_apks HealthConnectBackupRestore.apk=$KEYSDIR/releasekey \
    --extra_apks HealthConnectController.apk=$KEYSDIR/releasekey \
    --extra_apks OsuLogin.apk=$KEYSDIR/releasekey \
    --extra_apks SafetyCenterResources.apk=$KEYSDIR/releasekey \
    --extra_apks ServiceConnectivityResources.apk=$KEYSDIR/releasekey \
    --extra_apks ServiceUwbResources.apk=$KEYSDIR/releasekey \
    --extra_apks ServiceWifiResources.apk=$KEYSDIR/releasekey \
    --extra_apks WifiDialog.apk=$KEYSDIR/releasekey \
    "${EXTRA_ARGS[@]}" \
    $OUT/obj/PACKAGING/target_files_intermediates/*-target_files*.zip \
    $OUTFILE
