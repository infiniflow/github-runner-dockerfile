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
        apt-get update -y; \
        mkdir -p /etc/uv; \
        echo 'python-install-mirror = "https://registry.npmmirror.com/-/binary/python-build-standalone/"' > /etc/uv/uv.toml; \
        echo "[[index]]" >> /etc/uv/uv.toml; \
        echo 'url = "https://pypi.tuna.tsinghua.edu.cn/simple"' >> /etc/uv/uv.toml; \
        echo "default = true" >> /etc/uv/uv.toml; \
    fi; \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl jq build-essential libssl-dev libffi-dev libicu-dev python3 python3-venv python3-dev python3-pip pipx sudo git gh gawk sed wget gpg openssh-client gettext iproute2 curl telnet && \
    apt-get clean -y

RUN wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc && \
    if [ "$NEED_MIRROR" == "1" ]; then \
        echo "deb https://mirrors.tuna.tsinghua.edu.cn/llvm-apt/noble/ llvm-toolchain-noble-20 main" >> /etc/apt/sources.list; \
    else \
        echo "deb http://apt.llvm.org/noble/ llvm-toolchain-noble-20 main" >> /etc/apt/sources.list; \
    fi && \
    apt-get update && \
    apt-get install -y llvm-20 lld-20 && \
    ln -s /usr/bin/ld.lld-20 /usr/bin/ld.lld && \
    apt-get clean -y

# Install Go for running Go tests
RUN --mount=type=bind,source=go1.26.4.linux-amd64.tar.gz,target=/root/go1.26.4.linux-amd64.tar.gz \
    tar -C /usr/local -xzf /root/go1.26.4.linux-amd64.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Install Node.js (provides npm/npx, used by web-prettier and web-eslint hooks in lefthook.yml)
RUN --mount=type=bind,source=node-v22.23.1-linux-x64.tar.xz,target=/root/node-v22.23.1-linux-x64.tar.xz \
    tar -C /usr/local -xJf /root/node-v22.23.1-linux-x64.tar.xz --strip-components=1

# Install web lint/format toolchain (consumed by lefthook web-eslint / web-prettier hooks).
# Versions match web/package.json so image behavior stays aligned with what
# `npm ci --include=dev` in web/ would have produced.
RUN if [ "$NEED_MIRROR" == "1" ]; then \
        npm config set registry https://registry.npmmirror.com; \
    fi && \
    npm install -g --no-audit --no-fund \
        "eslint@^8.56.0" \
        "@typescript-eslint/parser@^8.52.0" \
        "@typescript-eslint/eslint-plugin@^8.52.0" \
        "eslint-plugin-react@^7.37.5" \
        "eslint-plugin-react-hooks@^4.6.0" \
        "eslint-plugin-react-refresh@^0.4.26" \
        "eslint-plugin-check-file@^2.8.0" \
        "prettier@^3.2.4" \
        "prettier-plugin-organize-imports@^3.2.4" \
        "prettier-plugin-packagejson@^2.4.9"

