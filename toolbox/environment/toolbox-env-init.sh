CONTAINERENV=/run/.containerenv

[[ ! -s $CONTAINERENV ]] && return

while read LINE; do
    KEY="TOOLBOX_$(echo $LINE | cut -d '=' -f 1 | tr '[:lower:]' '[:upper:]')"
    export $KEY="$(echo $LINE | cut -d '=' -f 2)"
done < $CONTAINERENV

PACKAGES=""

[[ ! -s /usr/bin/podman-remote ]] && PACKAGES+=" podman-remote.x86_64"
[[ ! -s /usr/bin/host-spawn ]] && PACKAGES+=" host-spawn.x86_64"
[[ ! -s /usr/bin/zsh ]] && PACKAGES+=" zsh.x86_64 zsh-autosuggestions.noarch"

[[ ! -z "$PACKAGES" ]] && \
    dnf check-update && \
    sudo dnf install -y --skip-unavailable "$PACKAGES" && \
    sudo dnf clean all

alias podman="/usr/bin/podman-remote"
alias flatpak="/usr/bin/flatpak-spawn --host /usr/bin/flatpak"

#export PROMPT="%{%f%b%k%} ~L4u $TOOLBOX_NAME  $(build_prompt)"
