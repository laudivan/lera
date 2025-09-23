CONTAINERENV=/run/.containerenv

function code {
    if [ -n "${TOOLBOX_ID}" ]; then
        host-spawn -no-pty flatpak run com.visualstudio.code "$@"
    else
        flatpak run com.visualstudio.code "$@"
    fi
}

[[ -v ZSH  ]] && {
	export ZSH_THEME=$([[ -s $CONTAINERENV ]] && echo "crunch" || echo "agnoster")
	source ~/.oh-my-zsh/oh-my-zsh.sh
}

[[ ! -s $CONTAINERENV ]] && return

while read LINE; do
    KEY="TOOLBOX_$(echo $LINE | cut -d '=' -f 1 | tr '[:lower:]' '[:upper:]')"
    export $KEY="$(echo $LINE | cut -d '=' -f 2)"
done < $CONTAINERENV

function dnf {
    sudo dnf --refresh --assumeyes "$@"
    sudo dnf clean all
}

function desktopUpdate {
	ID=${TOOLBOX_ID//\"/}
	DIR_ICONS=/usr/share/icons/hicolor/scalable/apps
	DEST_DIR_ICONS=~/.local/share/icons/hicolor/scalable/apps

	[[ ! -d ~/.local/share/applications ]] && mkdir -p ~/.local/share/applications

	[[ ! -d $DEST_DIR_ICONS ]] && mkdir -p $DEST_DIR_ICONS

	for LAUNCHER in /usr/share/applications/${1}*.desktop; do
        AUX=$(basename ${LAUNCHER})
		DESTINATION=~/.local/share/applications/toolbox-${ID}@${AUX%%.desktop}.desktop

		cat ${LAUNCHER} | \
			sed "s/Exec=/Exec=toolbox run --container=$TOOLBOX_NAME /g" | \
			sed "s/Icon=/Icon=${ID}@/g" > ${DESTINATION}
		cp -u $DIR_ICONS/${AUX%%.desktop}.svg \
		    $DEST_DIR_ICONS/${ID}@${AUX%%.desktop}.svg
	done
}

function podman {
    podman-remote "$@"
}

[[ ! -f /usr/bin/pv ]] && dnf install pv
[[ ! -f /usr/bin/zsh ]] && dnf install zsh && chsh --shell /usr/bin/zsh

export CONTAINER_HOST=unix:///run/user/$UID/podman/podman.sock
[[ ! -f /usr/bin/podman-remote ]] && \
    dnf install podman-remote.x86_64 && \
    dnf clean all

alias podman="podman-remote --url $CONTAINER_HOST"

[[ ! -f /usr/bin/flatpak-spawn ]] && \
    dnf install flatpak-spawn.x86_64 && \
    dnf clean all

[[ ! -f /usr/bin/host-spawn ]] && \
    dnf install host-spawn && \
    dnf clean all

alias flatpak="host-spawn flatpak"

[[ ! -d /var/home/linuxbrew ]] && \
    dnf install gcc && \
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    eval $(/var/home/linuxbrew/.linuxbrew/bin/brew shellenv) && \
    brew install kakoune fastfetch onefetch rich-cli fzf direnv

[[ -s /var/home/linuxbrew/.linuxbrew/bin/brew ]] &&
    eval $(/var/home/linuxbrew/.linuxbrew/bin/brew shellenv)

[[ ! -f /usr/bin/xdg-settings ]] && \
    dnf install xdg-utils

[[ ! -f ~/.local/share/applications/flatpak-spawn@com.google.Chrome.desktop ]] && \
    xdg-settings set default-web-browser flatpak-spawn@com.google.Chrome.desktop

export HOSTNAME="${HOSTNAME}-${TOOLBOX_NAME//\"/}"

