#!/bin/sh
set -eu

if [ "$#" -eq 0 ]; then
    set -- list
fi

target="$1"
shift

case "$target" in
    day[0-9]*)
        target="run-$target"
        ;;
    build-day[0-9]*)
        target="${target#build-}"
        ;;
    run-day[0-9]*)
        ;;
    *)
        # allow raw make targets
        ;;
esac

exec make "$target" "$@"

