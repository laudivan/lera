#!/usr/bin/bash
#
# ${toolbox-flatpak.sh com.google.Chrome @@u %U @@}

[[ -v CONTAINER_HOST ]] && \
flatpakCmd='flatpak-spawn --host flatpak'\
|| flatpakCmd=flatpak

eval "$flatpakCmd $@"

exit $?
