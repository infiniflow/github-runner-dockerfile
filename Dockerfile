FROM ubuntu:24.04
SHELL ["/bin/bash", "-c"]

# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

ARG NEED_MIRROR=0

RUN apt update -y && \
    apt --no-install-recommends install -y ca-certificates

RUN if [ "$NEED_MIRROR" == "1" ]; then \
        sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources; \
        sed -i 's|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources; \
        apt update -y; \
        mkdir -p /etc/uv && \
        echo "[[index]]" > /etc/uv/uv.toml && \
        echo 'url = "https://pypi.tuna.tsinghua.edu.cn/simple"' >> /etc/uv/uv.toml && \
        echo "default = true" >> /etc/uv/uv.toml; \
    fi; \
    apt upgrade -y && \
    apt install -y --no-install-recommends curl jq build-essential libssl-dev libffi-dev libicu-dev python3 python3-venv python3-dev python3-pip pipx sudo git gh gawk sed wget gpg openssh-client gettext && \
    apt clean -y

# Install docker
# curl -O -L https://download.docker.com/linux/static/stable/x86_64/docker-28.5.1.tgz
RUN --mount=type=bind,source=docker-28.5.1.tgz,target=/root/docker-28.5.1.tgz \
    cd /root \
    && tar zxf docker-28.5.1.tgz \
    && cp docker/* /usr/bin/ \
    && rm -rf docker

# Install docker-buildx
# curl -O -L https://github.com/docker/buildx/releases/download/v0.29.1/buildx-v0.29.1.linux-amd64
RUN --mount=type=bind,source=buildx-v0.29.1.linux-amd64,target=/root/buildx-v0.29.1.linux-amd64 \
    mkdir -p /usr/lib/docker/cli-plugins \
    && cp /root/buildx-v0.29.1.linux-amd64 /usr/lib/docker/cli-plugins/docker-buildx \
    && chmod +x /usr/lib/docker/cli-plugins/docker-buildx

# Install docker-compose
# curl -O -L https://github.com/docker/compose/releases/download/v2.40.1/docker-compose-linux-x86_64
RUN --mount=type=bind,source=docker-compose-linux-x86_64,target=/root/docker-compose-linux-x86_64 \
    mkdir -p /usr/lib/docker/cli-plugins \
    && cp /root/docker-compose-linux-x86_64 /usr/lib/docker/cli-plugins/docker-compose \
    && chmod +x /usr/lib/docker/cli-plugins/docker-compose

# https://docs.codecov.com/docs/codecov-uploader
# curl -Os https://cli.codecov.io/latest/linux/codecov
RUN --mount=type=bind,source=codecov,target=/root/codecov \
    cp /root/codecov /usr/bin/ \
    && chmod +x /usr/bin/codecov

RUN useradd -m alice \
    && echo "alice      ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/alice

# since the config and run script for actions are not allowed to be run by root,
# set the user to "alice" so all subsequent commands are run as the alice user
USER alice
ENV USER=alice HOME=/home/alice PATH=/home/alice/.local/bin:$PATH
WORKDIR /home/alice

RUN if [ "$NEED_MIRROR" == "1" ]; then \
        pip3 config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple && \
        pip3 config set global.trusted-host pypi.tuna.tsinghua.edu.cn; \
    fi; \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    uv python install python3.10 python3.11

# curl -O -L https://github.com/actions/runner/releases/download/v2.329.0/actions-runner-linux-x64-2.329.0.tar.gz
RUN --mount=type=bind,source=actions-runner-linux-x64-2.329.0.tar.gz,target=/actions-runner.tar.gz \
    cd /home/alice \
    && mkdir actions-runner \
    && cd actions-runner \
    && tar xzf /actions-runner.tar.gz \
    && sudo bin/installdependencies.sh

COPY start.sh start.sh

# make the script executable
RUN sudo chmod +x start.sh

ENTRYPOINT ["./start.sh"]
