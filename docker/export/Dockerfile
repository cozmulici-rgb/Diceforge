ARG GODOT_VERSION=4.3-stable
FROM ubuntu:24.04

ARG GODOT_VERSION
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
ENV GODOT_VERSION=${GODOT_VERSION}
ENV GODOT_PROJECT_PATH=/workspace/game

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        file \
        libasound2t64 \
        libfontconfig1 \
        libgl1 \
        libx11-6 \
        libxcursor1 \
        libxext6 \
        libxi6 \
        libxinerama1 \
        libxrandr2 \
        make \
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) godot_arch="x86_64" ;; \
        arm64) godot_arch="arm64" ;; \
        *) echo "Unsupported Docker target architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    version_number="${GODOT_VERSION%%-*}"; \
    version_flavor="${GODOT_VERSION#*-}"; \
    mkdir -p /opt/godot /root/.local/share/godot/export_templates; \
    curl -fsSL -o /tmp/godot.zip "https://downloads.godotengine.org/?version=${version_number}&flavor=${version_flavor}&slug=linux.${godot_arch}.zip&platform=linux.${godot_arch}"; \
    unzip -q /tmp/godot.zip -d /opt/godot; \
    mv "/opt/godot/Godot_v${GODOT_VERSION}_linux.${godot_arch}" /opt/godot/godot; \
    chmod +x /opt/godot/godot; \
    ln -s /opt/godot/godot /usr/local/bin/godot; \
    curl -fsSL -o /tmp/export_templates.tpz "https://downloads.godotengine.org/?version=${version_number}&flavor=${version_flavor}&slug=export_templates.tpz&platform=templates"; \
    mkdir -p /tmp/export-templates; \
    unzip -q /tmp/export_templates.tpz -d /tmp/export-templates; \
    version_dir="$(printf '%s' "${GODOT_VERSION}" | sed 's/-/./')"; \
    mkdir -p "/root/.local/share/godot/export_templates/${version_dir}"; \
    if [ -d /tmp/export-templates/templates ]; then \
        mv /tmp/export-templates/templates/* "/root/.local/share/godot/export_templates/${version_dir}/"; \
    else \
        mv /tmp/export-templates/* "/root/.local/share/godot/export_templates/${version_dir}/"; \
    fi; \
    rm -rf /tmp/godot.zip /tmp/export_templates.tpz /tmp/export-templates

WORKDIR /workspace

CMD ["bash"]
