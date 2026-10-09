$(call inherit-product, vendor/ponces/config/common.mk)

# @GH_REPO@ and @OTA_BRANCH@ are filled in by build.sh
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.system.ota.json_url=https://raw.githubusercontent.com/@GH_REPO@/@OTA_BRANCH@/config/ota.json

# Authorize the maintainer adb key in userdebug builds (needs no on-device prompt).
# The key lives on the build host only; the line is a no-op when the file is absent.
ifneq ($(wildcard /aosp/duo-de-keys/adb_keys.pub),)
PRODUCT_ADB_KEYS := duo-de-keys/adb_keys.pub
endif

# Surface Duo 2 has one physical SIM slot and one eSIM slot, which Android counts as two
# slots. The default is 1, so UiccController sizes mUiccSlots[1] and crashes with an
# ArrayIndexOutOfBounds as soon as the modem reports the eSIM on physical slot 1.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.telephony.sim_slots.count=2

