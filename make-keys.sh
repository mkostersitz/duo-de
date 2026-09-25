#!/bin/bash

# Generates the release keys used by sign.sh.
#
# Run it from the root of a synced AOSP tree (it needs development/tools/make_key):
#   bash treble_aosp/make-keys.sh ../duo-de-keys "/C=US/ST=WA/L=Seattle/O=duo-de/OU=duo-de/CN=duo-de"
#
# Pass --with-apex as third argument to also generate APEX container/payload keys.
# Keep the output directory PRIVATE and BACKED UP: OTA updates only install on top of
# builds signed with the same keys.

set -e

KEYSDIR="$1"
SUBJECT="$2"
WITH_APEX="$3"

if [ -z "$KEYSDIR" ] || [ -z "$SUBJECT" ]; then
    echo "usage: $0 <keys-dir> <subject> [--with-apex]"
    exit 1
fi

if [ ! -x development/tools/make_key ]; then
    echo "development/tools/make_key not found, run this from the root of the AOSP tree"
    exit 1
fi

mkdir -p "$KEYSDIR"

makeKey() {
    # make_key prompts for a password, an empty one keeps the key unencrypted
    [ -f "$KEYSDIR/$1.pk8" ] && return
    echo | development/tools/make_key "$KEYSDIR/$1" "$SUBJECT" || true
}

for key in releasekey platform shared media networkstack sdk_sandbox bluetooth nfc; do
    makeKey $key
done

if [ "$WITH_APEX" == "--with-apex" ]; then
    apexes=$(sed -n '/^APEXES=(/,/^)/p' "$(dirname "$(readlink -f "$0")")/sign.sh" | grep -v '[()]')
    for apex in $apexes; do
        makeKey $apex
        [ -f "$KEYSDIR/$apex.pem" ] || openssl genrsa -out "$KEYSDIR/$apex.pem" 4096
    done
fi

echo "--> Keys generated in $KEYSDIR"
