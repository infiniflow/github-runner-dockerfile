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

RUN wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc && \
    if [ "$NEED_MIRROR" == "1" ]; then \
        echo "deb https://mirrors.tuna.tsinghua.edu.cn/llvm-apt/noble/ llvm-toolchain-noble-20 main" >> /etc/apt/sources.list; \
    else \
        echo "deb http://apt.llvm.org/noble/ llvm-toolchain-noble-20 main" >> /etc/apt/sources.list; \
    fi && \
    apt update && \
    apt install -y llvm-20 && \
    apt clean -y

# Install docker
# curl -O -L https://download.docker.com/linux/static/stable/x86_64/docker-29.0.2.tgz
RUN --mount=type=bind,source=docker-29.0.2.tgz,target=/root/docker-29.0.2.tgz \
    cd /root \
    && tar zxf docker-29.0.2.tgz \
    && cp docker/* /usr/bin/ \
    && rm -rf docker

# Install docker-buildx
# curl -O -L https://github.com/docker/buildx/releases/download/v0.30.1/buildx-v0.30.1.linux-amd64
RUN --mount=type=bind,source=buildx-v0.30.1.linux-amd64,target=/root/buildx-v0.30.1.linux-amd64 \
    mkdir -p /usr/lib/docker/cli-plugins \
    && cp /root/buildx-v0.30.1.linux-amd64 /usr/lib/docker/cli-plugins/docker-buildx \
    && chmod +x /usr/lib/docker/cli-plugins/docker-buildx

# Install docker-compose
# curl -O -L https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-x86_64
RUN --mount=type=bind,source=docker-compose-linux-x86_64,target=/root/docker-compose-linux-x86_64 \
    mkdir -p /usr/lib/docker/cli-plugins \
    && cp /root/docker-compose-linux-x86_64 /usr/lib/docker/cli-plugins/docker-compose \
    && chmod +x /usr/lib/docker/cli-plugins/docker-compose

# https://docs.codecov.com/docs/codecov-uploader
# curl -Os https://cli.codecov.io/latest/linux/codecov
RUN --mount=type=bind,source=codecov,target=/root/codecov \
    cp /root/codecov /usr/bin/ \
    && chmod +x /usr/bin/codecov

# curl -Os https://github.com/astral-sh/uv/releases/download/0.9.15/uv-x86_64-unknown-linux-gnu.tar.gz
RUN --mount=type=bind,source=uv-x86_64-unknown-linux-gnu.tar.gz,target=/root/uv-x86_64-unknown-linux-gnu.tar.gz \
    mkdir -p /etc/uv \
    && echo "[[index]]" > /etc/uv/uv.toml \
    && echo 'url = "https://pypi.tuna.tsinghua.edu.cn/simple"' >> /etc/uv/uv.toml \
    && echo "default = true" >> /etc/uv/uv.toml \
    && tar xzf /root/uv-x86_64-unknown-linux-gnu.tar.gz \
    && cp uv-x86_64-unknown-linux-gnu/* /usr/local/bin/ \
    && rm -rf uv-x86_64-unknown-linux-gnu

# Install sqllogictest
# curl -Os https://github.com/risinglightdb/sqllogictest-rs/releases/download/v0.28.4/sqllogictest-bin-v0.28.4-x86_64-unknown-linux-musl.tar.gz
RUN --mount=type=bind,source=sqllogictest-bin-v0.28.4-x86_64-unknown-linux-musl.tar.gz,target=/root/sqllogictest-bin-v0.28.4-x86_64-unknown-linux-musl.tar.gz \
    cd /tmp && tar xzf /root/sqllogictest-bin-v0.28.4-x86_64-unknown-linux-musl.tar.gz && cp -rf sqllogictest /usr/local/bin && rm -fr /tmp/*

RUN useradd -m alice \
    && echo "alice      ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/alice

# since the config and run script for actions are not allowed to be run by root,
# set the user to "alice" so all subsequent commands are run as the alice user
USER alice
ENV USER=alice HOME=/home/alice PATH=/home/alice/.local/bin:$PATH UV_INDEX="https://pypi.tuna.tsinghua.edu.cn/simple"

WORKDIR /home/alice

RUN uv python install 3.10 3.11 3.12 3.13 3.14

# curl -O -L https://github.com/actions/runner/releases/download/v2.330.0/actions-runner-linux-x64-2.330.0.tar.gz
RUN --mount=type=bind,source=actions-runner-linux-x64-2.330.0.tar.gz,target=/actions-runner.tar.gz \
    cd /home/alice \
    && mkdir actions-runner \
    && cd actions-runner \
    && tar xzf /actions-runner.tar.gz \
    && sudo bin/installdependencies.sh

COPY start.sh start.sh

# make the script executable
RUN sudo chmod +x start.sh

ENTRYPOINT ["./start.sh"]
