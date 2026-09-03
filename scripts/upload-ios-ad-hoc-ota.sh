#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?RUNNER_TEMP is required.}"
: "${IOS_AD_HOC_IPA_PATH:?IOS_AD_HOC_IPA_PATH is required.}"
: "${IOS_BUNDLE_ID:?IOS_BUNDLE_ID is required.}"
: "${IOS_SHORT_VERSION:?IOS_SHORT_VERSION is required.}"
: "${IOS_BUILD_NUMBER:?IOS_BUILD_NUMBER is required.}"
: "${AZURE_OTA_STORAGE_ACCOUNT:?AZURE_OTA_STORAGE_ACCOUNT is required.}"
: "${AZURE_OTA_CONTAINER:?AZURE_OTA_CONTAINER is required.}"
: "${AZURE_OTA_UPLOAD_SAS:?AZURE_OTA_UPLOAD_SAS is required.}"
: "${AZURE_OTA_INSTALL_SAS:?AZURE_OTA_INSTALL_SAS is required.}"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$RUNNER_TEMP/frogcityfeast-ota-manifest.plist"
ipa_headers_path="$RUNNER_TEMP/frogcityfeast-ota-ipa.headers"
manifest_headers_path="$RUNNER_TEMP/frogcityfeast-ota-manifest.headers"
anonymous_headers_path="$RUNNER_TEMP/frogcityfeast-ota-anonymous.headers"
anonymous_body_path="$RUNNER_TEMP/frogcityfeast-ota-anonymous.body"

echo "::add-mask::$AZURE_OTA_UPLOAD_SAS"
echo "::add-mask::$AZURE_OTA_INSTALL_SAS"

if [[ ! "$AZURE_OTA_STORAGE_ACCOUNT" =~ ^[a-z0-9]{3,24}$ ]]; then
  echo "AZURE_OTA_STORAGE_ACCOUNT is invalid." >&2
  exit 1
