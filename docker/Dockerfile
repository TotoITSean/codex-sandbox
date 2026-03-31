# syntax=docker/dockerfile:1.7

# ==========================================================================
# Stage 1: Build XRDP from source with H264 encoding support
# ==========================================================================
FROM debian:bookworm AS xrdp-builder

RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    libssl-dev \
    libpam0g-dev \
    libjpeg-dev \
    libjpeg62-turbo-dev \
    libturbojpeg0-dev \
    libx11-dev \
    libxrandr-dev \
    libxfixes-dev \
    libfuse3-dev \
    libxkbfile-dev \
    xserver-xorg-dev \
    libtool \
    automake \
    pkg-config \
    nasm \
    wget \
    libmp3lame-dev \
    libpixman-1-dev \
    libpulse-dev \
    pulseaudio \
    && rm -rf /var/lib/apt/lists/*

# Build x264 for H264 encoding
WORKDIR /build
RUN git clone --depth 1 https://code.videolan.org/videolan/x264.git && \
    cd x264 && \
    ./configure --enable-shared --enable-static && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# Build XRDP with H264 support
RUN git clone --branch devel https://github.com/neutrinolabs/xrdp.git && \
    cd xrdp && \
    ./bootstrap && \
    ./configure \
        --enable-vsock \
        --enable-tjpeg \
        --enable-fuse \
        --enable-x264 \
        --enable-rfxcodec \
        --enable-mp3lame \
        --enable-pixman \
        --enable-painter \
        --with-socketdir=/run/xrdp \
    && \
    make -j$(nproc) && \
    make install

# Build xorgxrdp
RUN git clone --branch devel https://github.com/neutrinolabs/xorgxrdp.git && \
    cd xorgxrdp && \
    ./bootstrap && \
    ./configure && \
    make -j$(nproc) && \
    make install

# Build pulseaudio from source and pulseaudio-module-xrdp
RUN sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/*.sources 2>/dev/null || \
    echo "deb-src http://deb.debian.org/debian bookworm main" >> /etc/apt/sources.list && \
    apt-get update && apt-get install -y dpkg-dev libsndfile1-dev libspeexdsp-dev libtdb-dev meson check doxygen && \
    apt-get source pulseaudio && \
    PULSE_SRC=$(ls -d /build/pulseaudio-*/) && \
    cd "$PULSE_SRC" && \
    meson setup build -Ddaemon=false -Ddoxygen=false -Dgcov=false -Dman=false -Dtests=false && \
    cd /build && \
    git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git && \
    cd pulseaudio-module-xrdp && \
    ./bootstrap && \
    ./configure PULSE_DIR="$PULSE_SRC" PULSE_CONFIG_DIR="$PULSE_SRC/build" && \
    make -j$(nproc) && \
    make install && \
    rm -rf /var/lib/apt/lists/*

# Stage xrdp pulse modules to a stable path for COPY
RUN mkdir -p /build/pulse-xrdp-modules && \
    find /usr/lib -name "module-xrdp-*.so" -exec cp {} /build/pulse-xrdp-modules/ \;

# ==========================================================================
# Stage 2: Runtime image with Cinnamon desktop, XRDP, and dev tools
# ==========================================================================
FROM node:22-slim

ENV DEBIAN_FRONTEND=noninteractive

# ---------- Core tools, desktop environment, and dev essentials ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
        # Build tools
        build-essential \
        curl \
        wget \
        git \
        git-lfs \
        sudo \
        jq \
        ripgrep \
        unzip \
        zip \
        xz-utils \
        pkg-config \
        ca-certificates \
        gnupg \
        # Python
        python3 \
        python3-pip \
        python3-venv \
        # Media tools
        imagemagick \
        ffmpeg \
        # Network/shell tools
        openssh-server \
        tmux \
        nano \
        mosh \
        dos2unix \
        locales \
        # Cinnamon desktop
        cinnamon \
        cinnamon-core \
        cinnamon-session \
        lightdm \
        # X11 and graphics
        xserver-xorg-core \
        xserver-xorg-input-all \
        xserver-xorg-video-all \
        x11-xserver-utils \
        dbus-x11 \
        # XRDP runtime deps
        libssl3 \
        libpam0g \
        libjpeg62-turbo \
        libturbojpeg0 \
        libx11-6 \
        libxrandr2 \
        libxfixes3 \
        fuse3 \
        # Themes, icons, and cursors
        adwaita-icon-theme \
        gnome-themes-extra \
        papirus-icon-theme \
        dmz-cursor-theme \
        dconf-cli \
        lxappearance \
        bc \
        # PulseAudio for sound
        pulseaudio \
        # Terminal and browser
        xfce4-terminal \
        firefox-esr \
        # PulseAudio extras for XRDP sound
        pulseaudio-utils \
        alsa-utils \
        # Process management
        supervisor \
        dbus \
        openssl \
    && rm -rf /var/lib/apt/lists/*

# ---------- .NET SDK 10 ----------
RUN curl -fsSL https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && rm /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends dotnet-sdk-10.0 \
    && rm -rf /var/lib/apt/lists/*

# ---------- Codex CLI ----------
RUN npm install -g @openai/codex @th0rgal/ralph-wiggum playwright && npx playwright install --with-deps
ENV NODE_PATH=/usr/local/lib/node_modules

# ---------- Create 'user' account ----------
ARG PUID=1000
ARG PGID=1000
RUN groupadd -g $PGID user 2>/dev/null || groupmod -n user $(getent group $PGID | cut -d: -f1) && \
    useradd -g user -u $PUID -m -s /bin/bash user 2>/dev/null || usermod -l user -d /home/user -m $(getent passwd $PUID | cut -d: -f1) && \
    usermod -a -G sudo,audio,video user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/user/.profile && \
    echo 'cd /files' >> /home/user/.bashrc && \
    echo '[ -f /etc/container-title ] && PROMPT_COMMAND="printf \"\\033]0;\$(cat /etc/container-title)\\007\";$PROMPT_COMMAND"' >> /home/user/.bashrc

# ---------- SSH ----------
RUN mkdir -p /run/sshd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ---------- Locale ----------
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV TERM=xterm-256color

# ---------- Force 0.0.0.0 binding for common frameworks ----------
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENV HOST=0.0.0.0
ENV HOSTNAME=0.0.0.0

# ---------- Set Firefox as default browser ----------
RUN update-alternatives --set x-www-browser /usr/bin/firefox-esr && \
    update-alternatives --set gnome-www-browser /usr/bin/firefox-esr 2>/dev/null || true

# ==========================================================================
# XRDP: Copy compiled binaries from builder stage
# ==========================================================================
COPY --from=xrdp-builder /usr/local/bin/xrdp* /usr/local/bin/
COPY --from=xrdp-builder /usr/local/sbin/xrdp* /usr/local/sbin/
COPY --from=xrdp-builder /usr/local/lib/xrdp /usr/local/lib/xrdp
COPY --from=xrdp-builder /usr/local/lib/libx264.so* /usr/local/lib/
COPY --from=xrdp-builder /usr/local/libexec/xrdp/ /usr/local/libexec/xrdp/
COPY --from=xrdp-builder /usr/lib/xorg/modules/ /usr/lib/xorg/modules/
COPY --from=xrdp-builder /etc/xrdp/ /etc/xrdp/
COPY --from=xrdp-builder /usr/local/share/xrdp/ /usr/local/share/xrdp/

# Copy xrdp PulseAudio modules
COPY --from=xrdp-builder /build/pulse-xrdp-modules/ /tmp/pulse-modules/
RUN PULSE_MOD_DIR=$(find /usr/lib -maxdepth 1 -type d -name 'pulse-*' | head -1)/modules && \
    cp /tmp/pulse-modules/module-xrdp-*.so "$PULSE_MOD_DIR/" && \
    rm -rf /tmp/pulse-modules

# PAM config for xrdp-sesman
RUN printf '%s\n' \
'#%PAM-1.0' \
'@include common-auth' \
'@include common-account' \
'session    optional     pam_loginuid.so' \
'@include common-session' \
> /etc/pam.d/xrdp-sesman

# Xorg config for xrdpdev virtual framebuffer driver
RUN mkdir -p /etc/X11/xrdp && printf '%s\n' \
'Section "ServerLayout"' \
'    Identifier "X.org Configured"' \
'    Screen 0 "Screen0" 0 0' \
'    InputDevice "xrdpMouse" "CorePointer"' \
'    InputDevice "xrdpKeyboard" "CoreKeyboard"' \
'EndSection' \
'' \
'Section "Module"' \
'    Load "xorgxrdp"' \
'    Load "fb"' \
'    Load "glamoregl"' \
'EndSection' \
'' \
'Section "InputDevice"' \
'    Identifier "xrdpMouse"' \
'    Driver "xrdpmouse"' \
'EndSection' \
'' \
'Section "InputDevice"' \
'    Identifier "xrdpKeyboard"' \
'    Driver "xrdpkeyb"' \
'EndSection' \
'' \
'Section "Monitor"' \
'    Identifier "Monitor0"' \
'    HorizSync 0.0 - 200.0' \
'    VertRefresh 0.0 - 200.0' \
'EndSection' \
'' \
'Section "Device"' \
'    Identifier "Card0"' \
'    Driver "xrdpdev"' \
'EndSection' \
'' \
'Section "Screen"' \
'    Identifier "Screen0"' \
'    Device "Card0"' \
'    Monitor "Monitor0"' \
'    SubSection "Display"' \
'        Viewport 0 0' \
'        Depth 24' \
'        Modes "800x600"' \
'    EndSubSection' \
'EndSection' \
> /etc/X11/xrdp/xorg.conf

# Generate xrdp RSA keys and create directories
RUN /usr/local/bin/xrdp-keygen xrdp /etc/xrdp/rsakeys.ini && \
    ldconfig && \
    mkdir -p /run/xrdp /var/run/xrdp /var/log/xrdp /etc/xrdp/cert.d

# Set xfce4-terminal as default (gnome-terminal requires systemd user session)
RUN update-alternatives --set x-terminal-emulator /usr/bin/xfce4-terminal.wrapper

# Configure XRDP for H264 and performance
RUN echo "allowed_users=anybody" > /etc/X11/Xwrapper.config && \
    echo "needs_root_rights=yes" >> /etc/X11/Xwrapper.config

# Improve H264 quality
RUN sed -i \
    -e 's/^preset = "ultrafast"/preset = "veryfast"/' \
    -e 's/^profile = "main".*$/profile = "high"/' \
    -e 's/^threads = 1.*$/threads = 2/' \
    /etc/xrdp/gfx.toml

# Strip non-Xorg session types
RUN sed -i '/^\[Xvnc\]/,$d' /etc/xrdp/xrdp.ini

# Force xrdp and sesman to log to files only, not syslog/console
RUN sed -i \
    -e 's|^LogFile=.*|LogFile=/var/log/xrdp/xrdp.log|' \
    -e 's|^SyslogLevel=.*|SyslogLevel=DISABLED|' \
    -e 's|^EnableSyslog=.*|EnableSyslog=false|' \
    -e 's|^#EnableSyslog=.*|EnableSyslog=false|' \
    -e 's|^LogLevel=.*|LogLevel=WARNING|' \
    /etc/xrdp/xrdp.ini && \
    sed -i \
    -e 's|^LogFile=.*|LogFile=/var/log/xrdp/sesman.log|' \
    -e 's|^SyslogLevel=.*|SyslogLevel=DISABLED|' \
    -e 's|^EnableSyslog=.*|EnableSyslog=false|' \
    -e 's|^#EnableSyslog=.*|EnableSyslog=false|' \
    -e 's|^LogLevel=.*|LogLevel=WARNING|' \
    /etc/xrdp/sesman.ini

# Set XRDP_SOCKET_PATH for PulseAudio xrdp modules (UID 1000 = user)
RUN sed -i '/^\[SessionVariables\]/a XRDP_SOCKET_PATH=/run/xrdp/1000' /etc/xrdp/sesman.ini

# Create startwm.sh to launch Cinnamon desktop session
RUN printf '%s\n' \
'#!/bin/sh' \
'' \
'if [ -r /etc/default/locale ]; then' \
'    . /etc/default/locale' \
'    export LANG LANGUAGE' \
'fi' \
'' \
'export XDG_SESSION_TYPE=x11' \
'export XDG_CURRENT_DESKTOP=X-Cinnamon' \
'export DESKTOP_SESSION=cinnamon' \
'' \
'# Display scaling' \
'export GDK_DPI_SCALE=1.0' \
'export QT_SCALE_FACTOR=1.0' \
'if [ -f "$HOME/.config/display-scaling.conf" ]; then' \
'    . "$HOME/.config/display-scaling.conf"' \
'fi' \
'if [ -f "$HOME/.Xresources" ]; then' \
'    xrdb -merge "$HOME/.Xresources"' \
'elif [ -f /etc/X11/Xresources.d/scaling ]; then' \
'    xrdb -merge /etc/X11/Xresources.d/scaling' \
'fi' \
'' \
'# Start PulseAudio with xrdp sink/source for audio redirection' \
'export XRDP_SOCKET_PATH=/run/xrdp/$(id -u)' \
'export PULSE_RUNTIME_PATH=/run/user/$(id -u)/pulse' \
'export XDG_RUNTIME_DIR=/run/user/$(id -u)' \
'mkdir -p "$XDG_RUNTIME_DIR" "$PULSE_RUNTIME_PATH"' \
'chmod 700 "$XDG_RUNTIME_DIR"' \
'# Kill any existing PulseAudio and start fresh' \
'pulseaudio --kill 2>/dev/null || true' \
'sleep 0.5' \
'pulseaudio --start --log-target=syslog 2>/dev/null' \
'' \
'exec dbus-launch --exit-with-session cinnamon-session' \
> /etc/xrdp/startwm.sh && chmod +x /etc/xrdp/startwm.sh

# Disable PulseAudio realtime scheduling and auto-exit
RUN printf '\n%s\n' 'realtime-scheduling = no' 'high-priority = no' 'exit-idle-time = -1' >> /etc/pulse/daemon.conf

# PulseAudio system-wide config for XRDP audio redirection
# Uses /etc/pulse/default.pa (system-wide) so it survives /home/user volume mount
RUN printf '%s\n' \
'#!/usr/bin/pulseaudio -nF' \
'' \
'load-module module-augment-properties' \
'load-module module-always-sink' \
'load-module module-native-protocol-unix' \
'' \
'.ifexists module-x11-publish.so' \
'load-module module-x11-publish' \
'.endif' \
'' \
'.ifexists module-xrdp-sink.so' \
'load-module module-xrdp-sink' \
'.endif' \
'' \
'.ifexists module-xrdp-source.so' \
'load-module module-xrdp-source' \
'.endif' \
'' \
'load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1' \
'load-module module-switch-on-connect' \
> /etc/pulse/default.pa

# System-wide DPI default (96 = native, let RDP client handle scaling)
RUN mkdir -p /etc/X11/Xresources.d && \
    printf '%s\n' \
    'Xft.dpi: 96' \
    'Xft.antialias: 1' \
    'Xft.hinting: 1' \
    'Xft.hintstyle: hintslight' \
    'Xft.rgba: rgb' \
    'Xcursor.size: 24' \
    > /etc/X11/Xresources.d/scaling

# Set Cinnamon theme defaults via dconf
RUN mkdir -p /etc/dconf/profile /etc/dconf/db/local.d && \
    printf '%s\n' 'user-db:user' 'system-db:local' > /etc/dconf/profile/user && \
    printf '%s\n' \
    '[org/cinnamon/desktop/interface]' \
    "icon-theme='Papirus'" \
    "cursor-theme='DMZ-White'" \
    "cursor-size=24" \
    "gtk-theme='Adwaita'" \
    '' \
    '[org/cinnamon/theme]' \
    "name='cinnamon'" \
    '' \
    '[org/gnome/desktop/interface]' \
    "icon-theme='Papirus'" \
    "cursor-theme='DMZ-White'" \
    "cursor-size=24" \
    "gtk-theme='Adwaita'" \
    > /etc/dconf/db/local.d/00-theme && \
    dconf update

# ---------- Tmux config ----------
RUN echo 'set -g default-terminal "xterm-256color"' > /etc/tmux.conf && \
    echo 'set -gq utf8 on' >> /etc/tmux.conf && \
    echo 'set -gq status-utf8 on' >> /etc/tmux.conf && \
    echo 'set -g mouse on' >> /etc/tmux.conf && \
    echo 'set -g history-limit 50000' >> /etc/tmux.conf && \
    echo 'bind -n WheelUpPane if-shell -F -t = "#{mouse_any_flag}" "send-keys -M" "if -Ft= \"#{pane_in_mode}\" \"send-keys -M\" \"copy-mode -e\""' >> /etc/tmux.conf && \
    echo 'bind -n WheelDownPane select-pane -t = \\; send-keys -M' >> /etc/tmux.conf

# ==========================================================================
# Container setup script (password, timezone, codex config)
# ==========================================================================
RUN <<'EOF'
cat > /usr/local/bin/setup-container.sh <<'SETUP'
#!/usr/bin/env bash
set -e

# --- Password ---
echo "user:${USER_PASSWORD:-codex}" | chpasswd

# --- Timezone ---
TZ="${TZ:-America/Los_Angeles}"
ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
echo "$TZ" > /etc/timezone

# --- Tmux config (only write if not already customised) ---
HOME=/home/user
if [ ! -f "$HOME/.tmux.conf" ]; then
  cat > "$HOME/.tmux.conf" <<'TMUX'
set -g mouse on
set -g default-terminal "xterm-256color"
set -ga terminal-overrides ",xterm-256color:Tc"
TMUX
fi

# --- Global Codex instructions ---
mkdir -p "$HOME/.codex"
cat > "$HOME/.codex/AGENTS.md" <<'AGENTS'
# Environment

You are running inside a Docker container (Debian-based, node:22-slim) with a Cinnamon desktop accessible via XRDP.
supervisord manages background services — config in /etc/supervisor/conf.d/.

## Networking

Docker container — ALWAYS bind to `0.0.0.0`, NEVER `localhost`/`127.0.0.1`.
Mapped ports: HTTP `8080`, HTTPS `4430`, RDP `3389`.

## Desktop

Cinnamon desktop with Firefox browser is available via RDP.
When the user asks for RDP connection info or types "rdp", read and print the contents of /etc/rdp-info.txt

## Browser

Firefox ESR is the default browser, located at `/usr/bin/firefox-esr`.
Use Firefox for all browsing and automation tasks.
Playwright is installed and configured for Firefox: use `npx playwright launch --browser firefox` or the Playwright API with `firefox` browser type.
To launch Firefox from the command line: `firefox-esr`

## Available tools

git, python3, node/npm, dotnet (SDK 10), ffmpeg, imagemagick, playwright (firefox), tmux, nano, firefox-esr, ralph (wiggum loop)

## Working directory

`/files` — this directory is shared with the host machine.
AGENTS

# --- Enable multi-agent feature and trust /files ---
if [ ! -f "$HOME/.codex/config.toml" ]; then
  cat > "$HOME/.codex/config.toml" <<'TOML'
[features]
multi_agent = true

[projects."/files"]
trust_level = "trusted"
TOML
else
  if ! grep -q 'multi_agent' "$HOME/.codex/config.toml"; then
    printf '\n[features]\nmulti_agent = true\n' >> "$HOME/.codex/config.toml"
  fi
  if ! grep -q 'trust_level' "$HOME/.codex/config.toml"; then
    printf '\n[projects."/files"]\ntrust_level = "trusted"\n' >> "$HOME/.codex/config.toml"
  fi
fi


# --- Generate XRDP certificates if needed ---
if [ ! -f /etc/xrdp/cert.d/cert.pem ]; then
    mkdir -p /etc/xrdp/cert.d
    cd /etc/xrdp/cert.d
    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout key.pem -out cert.pem -days 365 \
        -subj "/C=US/ST=State/L=City/O=Org/CN=xrdp"
fi
SETUP
chmod +x /usr/local/bin/setup-container.sh
EOF

# ==========================================================================
# Supervisord config (background services)
# ==========================================================================
RUN <<'EOF'
cat > /etc/supervisor/conf.d/services.conf <<'CONF'
[supervisord]
nodaemon=false
logfile=/var/log/supervisord.log
logfile_maxbytes=1MB
loglevel=warn
pidfile=/var/run/supervisord.pid

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
stdout_logfile=/var/log/sshd.log
stderr_logfile=/var/log/sshd.err
stdout_logfile_maxbytes=1MB
stderr_logfile_maxbytes=1MB

[program:dbus]
command=/usr/bin/dbus-daemon --system --nofork
autostart=true
autorestart=true
stdout_logfile=/dev/null
stderr_logfile=/dev/null
stdout_logfile_maxbytes=0
stderr_logfile_maxbytes=0

[program:xrdp-sesman]
command=/usr/local/sbin/xrdp-sesman --nodaemon
autostart=true
autorestart=true
stdout_logfile=/var/log/xrdp-sesman.log
stderr_logfile=/var/log/xrdp-sesman.err
stdout_logfile_maxbytes=1MB
stderr_logfile_maxbytes=1MB

[program:xrdp]
command=/usr/local/sbin/xrdp --nodaemon
autostart=true
autorestart=true
depends_on=xrdp-sesman
stdout_logfile=/var/log/xrdp.log
stderr_logfile=/var/log/xrdp.err
stdout_logfile_maxbytes=1MB
stderr_logfile_maxbytes=1MB
CONF
EOF

# ---------- Entrypoint ----------
RUN <<'EOF'
cat > /opt/codex-entrypoint.sh <<'ENTRY'
#!/usr/bin/env bash
set -e

# All setup output to log file
/usr/local/bin/setup-container.sh >/var/log/entrypoint.log 2>&1

# Fix /home/user ownership (after setup writes config files)
chown -R user:user /home/user >/dev/null 2>&1

# Create XRDP and PulseAudio runtime directories
mkdir -p /run/xrdp /var/run/xrdp /var/log/xrdp /run/user/1000/pulse
chown -R user:user /run/user/1000
rm -f /run/xrdp/sesman.socket /run/xrdp/.sesman.socket.lock
rm -rf /run/xrdp/sesman.socket.r

# Redirect /dev/console to /dev/null so background services can't write to it
mount --bind /dev/null /dev/console 2>/dev/null || true

# Start supervisord fully detached from this tty using setsid
setsid /usr/bin/supervisord -c /etc/supervisor/supervisord.conf </dev/null >/dev/null 2>/dev/null &

# Update Codex CLI and ralph-wiggum to latest
npm update -g @openai/codex @th0rgal/ralph-wiggum >/dev/null 2>&1 || true

# Install or update superpowers plugin as user
sudo -u user bash -c '
  if [ -d "$HOME/.codex/superpowers/.git" ]; then
    (cd "$HOME/.codex/superpowers" && git pull) 2>/dev/null || true
  else
    git clone https://github.com/obra/superpowers.git "$HOME/.codex/superpowers" 2>/dev/null || true
  fi
  mkdir -p "$HOME/.agents/skills"
  ln -sfn "$HOME/.codex/superpowers/skills" "$HOME/.agents/skills/superpowers"
' >/dev/null 2>&1 || true

# Restore /dev/console for codex
umount /dev/console 2>/dev/null || true

# Print RDP info on startup and set terminal title
RDP_PORT="${RDP_HOST_PORT:-33890}"
PASS="${USER_PASSWORD:-changeme}"
if [ "$PASS" = "changeme" ]; then
  CREDS="user / changeme"
else
  CREDS="user / USER_PASSWORD"
fi
echo ""
echo "RDP available at localhost:${RDP_PORT} (${CREDS})"
echo ""

# Write persistent terminal title
HTTP_PORT="${HTTP_HOST_PORT:-8080}"
printf '%s | RDP: localhost:%s (%s) | HTTP: http://localhost:%s' \
  "${HOSTNAME:-codex}" "${RDP_PORT}" "${CREDS}" "${HTTP_PORT}" \
  > /etc/container-title

# Launch Codex in foreground as user
exec sudo -u user -i bash -c "cd /files && exec codex --dangerously-bypass-approvals-and-sandbox $*"
ENTRY
chmod +x /opt/codex-entrypoint.sh
EOF

# ---------- Ports ----------
EXPOSE 22 3389 8080 4430 60000-61000/udp

WORKDIR /files

# Neutralize systemd (pulled as dep by cinnamon/lightdm) so it never runs as PID 1
RUN rm -f /sbin/init && ln -s /opt/codex-entrypoint.sh /sbin/init

ENTRYPOINT ["/opt/codex-entrypoint.sh"]
