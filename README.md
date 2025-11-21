# github-runner-dockerfile
Dockerfile for the creation of a GitHub Actions runner image to be deployed dynamically. [Find the full explanation and tutorial here](https://baccini-al.medium.com/creating-a-dockerfile-for-dynamically-creating-github-actions-self-hosted-runners-5994cc08b9fb).

To build the runner image:

```
$ curl -O -L https://github.com/actions/runner/releases/download/v2.330.0/actions-runner-linux-x64-2.330.0.tar.gz
$ curl -O -L https://download.docker.com/linux/static/stable/x86_64/docker-29.0.2.tgz
$ curl -O -L https://github.com/docker/buildx/releases/download/v0.30.1/buildx-v0.30.1.linux-amd64
# curl -O -L https://github.com/docker/compose/releases/download/v2.40.3/docker-compose-linux-x86_64
$ curl -Os https://cli.codecov.io/latest/linux/codecov
$ docker build --build-arg NEED_MIRROR=1 -t infiniflow/github_action_runner .
```

When running the docker image, or when executing docker compose, environment variables for repo-owner/repo-name and github-token must be included. 

Credit to [testdriven.io](https://testdriven.io/blog/github-actions-docker/) for the original start.sh script, which I slightly modified to make it work with a regular repository rather than with an enterprise. 

Whene generating your GitHub PAT you will need to include `repo`, `workflow`, and `admin:org` permissions.

A sample `.env` looks like:

```
REPO=infiniflow/ragflow
TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EXTRA_LABELS=overseas
HOST_HOSTNAME=ragflow04
RUNNER_WORKSPACE_PREFIX=/opt/runners_work
TZ=Asia/Shanghai
```

To start the runner:

```
$ docker compose up -d
```

# Alternatives
- https://github.com/myoung34/docker-github-actions-runner
- https://github.com/actions/runner/blob/v2.330.0/images/Dockerfile
- https://github.com/actions/runner-images
