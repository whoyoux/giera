# Serwer dedykowany: ten sam projekt uruchomiony bez okna i bez gracza.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
ARG GODOT_SHA512_AMD64=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
ARG GODOT_SHA512_ARM64=dd59918da086bd49bde2f5450b5e567ff8650cbde9abbd7b8f4ca1197ff8c609baa38834666d032deafb47099078d7822279e2a0e06e5665745468f26533e7e2

RUN set -eu; \
	apt-get update; \
	apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1; \
	case "$(dpkg --print-architecture)" in \
		amd64) suffix=x86_64; sha="$GODOT_SHA512_AMD64" ;; \
		arm64) suffix=arm64; sha="$GODOT_SHA512_ARM64" ;; \
		*) echo "Nieobslugiwana architektura"; exit 1 ;; \
	esac; \
	name="Godot_v${GODOT_VERSION}-stable_linux.${suffix}"; \
	curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${name}.zip"; \
	echo "${sha}  /tmp/godot.zip" | sha512sum -c -; \
	unzip -q /tmp/godot.zip -d /tmp/godot; \
	install -m 755 "/tmp/godot/${name}" /usr/local/bin/godot; \
	rm -rf /tmp/godot /tmp/godot.zip; \
	apt-get purge -y curl unzip; \
	apt-get autoremove -y; \
	rm -rf /var/lib/apt/lists/*; \
	useradd --create-home giera

COPY --chown=giera:giera . /game
WORKDIR /game
USER giera

# Import buduje cache zasobow i liste klas. Bez tego plik nie powstanie i build sie przerwie.
RUN godot --headless --path /game --import || true; \
	test -f /game/.godot/global_script_class_cache.cfg

EXPOSE 7777/udp 7778/udp
STOPSIGNAL SIGTERM
# Port i tryb podaje compose.yaml. Ten sam obraz sluzy wszystkim serwerom.
ENTRYPOINT ["godot", "--headless", "--path", "/game", "--", "--server"]
CMD ["--port=7777", "--mode=deathmatch"]
