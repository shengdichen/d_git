#!/usr/bin/env dash

SCRIPT_PATH="$(realpath "$(dirname "${0}")")"
cd "${SCRIPT_PATH}" || exit 3

DIR_CONF="${HOME}/.config/git"

__conf() {
    mkdir -p "${DIR_CONF}"
    stow -R --target "${DIR_CONF}" "conf"
}

__id() {
    local _id="id.conf"
    [ ! -e "${DIR_CONF}/${_id}" ] && cp "./id/default.conf" "${DIR_CONF}/${_id}"
}

__conf
__id
