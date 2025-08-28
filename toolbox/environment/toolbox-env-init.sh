CONTAINERENV=/run/.containerenv

[[ ! -s $CONTAINERENV ]] && return

while read LINE; do
    KEY="TOOLBOX_$(echo $LINE | cut -d '=' -f 1 | tr '[:lower:]' '[:upper:]')"
    export $KEY="$(echo $LINE | cut -d '=' -f 2)"
done < $CONTAINERENV

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

export CONTAINER_HOST=unix:///run/user/$UID/podman/podman.sock
[[ ! -f /usr/bin/podman-remote ]] && \
    sudo dnf --quiet --refresh --assumeyes install podman-remote.x86_64 &&
    alias podman="podman-remote --url $CONTAINER_HOST"

[[ ! -f /usr/bin/flatpak-spawn ]] && \
    sudo dnf --quiet --refresh --assumeyes install flatpak-spawn.x86_64 && \
    alias flatpak="flatpak-spawn"

[[ ! -f /usr/bin/host-spawn ]] && \
    sudo dnf --quiet --refresh --assumeyes install host-spawn

[[ ! -d /var/home/linuxbrew ]] && \
    sudo dnf --quiet --refresh --assumeyes install gcc && \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
[[ -d /var/home/linuxbrew/.linuxbrew/bin/brew ]] &&
    eval $(/var/home/linuxbrew/.linuxbrew/bin/brew shellenv)
    
[[ ! -f /usr/bin/xdg-settings ]] && \
    sudo sudo dnf --quiet --refresh --assumeyes install xdg-utils

[[ ! -f ~/.local/share/applications/flatpak-spawn@com.google.Chrome.desktop ]] && \
    xdg-settings set default-web-browser flatpak-spawn@com.google.Chrome.desktop 
    
[[ ! -f /usr/bin/zsh ]] && \
    sudo dnf --quiet --refresh --assumeyes install zsh

#export PROMPT="%{%f%b%k%} ~L4u $TOOLBOX_NAME  $(build_prompt)"

export HOSTNAME="${HOSTNAME}-${TOOLBOX_NAME//\"/}"

alias dnf="sudo dnf --assumeyes"
