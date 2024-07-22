FROM ubuntu:24.04

ARG RUNNER_VERSION="2.317.0"

# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt upgrade -y && useradd -m alice
RUN apt install -y --no-install-recommends \
    curl jq build-essential libssl-dev libffi-dev libicu-dev python3 python3-venv python3-dev python3-pip

RUN apt install -y --no-install-recommends \
    sudo docker.io git gawk sed wget

RUN cd /home/alice && mkdir actions-runner && cd actions-runner \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

RUN chown -R alice ~alice && /home/alice/actions-runner/bin/installdependencies.sh
RUN echo "alice      ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/alice

RUN --mount=type=bind,source=rwlock.cpp,target=/rwlock.cpp g++ -o /usr/local/bin/rwlock /rwlock.cpp -lrt -lpthread

COPY start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# since the config and run script for actions are not allowed to be run by root,
# set the user to "alice" so all subsequent commands are run as the alice user
USER alice
ENV USER=alice

ENTRYPOINT ["./start.sh"]