fi
if (( ${#AZURE_OTA_CONTAINER} < 3 || ${#AZURE_OTA_CONTAINER} > 63 )) ||
  [[ ! "$AZURE_OTA_CONTAINER" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])$ ]] ||
  [[ "$AZURE_OTA_CONTAINER" == *"--"* ]]; then
  echo "AZURE_OTA_CONTAINER is invalid." >&2
  exit 1
fi
if [[ ! "$IOS_BUNDLE_ID" =~ ^[A-Za-z0-9]+([.-][A-Za-z0-9]+)+$ ]]; then
  echo "IOS_BUNDLE_ID is invalid." >&2
  exit 1
fi
if [[ ! "$IOS_SHORT_VERSION" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "IOS_SHORT_VERSION is invalid." >&2
  exit 1
fi
if [[ ! "$IOS_BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
  echo "IOS_BUILD_NUMBER is invalid." >&2
  exit 1
fi

upload_sas="${AZURE_OTA_UPLOAD_SAS#\?}"
install_sas="${AZURE_OTA_INSTALL_SAS#\?}"
if [[ "$upload_sas" =~ [[:space:][:cntrl:]] ]] ||
  [[ "$install_sas" =~ [[:space:][:cntrl:]] ]]; then
  echo "An OTA SAS value contains unsupported whitespace." >&2
  exit 1
fi
upload_sas_fields="&$upload_sas&"
install_sas_fields="&$install_sas&"
if [[ "$upload_sas_fields" != *"&si=workflow-upload&"* ]] ||
  [[ "$upload_sas_fields" != *"&spr=https&"* ]] ||
  [[ "$install_sas_fields" != *"&si=device-install&"* ]] ||
  [[ "$install_sas_fields" != *"&spr=https&"* ]]; then
  echo "The OTA SAS values are not bound to the approved policies." >&2
  exit 1
fi

if [[ ! -f "$IOS_AD_HOC_IPA_PATH" || -L "$IOS_AD_HOC_IPA_PATH" ]]; then
  echo "The validated Ad Hoc IPA path is not a regular file." >&2
  exit 1
fi
ipa_directory="$(
  cd "$(dirname "$IOS_AD_HOC_IPA_PATH")"
  pwd -P
)"
expected_directory="$(
  cd "$RUNNER_TEMP/ios-ad-hoc-export"
  pwd -P
)"
if [[ "$ipa_directory" != "$expected_directory" ]] ||
  [[ "${IOS_AD_HOC_IPA_PATH##*.}" != "ipa" ]]; then
  echo "The validated Ad Hoc IPA is outside the constrained export path." >&2
  exit 1
fi

rm -f -- \
  "$manifest_path" \
  "$ipa_headers_path" \
  "$manifest_headers_path" \
  "$anonymous_headers_path" \
  "$anonymous_body_path"

blob_prefix="frogcityfeast/$IOS_SHORT_VERSION/$IOS_BUILD_NUMBER"
ipa_blob="$blob_prefix/FrogCityFeast.ipa"
manifest_blob="$blob_prefix/manifest.plist"
container_url="https://$AZURE_OTA_STORAGE_ACCOUNT.blob.core.windows.net/$AZURE_OTA_CONTAINER"
ipa_install_url="$container_url/$ipa_blob?$install_sas"
manifest_install_url="$container_url/$manifest_blob?$install_sas"
ipa_upload_url="$container_url/$ipa_blob?$upload_sas"
manifest_upload_url="$container_url/$manifest_blob?$upload_sas"
rollback_urls=()
rollback_read_urls=()
rollback_md5_values=()
rollback_kinds=()
rollback_url_count=0
rollback_enabled=1

rollback_incomplete_upload() {
  local status=$?
  local index
  local rollback_failed=0
  local remote_build
  local remote_kind
  local remote_md5
  local response_code
  local rollback_url

  trap - EXIT
  if (( status != 0 && rollback_enabled != 0 && rollback_url_count > 0 )); then
    for (( index = 0; index < rollback_url_count; index++ )); do
      rollback_url="${rollback_urls[$index]}"
      if ! response_code="$(
        curl \
          --silent \
          --show-error \
          --head \
          --dump-header "$RUNNER_TEMP/frogcityfeast-ota-rollback.headers" \
          --output /dev/null \
          --write-out "%{http_code}" \
          "${rollback_read_urls[$index]}"
      )"; then
        rollback_failed=1
        continue
      fi
      if [[ "$response_code" == "404" ]]; then
        continue
      fi
      if [[ "$response_code" != "200" ]]; then
        rollback_failed=1
        continue
      fi
      remote_md5="$(
        tr -d '\r' < "$RUNNER_TEMP/frogcityfeast-ota-rollback.headers" |
          awk -F': ' 'tolower($1) == "content-md5" { print $2 }'
      )"
      remote_build="$(
        tr -d '\r' < "$RUNNER_TEMP/frogcityfeast-ota-rollback.headers" |
          awk -F': ' 'tolower($1) == "x-ms-meta-frogcityfeast_build" { print $2 }'
      )"
      remote_kind="$(
        tr -d '\r' < "$RUNNER_TEMP/frogcityfeast-ota-rollback.headers" |
          awk -F': ' 'tolower($1) == "x-ms-meta-frogcityfeast_kind" { print $2 }'
      )"
      if [[ "$remote_md5" != "${rollback_md5_values[$index]}" ]] ||
        [[ "$remote_build" != "$IOS_BUILD_NUMBER" ]] ||
        [[ "$remote_kind" != "${rollback_kinds[$index]}" ]]; then
        rollback_failed=1
        continue
      fi
      if ! curl \
        --fail \
        --silent \
        --show-error \
        --request DELETE \
        --header "x-ms-version: 2023-11-03" \
        "$rollback_url" \
        >/dev/null; then
        rollback_failed=1
      fi
    done
    if (( rollback_failed != 0 )); then
      echo "Private OTA rollback was incomplete." >&2
      exit 1
    fi
    echo "Incomplete private OTA blobs were removed." >&2
  fi
  exit "$status"
}

trap rollback_incomplete_upload EXIT

require_blob_absent() {
  local read_url="$1"
  local response_code

  response_code="$(
    curl \
      --silent \
      --show-error \
      --head \
      --output /dev/null \
      --write-out "%{http_code}" \
      "$read_url"
  )"
  if [[ "$response_code" == "404" ]]; then
    return
  fi
  if [[ "$response_code" == "200" ]]; then
    echo "The private OTA destination already exists." >&2
  else
    echo "The private OTA destination could not be preflighted." >&2
  fi
  exit 1
}

IOS_OTA_IPA_URL="$ipa_install_url" \
  python3 "$repo_root/scripts/create-ios-ota-manifest.py" \
  --output "$manifest_path" \
  --bundle-id "$IOS_BUNDLE_ID" \
  --bundle-version "$IOS_BUILD_NUMBER" \
  --title "Frog City Feast"

file_md5() {
  openssl dgst -md5 -binary "$1" | openssl base64 -A
}

