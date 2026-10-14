#!/usr/bin/env bash

# check if unzip is installed, if not exit with an error
if ! command -v unzip &> /dev/null; then
    printf 'Error: unzip is not installed\n' >&2
    exit 1
fi

verbose=false
version=""
for argument in "$@"; do
    case "$argument" in
        -v|--verbose)
            verbose=true
            ;;
        -*)
            printf 'Error: unknown option: %s\n' "$argument" >&2
            exit 1
            ;;
        *)
            if [[ -n "$version" ]]; then
                printf 'Usage: %s [-v|--verbose] <version>\n' "$0" >&2
                exit 1
            fi
            version="$argument"
            ;;
    esac
done

if [[ -z "$version" ]]; then
    printf 'Usage: %s [-v|--verbose] <version>\n' "$0" >&2
    exit 1
fi

if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(beta|alpha|rc)\.(0|[1-9][0-9]{0,2}))?$ ]]; then
	printf 'Error: invalid version: %s\n' "$version" >&2
	exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$script_dir/env" ]]; then
    printf 'Error: env file not found: %s/env\n' "$script_dir" >&2
    exit 1
fi
source <(sed 's/\r$//' "$script_dir/env")

if [[ -z "${payment_plugin_destination:-}" || -z "${comms_plugin_destination:-}" || -z "${import_plugin_destination:-}" ]]; then
    printf 'Error: one or more plugin destinations are not set in %s/env\n' "$script_dir" >&2
    exit 1
fi
if (( ${#payment_plugins[@]} == 0 || ${#comms_plugins[@]} == 0 || ${#import_plugins[@]} == 0 )); then
    printf 'Error: one or more plugin arrays are empty in %s/env\n' "$script_dir" >&2
    exit 1
fi
for destination in "$payment_plugin_destination" "$comms_plugin_destination" "$import_plugin_destination"; do
    if [[ ! -d "$destination" ]]; then
        printf 'Error: plugin destination is not an existing directory: %s\n' "$destination" >&2
        exit 1
    fi
done

route=""
major="${version%%.*}"
minor="${version#*.}"
minor="${minor%%.*}"

if [[ "$version" != *-* ]]; then
    route="dc-web"
elif (( major < 2 || ( major == 2 && minor < 5 ) )); then
	route="dc-web-beta"
else
	route="dc-web-alpha"
fi

plugin_route="https://dssl-release.fra1.cdn.digitaloceanspaces.com/$route/$version/plugins"

staging_dir="$script_dir/staging"

failed_plugins=()

process_plugin_group() {
    local category="$1"
    local destination="$2"
    shift 2

    local plugin archive_url plugin_staging archive_path curl_status
    local -a curl_args

    for plugin in "$@"; do
        archive_url="$plugin_route/$category/$plugin.zip"

        if ! plugin_staging="$(mktemp -d "$staging_dir/$plugin.XXXXXX")"; then
            printf 'Failed to prepare staging for %s/%s; continuing with next plugin\n' "$category" "$plugin" >&2
            failed_plugins+=("$category/$plugin")
            continue
        fi

        archive_path="$plugin_staging/$plugin.zip"
        curl_args=(--fail --show-error -o "$archive_path")
        if [[ "$verbose" == true ]]; then
            curl_args+=(--verbose)
            curl "${curl_args[@]}" "$archive_url"
        else
            curl "${curl_args[@]}" "$archive_url" >/dev/null 2>&1
        fi
        curl_status=$?
        if (( curl_status != 0 )); then
            printf 'Failed to download %s/%s; continuing with next plugin\n' "$category" "$plugin" >&2
            rm -rf "$plugin_staging"
            failed_plugins+=("$category/$plugin")
            continue
        fi

        if ! unzip -oqq "$archive_path" -d "$plugin_staging"; then
            printf 'Failed to extract %s/%s; continuing with next plugin\n' "$category" "$plugin" >&2
            rm -rf "$plugin_staging"
            failed_plugins+=("$category/$plugin")
            continue
        fi

        rm -f "$archive_path"
        if ! mv -f "$plugin_staging/"* "$destination"; then
            printf 'Failed to move files for %s/%s; continuing with next plugin\n' "$category" "$plugin" >&2
            failed_plugins+=("$category/$plugin")
        else
            printf '%s complete....\n' "$plugin"
        fi

        rm -rf "$plugin_staging"
    done
}

process_plugin_group "PaymentGateways" "$payment_plugin_destination" "${payment_plugins[@]}"
process_plugin_group "Comms" "$comms_plugin_destination" "${comms_plugins[@]}"
process_plugin_group "Import" "$import_plugin_destination" "${import_plugins[@]}"

if (( ${#failed_plugins[@]} > 0 )); then
    printf 'Failed plugins: %s\n' "${failed_plugins[*]}" >&2
    exit 1
fi
