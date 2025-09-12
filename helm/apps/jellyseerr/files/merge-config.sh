#!/bin/sh

set -eof pipefail


TMP_SETTINGS="/tmp/settings.json"
CONFIGMAP_SETTINGS="/shared/config/settings.json"
PVC_SETTINGS="/app/config/settings.json"


jq_update() {
  jq_query=$1
  tmp=$(mktemp)
  jq -s "$jq_query" $TMP_SETTINGS "$PVC_SETTINGS" > "$tmp" && mv "$tmp" "$TMP_SETTINGS"
}

replace_attribute() {
  jq_attribute_name=$1
  jq_update ".[0].${jq_attribute_name} = .[1].${jq_attribute_name} | select(.)[0]"
}

if [ ! -r "$PVC_SETTINGS" ]; then
  # PVC is empty so we just copy the settings from the configmap
  cp -f "$CONFIGMAP_SETTINGS" "$PVC_SETTINGS"
else
  echo "Merging multiple options from existing configuration"
  # Do jq operations one by one to be readable
  # Replace jellyfin object from pvc config and return whole config
  jq -s '.[0].jellyfin = .[1].jellyfin | select(.)[0]' "$CONFIGMAP_SETTINGS" "$PVC_SETTINGS" > "$TMP_SETTINGS"

  # Set media server type from setup phase
  replace_attribute 'main.mediaServerType'

  # Set initialized status to the one in pvc
  replace_attribute 'public.initialized'

  # Replace the pvc config by the final temp file
  cp -f /tmp/settings.json "$PVC_SETTINGS"
fi