# Install docker
RUN --mount=type=bind,source=docker-29.6.1.tgz,target=/root/docker-29.6.1.tgz \
    cd /root \
    && tar zxf docker-29.6.1.tgz \
    && cp docker/* /usr/bin/ \
    && rm -rf docker

# Install docker-buildx
RUN --mount=type=bind,source=buildx-v0.35.0.linux-amd64,target=/root/buildx-v0.35.0.linux-amd64 \
    mkdir -p /usr/lib/docker/cli-plugins \
    && cp /root/buildx-v0.35.0.linux-amd64 /usr/lib/docker/cli-plugins/docker-buildx \
    && chmod +x /usr/lib/docker/cli-plugins/docker-buildx

# Install docker-compose
RUN --mount=type=bind,source=docker-compose-linux-x86_64,target=/root/docker-compose-linux-x86_64 \
    mkdir -p /usr/lib/docker/cli-plugins \
    && cp /root/docker-compose-linux-x86_64 /usr/lib/docker/cli-plugins/docker-compose \
    && chmod +x /usr/lib/docker/cli-plugins/docker-compose

# Install uv
RUN --mount=type=bind,source=uv-x86_64-unknown-linux-gnu.tar.gz,target=/root/uv-x86_64-unknown-linux-gnu.tar.gz \
    tar xzf /root/uv-x86_64-unknown-linux-gnu.tar.gz \
    && cp uv-x86_64-unknown-linux-gnu/* /usr/local/bin/ \
    && rm -rf uv-x86_64-unknown-linux-gnu

# Install ruff (Python linter/formatter, used by lefthook pre-commit hooks)
RUN --mount=type=bind,source=ruff-x86_64-unknown-linux-gnu.tar.gz,target=/root/ruff-x86_64-unknown-linux-gnu.tar.gz \
    tar xzf /root/ruff-x86_64-unknown-linux-gnu.tar.gz \
    && cp ruff-x86_64-unknown-linux-gnu/* /usr/local/bin/ \
    && rm -rf ruff-x86_64-unknown-linux-gnu

# Install sqllogictest
RUN --mount=type=bind,source=sqllogictest-bin-v0.29.1-x86_64-unknown-linux-musl.tar.gz,target=/root/sqllogictest-bin-v0.29.1-x86_64-unknown-linux-musl.tar.gz \
    cd /tmp && tar xzf /root/sqllogictest-bin-v0.29.1-x86_64-unknown-linux-musl.tar.gz && cp -rf sqllogictest /usr/local/bin && rm -fr /tmp/*

# Install codecov
RUN --mount=type=bind,source=codecovcli_linux,target=/root/codecovcli_linux \
    cp /root/codecovcli_linux /usr/bin/codecov \
    && chmod +x /usr/bin/codecov

# Install stripe-cli
RUN --mount=type=bind,source=stripe_1.43.2_linux_x86_64.tar.gz,target=/root/stripe_1.43.2_linux_x86_64.tar.gz \
    cd /tmp && tar xzf /root/stripe_1.43.2_linux_x86_64.tar.gz && cp stripe /usr/local/bin/ && rm -fr /tmp/*

# Install kubectl
RUN --mount=type=bind,source=kubectl-v1.36.1,target=/root/kubectl-v1.36.1 \
    install -o root -g root -m 0755 /root/kubectl-v1.36.1 /usr/local/bin/kubectl

# Install tofu
RUN --mount=type=bind,source=tofu_1.12.3_linux_amd64.tar.gz,target=/root/tofu_1.12.3_linux_amd64.tar.gz \
    cd /tmp && tar xzf /root/tofu_1.12.3_linux_amd64.tar.gz && cp tofu /usr/local/bin/ && rm -fr /tmp/*

# Install lefthook (pre-commit hook runner, drives checks defined in lefthook.yml)
RUN --mount=type=bind,source=lefthook_2.1.10_Linux_x86_64.gz,target=/root/lefthook_2.1.10_Linux_x86_64.gz \
    gunzip -c /root/lefthook_2.1.10_Linux_x86_64.gz > /usr/local/bin/lefthook \
    && chmod +x /usr/local/bin/lefthook

# Copy NLTK data
COPY nltk_data /usr/share/nltk_data

# Pre-extract native static libraries for Go build (pdfium, pdf_oxide, office_oxide).
# build.sh checks /opt/ragflow-native-libs/ first before attempting network download.
COPY pdfium-linux-x64-static.tgz pdf_oxide-go-ffi-linux-amd64.tar.gz office_oxide-linux-x86_64.tar.gz onnxruntime-linux-x64-static_lib-1.23.2-glibc2_28.zip /tmp/
RUN mkdir -p /opt/ragflow-native-libs/pdfium-static && \
    tar xzf /tmp/pdfium-linux-x64-static.tgz -C /opt/ragflow-native-libs/pdfium-static && \
    mkdir -p /opt/ragflow-native-libs/pdf_oxide && \
    tar xzf /tmp/pdf_oxide-go-ffi-linux-amd64.tar.gz -C /opt/ragflow-native-libs/pdf_oxide && \
    mkdir -p /opt/ragflow-native-libs/office_oxide && \
    tar xzf /tmp/office_oxide-linux-x86_64.tar.gz -C /opt/ragflow-native-libs/office_oxide && \
    strings /opt/ragflow-native-libs/office_oxide/lib/liboffice_oxide.a 2>/dev/null | grep -Fxq "0.1.9" || \
      (echo "ERROR: office_oxide version mismatch, expected v0.1.9; run: rm office_oxide-linux-x86_64.tar.gz && uv run download_deps.py" && exit 1) && \
    rm /tmp/pdfium-linux-x64-static.tgz /tmp/pdf_oxide-go-ffi-linux-amd64.tar.gz /tmp/office_oxide-linux-x86_64.tar.gz

# onnxruntime static libs for the in-process Go DeepDoc backend. Baked into
# /opt (like the other native libs); build.sh seeds it to the user cache at
# build/test time via _seed_from_system, so CI never downloads it.
RUN mkdir -p /opt/ragflow-native-libs/onnxruntime/static_lib && \
    python3 -c "import zipfile; zipfile.ZipFile('/tmp/onnxruntime-linux-x64-static_lib-1.23.2-glibc2_28.zip').extractall('/opt/ragflow-native-libs/onnxruntime/static_lib')" && \
    rm /tmp/onnxruntime-linux-x64-static_lib-1.23.2-glibc2_28.zip

# DeepDoc model files (det/layout/tsr/rec.onnx, ocr.res), baked into the
# runner image so CI never downloads them at run time. Consumed by
# sep-tests.yml via the MODEL_DIR env var.
COPY deepdoc-models/ /opt/ragflow-deepdoc-models/

RUN mkdir -p /opt/ragflow_deps && \
    curl -fsSL -o /opt/ragflow_deps/cl100k_base.tiktoken \
      https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken || true

RUN useradd -m alice \
    && echo "alice      ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/alice

# since the config and run script for actions are not allowed to be run by root,
# set the user to "alice" so all subsequent commands are run as the alice user
USER alice
ENV USER=alice HOME=/home/alice PATH=/home/alice/.local/bin:$PATH

WORKDIR /home/alice

RUN if [ "$NEED_MIRROR" == "1" ]; then \
        go env -w GOPROXY=https://goproxy.cn,https://goproxy.io,https://proxy.golang.org,direct; \
    fi && \
    go mod download github.com/apache/thrift@v0.22.0

RUN uv python install 3.12 3.13 3.14

RUN --mount=type=bind,source=actions-runner-linux-x64-2.336.0.tar.gz,target=/actions-runner.tar.gz \
    cd /home/alice \
    && mkdir actions-runner \
    && cd actions-runner \
    && tar xzf /actions-runner.tar.gz \
    && sudo bin/installdependencies.sh

COPY start.sh start.sh

# make the script executable
RUN sudo chmod +x start.sh

ENTRYPOINT ["./start.sh"]
