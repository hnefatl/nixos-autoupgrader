#!/usr/bin/env bash

# shellcheck source=/dev/null
source shflags.sh

function die {
    echo "$@"
    exit 1
}

DEFINE_string upgrade_home_flake "" "Directory containing home-manager flake to update"
DEFINE_string upgrade_os_flake "" "Directory containing home-manager flake to update"

DEFINE_string update_inputs "" "Space-separated list of flake inputs to update. Defaults to all inputs."
DEFINE_string from_email "" "Which address to send a result email from."
DEFINE_string to_email "" "Which address to send a result email to."

FLAGS "$@" || exit $?
eval set -- "${FLAGS_ARGV}"

[[ -z "${FLAGS_upgrade_home_flake}"  ]] && [[ -z "${FLAGS_upgrade_os_flake}" ]] && die "One of --upgrade_home_flake or --upgrade_os_flake must be set"
[[ -z "${FLAGS_from_email}" ]] && die "Missing flag --from_email"
[[ -z "${FLAGS_to_email}" ]] && die "Missing flag --to_email"


function main {
    if [[ -n "${FLAGS_upgrade_home_flake}" ]] ; then
        cd "${FLAGS_upgrade_home_flake}"
        do_upgrade home "home-manager"
    fi
    if [[ -n "${FLAGS_upgrade_os_flake}" ]] ; then
        cd "${FLAGS_upgrade_os_flake}"
        do_upgrade os "NixOS"
    fi
}

function do_upgrade {
    nh_subcommand="$1"
    description="$2"

    log "Updating ${description} flake in $(pwd)..."
    echo "${FLAGS_update_inputs}" | xargs nix flake update 

    log "Upgrading ${description}..."
    output_file=$(mktemp)
    
    log "Building new ${description} generation (writing stdout to ${output_file})..."
    nh "${nh_subcommand}" build . | tee "${output_file}"

    if ! system_diff "${output_file}" ; then
        log "No diff."
        return
    fi

    # Try to do the switch, don't exit if fails.
    log "Switching to new ${description} generation..."
    nh "${nh_subcommand}" switch . || :

    send_result $? "${description}" "${output_file}"
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
        subject="${upgrade_type} upgrade succeeded"
    else
        subject="${upgrade_type} upgrade failed with code ${status}"
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