upload_blob() {
  local source_path="$1"
  local destination_url="$2"
  local content_type="$3"
  local content_md5="$4"
  local content_kind="$5"

  curl \
    --fail-with-body \
    --silent \
    --show-error \
    --request PUT \
    --header "x-ms-version: 2023-11-03" \
    --header "x-ms-blob-type: BlockBlob" \
    --header "Content-Type: $content_type" \
    --header "Content-MD5: $content_md5" \
    --header "x-ms-meta-frogcityfeast_build: $IOS_BUILD_NUMBER" \
    --header "x-ms-meta-frogcityfeast_kind: $content_kind" \
    --header "If-None-Match: *" \
    --data-binary "@$source_path" \
    "$destination_url" \
    >/dev/null
}

verify_blob() {
  local source_path="$1"
  local source_md5="$2"
  local read_url="$3"
  local headers_path="$4"
  local expected_kind="$5"
  local remote_build
  local remote_kind
  local remote_md5

  curl \
    --fail \
    --silent \
    --show-error \
    --head \
    --dump-header "$headers_path" \
    --output /dev/null \
    "$read_url"
  remote_md5="$(
    tr -d '\r' < "$headers_path" |
      awk -F': ' 'tolower($1) == "content-md5" { print $2 }'
  )"
  remote_build="$(
    tr -d '\r' < "$headers_path" |
      awk -F': ' 'tolower($1) == "x-ms-meta-frogcityfeast_build" { print $2 }'
  )"
  remote_kind="$(
    tr -d '\r' < "$headers_path" |
      awk -F': ' 'tolower($1) == "x-ms-meta-frogcityfeast_kind" { print $2 }'
  )"
  if [[ "$remote_md5" != "$source_md5" ]] ||
    [[ "$remote_build" != "$IOS_BUILD_NUMBER" ]] ||
    [[ "$remote_kind" != "$expected_kind" ]]; then
    echo "A private OTA blob failed its upload integrity check." >&2
    exit 1
  fi
  if [[ ! -s "$source_path" ]]; then
    echo "A private OTA source file is empty." >&2
    exit 1
  fi
}

verify_anonymous_access_denied() {
  local anonymous_url="$1"
  local error_code
  local response_code

  rm -f -- "$anonymous_headers_path" "$anonymous_body_path"
  response_code="$(
    curl \
      --silent \
      --show-error \
      --request GET \
      --range "0-0" \
      --dump-header "$anonymous_headers_path" \
      --output "$anonymous_body_path" \
      --write-out "%{http_code}" \
      "$anonymous_url"
  )"
  case "$response_code" in
    401|403|404)
      return
      ;;
    409)
      error_code="$(
        tr -d '\r' < "$anonymous_headers_path" |
          awk -F': ' 'tolower($1) == "x-ms-error-code" { print $2 }'
      )"
      if [[ -z "$error_code" ]]; then
        error_code="$(
          tr -d '\r\n' < "$anonymous_body_path" |
            sed -n 's:.*<Code>\([^<]*\)</Code>.*:\1:p'
        )"
      fi
      if [[ "$error_code" == "PublicAccessNotPermitted" ]]; then
        return
      fi
      ;;
    *)
      ;;
  esac
  echo "Anonymous access to a private OTA blob was not denied as expected." >&2
  exit 1
}

ipa_md5="$(file_md5 "$IOS_AD_HOC_IPA_PATH")"
manifest_md5="$(file_md5 "$manifest_path")"

require_blob_absent "$ipa_install_url"
rollback_urls+=("$ipa_upload_url")
rollback_read_urls+=("$ipa_install_url")
rollback_md5_values+=("$ipa_md5")
rollback_kinds+=("ipa")
rollback_url_count=$((rollback_url_count + 1))
upload_blob \
  "$IOS_AD_HOC_IPA_PATH" \
  "$ipa_upload_url" \
  "application/octet-stream" \
  "$ipa_md5" \
  "ipa"
verify_blob \
  "$IOS_AD_HOC_IPA_PATH" \
  "$ipa_md5" \
  "$ipa_install_url" \
  "$ipa_headers_path" \
  "ipa"

require_blob_absent "$manifest_install_url"
rollback_urls+=("$manifest_upload_url")
rollback_read_urls+=("$manifest_install_url")
rollback_md5_values+=("$manifest_md5")
rollback_kinds+=("manifest")
rollback_url_count=$((rollback_url_count + 1))
upload_blob \
  "$manifest_path" \
  "$manifest_upload_url" \
  "text/xml" \
  "$manifest_md5" \
  "manifest"
verify_blob \
  "$manifest_path" \
  "$manifest_md5" \
  "$manifest_install_url" \
  "$manifest_headers_path" \
  "manifest"

verify_anonymous_access_denied "$container_url/$ipa_blob"
verify_anonymous_access_denied "$container_url/$manifest_blob"

rollback_enabled=0
echo "Private OTA package and manifest uploaded for build $IOS_BUILD_NUMBER."
echo "The signed installation URL was not printed or committed."
