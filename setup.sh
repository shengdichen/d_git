#!/usr/bin/env dash

SCRIPT_PATH="$(realpath "$(dirname "${0}")")"
cd "${SCRIPT_PATH}" || exit 3

DIR_CONF="${HOME}/.config/git"

__stow() {
    mkdir -p "${DIR_CONF}"
    stow -R --target "${DIR_CONF}" "conf"
}

__stow
