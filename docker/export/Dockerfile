ARG GODOT_VERSION=4.3-stable
FROM ubuntu:24.04

ARG GODOT_VERSION

ENV DEBIAN_FRONTEND=noninteractive
ENV GODOT_VERSION=${GODOT_VERSION}

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        make \
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash", "-lc", "echo 'Phase 03 will wire the headless Godot verify/export commands.'"]
