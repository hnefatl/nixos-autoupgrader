#!/usr/bin/env bash

# shellcheck source=/dev/null
source shflags.sh

function die {
    echo "$@"
    exit 1
}

DEFINE_string os_flake_dir "" "Directory containing NixOS flake to update"
DEFINE_string home_flake_dir "" "Directory containing home-manager flake to update"
DEFINE_string home_user "" "Which user to run the home-manager upgrade as"

DEFINE_string update_inputs "" "Space-separated list of flake inputs to update. Defaults to all inputs."
DEFINE_string from_email "" "Which address to send a result email from."
DEFINE_string to_email "" "Which address to send a result email to."

FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

[[ -z "${FLAGS_home_flake_dir}"  ]] && [[ -z "${FLAGS_os_flake_dir}" ]] && die "One of --home_flake_dir or --os_flake_dir must be set"
[[ -n "${FLAGS_home_flake_dir}"  ]] && [[ -z "${FLAGS_home_user}" ]] && die "--home_user must be set"
[[ -z "${FLAGS_from_email}" ]] && die "Missing flag --from_email"
[[ -z "${FLAGS_to_email}" ]] && die "Missing flag --to_email"


function main {
    if [[ -n "${FLAGS_os_flake_dir}" ]] ; then
        cd "${FLAGS_os_flake_dir}"
        BUILD_COMMAND=(nh os build --bypass-root-check .)
        SWITCH_COMMAND=(nh os switch --bypass-root-check .)
        do_upgrade "NixOS"
    fi
    if [[ -n "${FLAGS_home_flake_dir}" ]] ; then
        cd "${FLAGS_home_flake_dir}"
        BUILD_COMMAND=(/run/wrappers/bin/sudo -u "${FLAGS_home_user}" nh home build .)
        SWITCH_COMMAND=(/run/wrappers/bin/sudo -u "${FLAGS_home_user}" nh home switch .)
        do_upgrade "home-manager"
    fi
}

function do_upgrade {
    description="$1"

    log "Updating ${description} flake inputs '${FLAGS_update_inputs}' in $(pwd)..."
    echo "${FLAGS_update_inputs}" | xargs nix flake update 

    log "Upgrading ${description}..."
    output_file=$(mktemp)
    
    log "Building new ${description} generation (writing stdout to ${output_file})..."
    "${BUILD_COMMAND[@]}" | tee "${output_file}"

    if ! system_diff "${output_file}" ; then
        log "No diff."
    else
        # Try to do the switch, don't exit if fails.
        log "Switching to new ${description} generation..."
        "${SWITCH_COMMAND[@]}" || :

        send_result $? "${description}" "${output_file}"
    fi
    # Clean up the output, don't exit if it fails.
    rm "${output_file}" || :
}

function log {
    echo "[nix autoupgrader]" "$@"
}

function system_diff {
    # If the file only has the <<</>>> markers or empty lines then there's no diff
    grep -qEv "(<<<)|(>>>)|(^$)" "$1"
}

function send_result {
    status="$1"
    upgrade_type="$2"
    output_file="$3"

    if [[ "${status}" -eq 0 ]] ; then
        subject="$(hostname): ${upgrade_type} upgrade succeeded"
    else
        subject="$(hostname): ${upgrade_type} upgrade failed with code ${status}"
    fi

    log "Sending status email to ${FLAGS_to_email}..."
    (
        echo "From: ${FLAGS_from_email}";
        echo "To: ${FLAGS_to_email}";
        echo "Subject: ${subject}";
        echo "Content-Type: text/html";
        echo "MIME-Version: 1.0";
        echo "";
        aha -f "${output_file}"
    ) | sendmail -t
}

main
