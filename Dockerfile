FROM ubuntu:24.04
SHELL ["/bin/bash", "-c"]

# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

ARG NEED_MIRROR=0

# TARGETARCH is injected by buildx (amd64 / arm64). It drives every
# architecture-specific choice below (binaries, native static libs, the
# GitHub Actions runner) so a single Dockerfile produces a multi-arch image
# under one tag that runs natively on either platform. The amd64 branches are
# byte-for-byte the prior behavior; arm64 is new (needed for ragflow PR #19247).
ARG TARGETARCH

RUN apt update -y && \
    apt --no-install-recommends install -y ca-certificates

RUN if [ "$NEED_MIRROR" == "1" ]; then \
        sed -i 's|http://archive.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources; \
        sed -i 's|http://security.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn|g' /etc/apt/sources.list.d/ubuntu.sources; \
        sed -i 's|http://ports.ubuntu.com|https://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports|g' /etc/apt/sources.list.d/ubuntu.sources; \
        apt-get update -y; \
        mkdir -p /etc/uv; \
        echo 'python-install-mirror = "https://registry.npmmirror.com/-/binary/python-build-standalone/"' > /etc/uv/uv.toml; \
        echo "[[index]]" >> /etc/uv/uv.toml; \
        echo 'url = "https://pypi.tuna.tsinghua.edu.cn/simple"' >> /etc/uv/uv.toml; \
        echo "default = true" >> /etc/uv/uv.toml; \
    fi; \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends curl jq build-essential libssl-dev libffi-dev libicu-dev libsimde-dev python3 python3-venv python3-dev python3-pip pipx sudo git gh gawk sed wget gpg openssh-client gettext iproute2 curl telnet unzip && \
    apt-get clean -y

RUN wget -qO- https://apt.llvm.org/llvm-snapshot.gpg.key | tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc && \
    if [ "$NEED_MIRROR" == "1" ]; then \
        echo "deb https://mirrors.tuna.tsinghua.edu.cn/llvm-apt/noble/ llvm-toolchain-noble-20 main" >> /etc/apt/sources.list; \
    else \
        echo "deb http://apt.llvm.org/noble/ llvm-toolchain-noble-20 main" >> /etc/apt/sources.list; \
    fi && \
    apt-get update && \
    apt-get install -y llvm-20 lld-20 clang-20 && \
    ln -s /usr/bin/ld.lld-20 /usr/bin/ld.lld && \
    ln -s /usr/bin/clang-20 /usr/bin/clang && \
    ln -s /usr/bin/clang++-20 /usr/bin/clang++ && \
    apt-get clean -y

# Install Go for running Go tests
RUN --mount=type=bind,source=go1.27.1.linux-amd64.tar.gz,target=/tmp/go-amd64.tar.gz \
    --mount=type=bind,source=go1.27.1.linux-arm64.tar.gz,target=/tmp/go-arm64.tar.gz \
    case "$TARGETARCH" in \
        amd64) tar -C /usr/local -xzf /tmp/go-amd64.tar.gz ;; \
        arm64) tar -C /usr/local -xzf /tmp/go-arm64.tar.gz ;; \
        *) echo "ERROR: unsupported TARGETARCH=$TARGETARCH" && exit 1 ;; \
    esac
ENV PATH="/usr/local/go/bin:${PATH}"

