FROM debian:13-slim

# Ruby and python are more sensible to version changes, so we set those to specific versions. The rest of the tools should be fine with the latest version, so
# we set those to latest.
ARG ASDF_VERSION=0.18.1
ARG RUBY_VERSION=3.4.9
ARG PYTHON_VERSION=3.14.4

# Check https://developer.android.com/studio#command-line-tools-only for newer versions
ARG ANDROID_CMDLINE_TOOLS_VERSION=11076708

ARG PI_VERSION=latest
ARG OPENCODE_VERSION=latest
ARG OHMYPI_VERSION=latest

# Install dependencies
RUN apt-get update && \
    apt upgrade -y && \
    apt-get install -y --no-install-recommends \
    autoconf \
    bison \
    build-essential \
    ca-certificates \
    clang \
    cmake \
    chromium \
    curl \
    ddgr \
    default-jdk-headless \
    dnsutils \
    fd-find \
    ffmpeg \
    git \
    hugo \
    imagemagick \
    jq \
    libbz2-dev \
    libffi-dev \
    libgmp-dev \
    libgtk-3-dev \
    liblzma-dev \
    libreadline-dev \
    libsqlite3-dev \
    libssl-dev \
    libyaml-dev \
    make \
    mesa-utils \
    netcat-openbsd \
    ninja-build \
    pkg-config \
    poppler-utils \
    ripgrep \
    ssh \
    unzip \
    zlib1g-dev && \
    ln -s /usr/bin/fdfind /usr/bin/fd && \
    rm -rf /var/lib/apt/lists/*

# Install asdf
RUN cd /tmp && \
    curl -L https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/asdf-v${ASDF_VERSION}-linux-amd64.tar.gz -o asdf.tar.gz && \
    tar -xzf asdf.tar.gz && \
    rm asdf.tar.gz && \
    chmod +x asdf && \
    mv asdf /usr/bin

# Create non-root user
RUN useradd -s /usr/bin/bash -m coder && \
    apt-get update && \
    apt-get install -y --no-install-recommends sudo && \
    echo 'coder ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/coder && \
    chmod 0440 /etc/sudoers.d/coder && \
    rm -rf /var/lib/apt/lists/*

USER coder
WORKDIR /home/coder

RUN mkdir /home/coder/.config && \
    mkdir /home/coder/.agents

# This could be written a a single RUN command but should any of the utilities fail to install, that step would have to be run again, reinstalling everything.
# By splitting the installation into multiple steps, if one fails, only that step needs to be rerun.
# Same reason why we install pi, oh-my-pi and opencode separately, if one of those fails, the others don't need to be reinstalled.

RUN asdf plugin add python && \
    asdf set python ${PYTHON_VERSION} && \
    asdf install python

RUN asdf plugin add bun && \
    asdf set bun latest && \
    asdf install bun

RUN asdf plugin add uv && \
    asdf set uv latest && \
    asdf install uv

RUN asdf plugin add golang && \
    asdf set golang latest && \
    asdf install golang

RUN asdf plugin add ruby && \
    asdf set ruby ${RUBY_VERSION} && \
    asdf install ruby

RUN asdf plugin add flutter && \
    asdf set flutter latest && \
    asdf install flutter

ENV SHELL="/usr/bin/bash"

# Android SDK — installed manually to get a clean `flutter doctor` without Android Studio.
# sdkmanager requires Java; default-jdk-headless is installed above.
# ANDROID_HOME must be set before the RUN steps that use sdkmanager.
ENV ANDROID_HOME=/home/coder/android-sdk
ENV ANDROID_SDK_ROOT=/home/coder/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/default-java
ENV HOME=/home/coder
ENV BUNDLE_PATH=/home/coder/.bundle
ENV PATH="${HOME}/.asdf/shims:${HOME}/.bun/bin:${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools"

# 1. Download cmdline-tools and place them where the SDK manager expects them.
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools && \
    curl -fsSL \
        "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
        -o /tmp/cmdline-tools.zip && \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/android-cmdline-tools && \
    mv /tmp/android-cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest && \
    rm -rf /tmp/cmdline-tools.zip /tmp/android-cmdline-tools

# 2. Accept all SDK licences and install the required components.
RUN yes | sdkmanager --licenses && \
    sdkmanager \
        "platform-tools" \
        "platforms;android-36" \
        "build-tools;36.0.0"

# 3. Tell Flutter where the SDK lives.
RUN flutter config --android-sdk ${ANDROID_HOME} --no-enable-web

RUN bun install -pg @earendil-works/pi-coding-agent@${PI_VERSION}
RUN bun install -pg @oh-my-pi/pi-coding-agent@${OHMYPI_VERSION}
RUN bun install -pg opencode-ai@${OPENCODE_VERSION}
RUN pip install pdf2image

COPY --chown=coder:coder bashrc /home/coder/.bashrc

COPY entrypoint.sh /usr/bin/entrypoint.sh

ENTRYPOINT ["/usr/bin/entrypoint.sh"]
