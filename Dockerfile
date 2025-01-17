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
    apt install -y --no-install-recommends curl jq build-essential libssl-dev libffi-dev libicu-dev python3 python3-venv python3-dev python3-pip pipx sudo docker.io git gawk sed wget && \
    apt clean -y

# https://docs.docker.com/engine/install/ubuntu/#install-docker-ce
# https://developer.aliyun.com/mirror/docker-ce/
RUN apt update -y \
    && apt purge -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc \
    && apt install -y ca-certificates curl gnupg \
    && install -m 0755 -d /etc/apt/keyrings; \
    if [ "$NEED_MIRROR" == "1" ]; then \
        curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
        chmod a+r /etc/apt/keyrings/docker.asc; \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://mirrors.aliyun.com/docker-ce/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null; \
    else \
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
        chmod a+r /etc/apt/keyrings/docker.asc; \
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null; \
    fi; \
    apt update -y \
    && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
    && apt autoremove \
    && apt clean -y

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
    pipx install uv poetry && \
    uv python install python3.10 python3.11 python3.12 python3.13; \
    if [ "$NEED_MIRROR" == "1" ]; then \
        pipx inject poetry poetry-plugin-pypi-mirror; \
    fi

ENV POETRY_VIRTUALENVS_CREATE=true POETRY_VIRTUALENVS_IN_PROJECT=true

# curl -O -L https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz \
RUN --mount=type=bind,source=actions-runner-linux-x64-2.321.0.tar.gz,target=/actions-runner.tar.gz \
    cd /home/alice \
    && mkdir actions-runner \
    && cd actions-runner \
    && tar xzf /actions-runner.tar.gz \
    && sudo bin/installdependencies.sh

COPY start.sh start.sh

# make the script executable
RUN sudo chmod +x start.sh

ENTRYPOINT ["./start.sh"]
