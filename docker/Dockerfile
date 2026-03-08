# syntax=docker/dockerfile:1.7
FROM node:22-slim

ENV DEBIAN_FRONTEND=noninteractive

# ---------- Core tools & dev essentials ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
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
        # Requested tools
        imagemagick \
        ffmpeg \
        openssh-server \
        tmux \
        nano \
        mosh \
        dos2unix \
        locales \
        # Process supervisor
        supervisor \
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

# ---------- Sudo for all users ----------
RUN echo 'ALL ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/nopasswd \
    && chmod 0440 /etc/sudoers.d/nopasswd

# ---------- SSH ----------
RUN mkdir -p /run/sshd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config

# ---------- Locale ----------
RUN sed -i 's/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# ---------- Force 0.0.0.0 binding for common frameworks ----------
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENV HOST=0.0.0.0
ENV HOSTNAME=0.0.0.0

# ---------- OSC 52 clipboard shim ----------
RUN <<'EOF'
cat > /usr/local/bin/xclip <<'SHIM'
#!/usr/bin/env bash
data=$(cat)
printf '\e]52;c;%s\a' "$(echo -n "$data" | base64 -w0)"
SHIM
chmod +x /usr/local/bin/xclip
EOF

# ---------- Ports ----------
EXPOSE 22 8080 4430 60000-61000/udp

# ---------- Container setup script ----------
RUN <<'EOF'
cat > /opt/codex-setup.sh <<'SETUP'
#!/usr/bin/env bash
set -e

# --- Password ---
echo "root:${USER_PASSWORD:-codex}" | chpasswd

# --- Timezone ---
TZ="${TZ:-America/Los_Angeles}"
ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
echo "$TZ" > /etc/timezone

# --- Tmux config (only write if not already customised) ---
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

You are running inside a Docker container (Debian-based, node:22-slim).
supervisord manages services — config in /etc/supervisor/conf.d/.

## Networking

Docker container — ALWAYS bind to `0.0.0.0`, NEVER `localhost`/`127.0.0.1`.
Mapped ports: HTTP `8080`, HTTPS `4430`.

## Services

When installing services or daemons, add a .conf file in /etc/supervisor/conf.d/
and run `supervisorctl reread && supervisorctl update` to start them.

## Available tools

git, python3, node/npm, dotnet (SDK 10), ffmpeg, imagemagick, playwright, tmux, nano, ralph (wiggum loop)

## Working directory

`/files` — this directory is shared with the host machine.
AGENTS

# --- Enable multi-agent feature ---
if [ ! -f "$HOME/.codex/config.toml" ]; then
  cat > "$HOME/.codex/config.toml" <<'TOML'
[features]
multi_agent = true
TOML
elif ! grep -q 'multi_agent' "$HOME/.codex/config.toml"; then
  printf '\n[features]\nmulti_agent = true\n' >> "$HOME/.codex/config.toml"
fi
SETUP
chmod +x /opt/codex-setup.sh
EOF

# ---------- Supervisord config (background services only) ----------
RUN <<'EOF'
cat > /etc/supervisor/conf.d/services.conf <<'CONF'
[supervisord]
nodaemon=false

[program:sshd]
command=/usr/sbin/sshd -D
autostart=true
autorestart=true
CONF
EOF

# ---------- Entrypoint ----------
RUN <<'EOF'
cat > /opt/codex-entrypoint.sh <<'ENTRY'
#!/usr/bin/env bash
set -e

# Run container setup
/opt/codex-setup.sh

# Start supervisord for background services (sshd, etc.)
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf

# Update Codex CLI and ralph-wiggum to latest
npm update -g @openai/codex @th0rgal/ralph-wiggum 2>/dev/null || true

# Install or update superpowers plugin
if [ -d "$HOME/.codex/superpowers/.git" ]; then
  (cd "$HOME/.codex/superpowers" && git pull) 2>/dev/null || true
else
  git clone https://github.com/obra/superpowers.git "$HOME/.codex/superpowers" 2>/dev/null || true
fi
mkdir -p "$HOME/.agents/skills"
ln -sfn "$HOME/.codex/superpowers/skills" "$HOME/.agents/skills/superpowers"

# Launch Codex in foreground with TTY
exec codex --dangerously-bypass-approvals-and-sandbox "$@"
ENTRY
chmod +x /opt/codex-entrypoint.sh
EOF

WORKDIR /files

ENTRYPOINT ["/opt/codex-entrypoint.sh"]
