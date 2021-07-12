#!/usr/bin/env bash

err_generic=1
err_missing_file=3
err_config_test_failed=4

keyserver_url="https://sentinel.gravityadmin.com/authorized_keys"

usage() {
    echo "$0 [options] <ssh_user>"
    echo
    echo "Arguments:"
    echo "    ssh_user"
    echo "        The username of the user that SSH access should be restricted to."
    echo
    echo "Options:"
    echo "    -h, --help"
    echo "        Display this help text."
    echo
    echo "    --describe"
    echo "        Do not actually change any system settings, only describe which actions would be taken."
    echo
    echo "    --keyserver <url>"
    echo "       The HTTP or HTTPS URL that should be used as the authorized keys source."
    echo "       Default: ${keyserver_url}"
    echo
    echo "Exit Codes:"
    echo "    1  - Something unexpected happend (e.g. incorrect command arguments)"
    echo "    3  - A configuration this script normally touches could not be accessed"
    echo "    4  - A config test (e.g. sshd -t) exited with a non-zero status code"
}

describe=0
positional_args=()

while [ $# -gt 0 ]; do
    key="$1"

    case $key in
        --help)
            usage

            exit 0

            ;;

        --describe)
            describe=1

            ;;

	--keyserver)
	    keyserver_url="$2"
	    shift

	    ;;

        -*|--*)
            usage

            exit $err_generic

            ;;

        *)
            positional_args+=("$key")

            ;;
    esac

    shift
done

set -- "${positional_args[@]}"

if [ $# -ne 1 ]; then
    usage

    exit $err_generic
fi

fetch_keys_script_path="/opt/sentinel/fetch_keys.sh"

if [ $describe -gt 0 ]; then
    echo "Creating ${fetch_keys_script_path}"
else
    mkdir -p "$(dirname "$fetch_keys_script_path")"

    echo '#!/usr/bin/env sh

# Only the user that was configured to have SSH access is allowed to retrieve SSH keys
if [ "$1" != "'$1'" ]; then
    exit 0
fi

curl -s "'$keyserver_url'"' > "$fetch_keys_script_path"

    chmod 755 "$fetch_keys_script_path"
fi

sshd_config_path="/etc/ssh/sshd_config"
sshd_authorized_keys_command_value="AuthorizedKeysCommand /opt/sentinel/fetch_keys.sh"
sshd_authorized_keys_command_user_value="AuthorizedKeysCommandUser nobody"

if [ -f "$sshd_config_path" ]; then
    if [ $describe -gt 0 ]; then
        echo "Updating AuthorizedKeysCommand and AuthorizedKeysCommandUser in ${sshd_config_path}"
        echo "===== OLD ====="
        echo "$(grep -P "AuthorizedKeysCommand(User)? " "$sshd_config_path")"
        echo
        echo "===== NEW ====="
        echo $sshd_authorized_keys_command_value
        echo $sshd_authorized_keys_command_user_value
    else
        sed -i "s|^#\{0,1\}\w*AuthorizedKeysCommand .*|${sshd_authorized_keys_command_value}|" "${sshd_config_path}"
        sed -i "s|^#\{0,1\}\w*AuthorizedKeysCommandUser .*|${sshd_authorized_keys_command_user_value}|" "${sshd_config_path}"
    fi
else
    echo "ERROR: Could not determine patch to sshd_config"

    exit $err_missing_file
fi

if ! sshd -t; then
    echo "sshd -t exited with a non-zero exit code, indicating a problem with the new configuration. You will"
    echo "need to review it and fix any issues."

    exit $err_config_test_failed
fi

if [ $describe -eq 0 ]; then
    apt-get remove -y ec2-instance-connect
    systemctl reload sshd
fi
