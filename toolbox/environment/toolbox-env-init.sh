CONTAINERENV=/run/.containerenv

[[ ! -s $CONTAINERENV ]] && return

while read LINE; do
    KEY="TOOLBOX_$(echo $LINE | cut -d '=' -f 1 | tr '[:lower:]' '[:upper:]')"
    export $KEY="$(echo $LINE | cut -d '=' -f 2)"
done < $CONTAINERENV

PACKAGES=""

[[ ! -s /usr/bin/podman-remote ]] && PACKAGES+=' podman-remote'

[[ $PACKAGES!="" ]] && \
    dnf check-update && \
    sudo dnf --assumeyes install $PACKAGES && \
    sudo dnf clean all

alias podman="/usr/bin/podman-remote"
alias flatpak="/usr/bin/flatpak-spawn --host /usr/bin/flatpak"

#export PROMPT="%{%f%b%k%} ~L4u $TOOLBOX_NAME  $(build_prompt)"
