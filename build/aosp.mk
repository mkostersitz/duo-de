$(call inherit-product, vendor/ponces/config/common.mk)

# @GH_REPO@ and @OTA_BRANCH@ are filled in by build.sh
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.system.ota.json_url=https://raw.githubusercontent.com/@GH_REPO@/@OTA_BRANCH@/config/ota.json
