# Minimal fresh install: a sudo-capable desktop user and the README's
# prerequisite (Git). setup_linux.sh does everything else.
ARG UBUNTU_RELEASE=26.04
FROM ubuntu:${UBUNTU_RELEASE}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get -y install --no-install-recommends ca-certificates git sudo && \
    rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --shell /bin/bash tester && \
    printf '%s\n' 'tester ALL=(ALL) NOPASSWD:ALL' \
      'Defaults env_keep += "DEBIAN_FRONTEND"' > /etc/sudoers.d/tester && \
    chmod 0440 /etc/sudoers.d/tester

USER tester
WORKDIR /home/tester
# Containers lack FUSE, so AppImages (Neovim) extract themselves instead.
ENV APPIMAGE_EXTRACT_AND_RUN=1 USER=tester
