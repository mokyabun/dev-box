# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=Asia/Seoul

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# 1. Install dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        fish \
        git \
        gosu \
        iproute2 \
        less \
        openssh-client \
        openssh-server \
        sudo \
        tini \
        unzip \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

# 2. Install development tools
RUN curl -fsSL https://code-server.dev/install.sh \
        | sh -s -- --method standalone --prefix /usr/local \
    && rm -rf /root/.cache/code-server \
    && code-server --version

RUN install_home="$(mktemp -d)" \
    && curl -fsSL https://opencode.ai/v2/install \
        | HOME="${install_home}" bash -s -- --no-modify-path \
    && install -m 0755 \
        "${install_home}/.opencode/bin/opencode" \
        /usr/local/bin/opencode \
    && rm -rf "${install_home}" \
    && opencode --version

RUN curl -fsSL https://mise.run \
        | MISE_INSTALL_PATH=/usr/local/bin/mise MISE_INSTALL_HELP=0 sh \
    && mise --version \
    && ln -s /bin/true /usr/local/bin/xdg-open

RUN cd /usr/local/bin \
    && curl -fsSL https://getmic.ro | GETMICRO_REGISTER=no bash \
    && micro -version

# Automation uses bash; interactive users can start fish explicitly.
RUN groupadd --gid 1001 dev \
    && useradd --uid 1001 --gid 1001 --create-home --shell /bin/bash dev \
    && usermod --append --groups sudo dev \
    && passwd --delete dev \
    && printf 'dev ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/dev \
    && chmod 0440 /etc/sudoers.d/dev \
    && install -d -m 0755 /run/sshd /workspace /etc/devbox/ssh

# 3. Copy configuration files and scripts
COPY config/sshd_config /etc/ssh/sshd_config
COPY scripts/healthcheck.sh /usr/local/bin/devbox-healthcheck
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

RUN chmod 0755 /usr/local/bin/docker-entrypoint /usr/local/bin/devbox-healthcheck \
    && chown -R dev:dev /home/dev /workspace

# 4. Set default environment variables
ENV HOME=/home/dev \
    USER=dev \
    SHELL=/bin/bash \
    EDITOR=micro \
    VISUAL=micro \
    PATH=/home/dev/.local/share/mise/shims:/home/dev/.local/bin:${PATH} \
    PUID=1001 \
    PGID=1001 \
    WORKSPACE_DIR=/workspace \
    MISE_CONFIG_DIR=/home/dev/.config/mise \
    MISE_DATA_DIR=/home/dev/.local/share/mise \
    MISE_CACHE_DIR=/home/dev/.cache/mise \
    MISE_STATE_DIR=/home/dev/.local/state/mise \
    CODE_SERVER_PORT=8080 \
    OPENCODE_PORT=4096 \
    SSH_PORT=2222 \
    ENABLE_CODE_SERVER=true \
    ENABLE_OPENCODE=true \
    ENABLE_SSH=true

# 5. Set working directory and expose ports
WORKDIR /workspace

EXPOSE 8080 4096 2222

# 6. Set healthcheck and entrypoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=5 \
    CMD ["devbox-healthcheck"]

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint"]
