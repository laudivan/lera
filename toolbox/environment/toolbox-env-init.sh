CONTAINERENV=/run/.containerenv

[[ ! -s $CONTAINERENV ]] && return

while read LINE; do
    KEY="TOOLBOX_$(echo $LINE | cut -d '=' -f 1 | tr '[:lower:]' '[:upper:]')"
    export $KEY="$(echo $LINE | cut -d '=' -f 2)"
done < $CONTAINERENV

function podman {
    CONTAINER_HOST=unix:///run/user/$UID/podman/podman.sock

    [[ ! -f /usr/bin/podman-remote ]] && \
        sudo dnf --refresh --color=always --assumeyes \
	        --quiet --best \
            install podman-remote.x86_64 && \
        sudo dnf clean all

    podman-remote --url $CONTAINER_HOST "$*"

    return $?
}

function flatpak {
    [[ ! -f /usr/bin/flatpak-spawn ]] && \
        sudo dnf --refresh install --assumeyes flatpak-spawn.x86_64 && \
        sudo dnf clean all

    flatpak-spawn --host flatpak "$*"

    return $?
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
		cp -u $DIR_ICONS/${AUX%%.desktop}.svg $DEST_DIR_ICONS/${ID}@${AUX%%.desktop}.svg
	done
}

[[ ! -d /var/home/linuxbrew ]] && \
    sudo dnf --refresh --assumeyes install gcc && \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

#export PROMPT="%{%f%b%k%} ~L4u $TOOLBOX_NAME  $(build_prompt)"