# Install Node.js (provides npm/npx, used by web-prettier and web-eslint hooks in lefthook.yml)
RUN --mount=type=bind,source=node-v22.23.1-linux-x64.tar.xz,target=/tmp/node-amd64.tar.xz \
    --mount=type=bind,source=node-v22.23.1-linux-arm64.tar.xz,target=/tmp/node-arm64.tar.xz \
    case "$TARGETARCH" in \
        amd64) tar -C /usr/local -xJf /tmp/node-amd64.tar.xz --strip-components=1 ;; \
        arm64) tar -C /usr/local -xJf /tmp/node-arm64.tar.xz --strip-components=1 ;; \
        *) echo "ERROR: unsupported TARGETARCH=$TARGETARCH" && exit 1 ;; \
    esac

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
RUN --mount=type=bind,source=docker-29.6.1.tgz,target=/tmp/docker-amd64.tgz \
    --mount=type=bind,source=docker-29.6.1-aarch64.tgz,target=/tmp/docker-arm64.tgz \
    mkdir -p /root/docker-extract \
    && case "$TARGETARCH" in \
        amd64) tar zxf /tmp/docker-amd64.tgz -C /root/docker-extract ;; \
        arm64) tar zxf /tmp/docker-arm64.tgz -C /root/docker-extract ;; \
        *) exit 1 ;; \
    esac \
    && cp /root/docker-extract/docker/* /usr/bin/ \
    && rm -rf /root/docker-extract

# Install docker-buildx
RUN --mount=type=bind,source=buildx-v0.35.0.linux-amd64,target=/tmp/buildx-amd64 \
    --mount=type=bind,source=buildx-v0.35.0.linux-arm64,target=/tmp/buildx-arm64 \
    mkdir -p /usr/lib/docker/cli-plugins \
    && case "$TARGETARCH" in \
        amd64) cp /tmp/buildx-amd64 /usr/lib/docker/cli-plugins/docker-buildx ;; \
        arm64) cp /tmp/buildx-arm64 /usr/lib/docker/cli-plugins/docker-buildx ;; \
        *) exit 1 ;; \
    esac \
    && chmod +x /usr/lib/docker/cli-plugins/docker-buildx

# Install docker-compose
RUN --mount=type=bind,source=docker-compose-linux-x86_64,target=/tmp/compose-amd64 \
    --mount=type=bind,source=docker-compose-linux-aarch64,target=/tmp/compose-arm64 \
    mkdir -p /usr/lib/docker/cli-plugins \
    && case "$TARGETARCH" in \
        amd64) cp /tmp/compose-amd64 /usr/lib/docker/cli-plugins/docker-compose ;; \
        arm64) cp /tmp/compose-arm64 /usr/lib/docker/cli-plugins/docker-compose ;; \
        *) exit 1 ;; \
    esac \
    && chmod +x /usr/lib/docker/cli-plugins/docker-compose

# Install uv
RUN --mount=type=bind,source=uv-x86_64-unknown-linux-gnu.tar.gz,target=/tmp/uv-amd64.tar.gz \
    --mount=type=bind,source=uv-aarch64-unknown-linux-gnu.tar.gz,target=/tmp/uv-arm64.tar.gz \
    mkdir -p /tmp/uvx /tmp/uva \
    && tar xzf /tmp/uv-amd64.tar.gz -C /tmp/uvx \
    && tar xzf /tmp/uv-arm64.tar.gz -C /tmp/uva \
    && case "$TARGETARCH" in \
        amd64) cp /tmp/uvx/uv-x86_64-unknown-linux-gnu/* /usr/local/bin/ ;; \
        arm64) cp /tmp/uva/uv-aarch64-unknown-linux-gnu/* /usr/local/bin/ ;; \
        *) exit 1 ;; \
    esac \
    && rm -rf /tmp/uvx /tmp/uva

# Install ruff (Python linter/formatter, used by lefthook pre-commit hooks)
RUN --mount=type=bind,source=ruff-x86_64-unknown-linux-gnu.tar.gz,target=/tmp/ruff-amd64.tar.gz \
    --mount=type=bind,source=ruff-aarch64-unknown-linux-gnu.tar.gz,target=/tmp/ruff-arm64.tar.gz \
    mkdir -p /tmp/ruffx /tmp/ruffa \
    && tar xzf /tmp/ruff-amd64.tar.gz -C /tmp/ruffx \
    && tar xzf /tmp/ruff-arm64.tar.gz -C /tmp/ruffa \
    && case "$TARGETARCH" in \
        amd64) cp /tmp/ruffx/ruff-x86_64-unknown-linux-gnu/* /usr/local/bin/ ;; \
        arm64) cp /tmp/ruffa/ruff-aarch64-unknown-linux-gnu/* /usr/local/bin/ ;; \
        *) exit 1 ;; \
    esac \
    && rm -rf /tmp/ruffx /tmp/ruffa

# Install sqllogictest
RUN --mount=type=bind,source=sqllogictest-bin-v0.29.1-x86_64-unknown-linux-musl.tar.gz,target=/tmp/sql-amd64.tar.gz \
    --mount=type=bind,source=sqllogictest-bin-v0.29.1-aarch64-unknown-linux-musl.tar.gz,target=/tmp/sql-arm64.tar.gz \
    mkdir -p /tmp/sqlx /tmp/sqla \
    && tar xzf /tmp/sql-amd64.tar.gz -C /tmp/sqlx \
    && tar xzf /tmp/sql-arm64.tar.gz -C /tmp/sqla \
    && case "$TARGETARCH" in \
        amd64) cp -rf /tmp/sqlx/sqllogictest /usr/local/bin ;; \
        arm64) cp -rf /tmp/sqla/sqllogictest /usr/local/bin ;; \
        *) exit 1 ;; \
    esac \
    && rm -rf /tmp/sqlx /tmp/sqla

# Install codecov
RUN --mount=type=bind,source=codecovcli_linux,target=/tmp/codecov-amd64 \
    --mount=type=bind,source=codecovcli_linux_aarch64,target=/tmp/codecov-arm64 \
    case "$TARGETARCH" in \
        amd64) cp /tmp/codecov-amd64 /usr/bin/codecov ;; \
        arm64) cp /tmp/codecov-arm64 /usr/bin/codecov ;; \
        *) exit 1 ;; \
    esac \
    && chmod +x /usr/bin/codecov

# Install stripe-cli
RUN --mount=type=bind,source=stripe_1.43.2_linux_x86_64.tar.gz,target=/tmp/stripe-amd64.tar.gz \
    --mount=type=bind,source=stripe_1.43.2_linux_arm64.tar.gz,target=/tmp/stripe-arm64.tar.gz \
    mkdir -p /tmp/stx /tmp/sta \
    && tar xzf /tmp/stripe-amd64.tar.gz -C /tmp/stx \
    && tar xzf /tmp/stripe-arm64.tar.gz -C /tmp/sta \
    && case "$TARGETARCH" in \
        amd64) cp /tmp/stx/stripe /usr/local/bin/ ;; \
        arm64) cp /tmp/sta/stripe /usr/local/bin/ ;; \
        *) exit 1 ;; \
    esac \
    && rm -rf /tmp/stx /tmp/sta

# Install kubectl
RUN --mount=type=bind,source=kubectl-v1.36.1,target=/tmp/kubectl-amd64 \
    --mount=type=bind,source=kubectl-v1.36.1-arm64,target=/tmp/kubectl-arm64 \
    case "$TARGETARCH" in \
        amd64) install -o root -g root -m 0755 /tmp/kubectl-amd64 /usr/local/bin/kubectl ;; \
        arm64) install -o root -g root -m 0755 /tmp/kubectl-arm64 /usr/local/bin/kubectl ;; \
        *) exit 1 ;; \
    esac

# Install tofu
RUN --mount=type=bind,source=tofu_1.12.3_linux_amd64.tar.gz,target=/tmp/tofu-amd64.tar.gz \
    --mount=type=bind,source=tofu_1.12.3_linux_arm64.tar.gz,target=/tmp/tofu-arm64.tar.gz \
    mkdir -p /tmp/tfx /tmp/tfa \
    && tar xzf /tmp/tofu-amd64.tar.gz -C /tmp/tfx \
    && tar xzf /tmp/tofu-arm64.tar.gz -C /tmp/tfa \
    && case "$TARGETARCH" in \
        amd64) cp /tmp/tfx/tofu /usr/local/bin/ ;; \
        arm64) cp /tmp/tfa/tofu /usr/local/bin/ ;; \
        *) exit 1 ;; \
    esac \
    && rm -rf /tmp/tfx /tmp/tfa

# Install lefthook (pre-commit hook runner, drives checks defined in lefthook.yml)
RUN --mount=type=bind,source=lefthook_2.1.10_Linux_x86_64.gz,target=/tmp/lefthook-amd64.gz \
    --mount=type=bind,source=lefthook_2.1.10_Linux_arm64.gz,target=/tmp/lefthook-arm64.gz \
    case "$TARGETARCH" in \
        amd64) gunzip -c /tmp/lefthook-amd64.gz > /usr/local/bin/lefthook ;; \
        arm64) gunzip -c /tmp/lefthook-arm64.gz > /usr/local/bin/lefthook ;; \
        *) exit 1 ;; \
    esac \
    && chmod +x /usr/local/bin/lefthook

# Install cmake 4.4.3 (needed to build certain native dependencies in CI)
RUN --mount=type=bind,source=cmake-4.4.3-linux-x86_64.tar.gz,target=/tmp/cmake-amd64.tar.gz \
    --mount=type=bind,source=cmake-4.4.3-linux-aarch64.tar.gz,target=/tmp/cmake-arm64.tar.gz \
    case "$TARGETARCH" in \
        amd64) tar xzf /tmp/cmake-amd64.tar.gz -C /opt && ln -sf /opt/cmake-4.4.3-linux-x86_64/bin/* /usr/local/bin/ ;; \
        arm64) tar xzf /tmp/cmake-arm64.tar.gz -C /opt && ln -sf /opt/cmake-4.4.3-linux-aarch64/bin/* /usr/local/bin/ ;; \
        *) exit 1 ;; \
    esac

# Copy NLTK data
COPY nltk_data /usr/share/nltk_data

# Pre-extract native static libraries for Go build (pdfium, pdf_oxide, office_oxide).
# build.sh checks /opt/ragflow-native-libs/ first before attempting network download.
# Both architectures' archives are baked into the build context; the right one
# is selected per TARGETARCH so a single image tag serves amd64 and arm64.
COPY pdfium-linux-x64-static.tgz pdfium-linux-arm64-static.tgz \
     pdf_oxide-go-ffi-linux-amd64.tar.gz pdf_oxide-go-ffi-linux-arm64.tar.gz \
     office_oxide-linux-x86_64.tar.gz office_oxide-linux-aarch64.tar.gz \
     onnxruntime-linux-x64-static_lib-1.23.2-glibc2_28.zip onnxruntime-linux-aarch64-static_lib-1.23.2-glibc2_28.zip \
     onnxruntime-v1.29.0-linux-x86_64.zip onnxruntime-v1.29.0-linux-aarch64.zip /tmp/
RUN mkdir -p /opt/ragflow-native-libs/pdfium-static /opt/ragflow-native-libs/pdf_oxide /opt/ragflow-native-libs/office_oxide && \
    case "$TARGETARCH" in \
        amd64) \
            tar xzf /tmp/pdfium-linux-x64-static.tgz -C /opt/ragflow-native-libs/pdfium-static && \
            tar xzf /tmp/pdf_oxide-go-ffi-linux-amd64.tar.gz -C /opt/ragflow-native-libs/pdf_oxide && \
            [ "$(strings /opt/ragflow-native-libs/pdf_oxide/lib/linux_amd64/libpdf_oxide.a 2>/dev/null | grep -oE 'pdf_oxide [0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d' ' -f2)" = "0.3.73" ] || \
                (echo "ERROR: pdf_oxide version mismatch (amd64), expected v0.3.73; run: rm pdf_oxide-go-ffi-linux-amd64.tar.gz && uv run download_deps.py" && exit 1) && \
            tar xzf /tmp/office_oxide-linux-x86_64.tar.gz -C /opt/ragflow-native-libs/office_oxide && \
            strings /opt/ragflow-native-libs/office_oxide/lib/liboffice_oxide.a 2>/dev/null | grep -Fxq "0.1.12" || \
                (echo "ERROR: office_oxide version mismatch (amd64), expected v0.1.12; run: rm office_oxide-linux-x86_64.tar.gz && uv run download_deps.py" && exit 1) ;; \
        arm64) \
            tar xzf /tmp/pdfium-linux-arm64-static.tgz -C /opt/ragflow-native-libs/pdfium-static && \
            tar xzf /tmp/pdf_oxide-go-ffi-linux-arm64.tar.gz -C /opt/ragflow-native-libs/pdf_oxide && \
            [ "$(strings /opt/ragflow-native-libs/pdf_oxide/lib/linux_arm64/libpdf_oxide.a 2>/dev/null | grep -oE 'pdf_oxide [0-9]+\.[0-9]+\.[0-9]+' | head -1 | cut -d' ' -f2)" = "0.3.73" ] || \
                (echo "ERROR: pdf_oxide version mismatch (arm64), expected v0.3.73; run: rm pdf_oxide-go-ffi-linux-arm64.tar.gz && uv run download_deps.py" && exit 1) && \
            tar xzf /tmp/office_oxide-linux-aarch64.tar.gz -C /opt/ragflow-native-libs/office_oxide && \
            strings /opt/ragflow-native-libs/office_oxide/lib/liboffice_oxide.a 2>/dev/null | grep -Fxq "0.1.12" || \
                (echo "ERROR: office_oxide version mismatch (arm64), expected v0.1.12; run: rm office_oxide-linux-aarch64.tar.gz && uv run download_deps.py" && exit 1) ;; \
        *) echo "ERROR: unsupported TARGETARCH=$TARGETARCH" && exit 1 ;; \
    esac && \
    rm /tmp/pdfium-linux-*.tgz /tmp/pdf_oxide-go-ffi-linux-*.tar.gz /tmp/office_oxide-linux-*.tar.gz

# onnxruntime static libs, baked into /opt (like the other native libs);
# build.sh seeds it to the user cache at build/test time via _seed_from_system,
# so CI never downloads it. 1.23.2 is consumed by the Python DeepDoc pipeline;
# 1.29.0 is the Go in-process backend (mirrors DeepDocORTVersion). The two are
# extracted into separate version-stamped dirs under static_lib.
RUN mkdir -p /opt/ragflow-native-libs/onnxruntime/static_lib && \
    case "$TARGETARCH" in \
        amd64) \
            python3 -c "import zipfile; zipfile.ZipFile('/tmp/onnxruntime-linux-x64-static_lib-1.23.2-glibc2_28.zip').extractall('/opt/ragflow-native-libs/onnxruntime/static_lib')" && \
            python3 -c "import zipfile,shutil,os; \
              z=zipfile.ZipFile('/tmp/onnxruntime-v1.29.0-linux-x86_64.zip'); \
              z.extractall('/opt/ragflow-native-libs/onnxruntime/static_lib'); z.close(); \
              src='/opt/ragflow-native-libs/onnxruntime/static_lib/onnxruntime-v1.29.0-linux-x86_64'; \
              dst='/opt/ragflow-native-libs/onnxruntime/static_lib/onnxruntime-linux-x64-static_lib-1.29.0-glibc2_28'; \
              (os.path.exists(dst) and shutil.rmtree(dst)); os.rename(src,dst)" ;; \
        arm64) \
            python3 -c "import zipfile; zipfile.ZipFile('/tmp/onnxruntime-linux-aarch64-static_lib-1.23.2-glibc2_28.zip').extractall('/opt/ragflow-native-libs/onnxruntime/static_lib')" && \
            python3 -c "import zipfile,shutil,os; \
              z=zipfile.ZipFile('/tmp/onnxruntime-v1.29.0-linux-aarch64.zip'); \
              z.extractall('/opt/ragflow-native-libs/onnxruntime/static_lib'); z.close(); \
              src='/opt/ragflow-native-libs/onnxruntime/static_lib/onnxruntime-v1.29.0-linux-aarch64'; \
              dst='/opt/ragflow-native-libs/onnxruntime/static_lib/onnxruntime-linux-aarch64-static_lib-1.29.0-glibc2_28'; \
              (os.path.exists(dst) and shutil.rmtree(dst)); os.rename(src,dst)" ;; \
        *) exit 1 ;; \
    esac && \
    rm /tmp/onnxruntime-*.zip

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

RUN --mount=type=bind,source=actions-runner-linux-x64-2.337.0.tar.gz,target=/tmp/runner-amd64.tar.gz \
    --mount=type=bind,source=actions-runner-linux-arm64-2.337.0.tar.gz,target=/tmp/runner-arm64.tar.gz \
    cd /home/alice \
    && mkdir actions-runner \
    && cd actions-runner \
    && case "$TARGETARCH" in \
        amd64) tar xzf /tmp/runner-amd64.tar.gz ;; \
        arm64) tar xzf /tmp/runner-arm64.tar.gz ;; \
        *) exit 1 ;; \
    esac \
    && sudo bin/installdependencies.sh

COPY start.sh start.sh

# make the script executable
RUN sudo chmod +x start.sh

ENTRYPOINT ["./start.sh"]
