# github-runner-dockerfile
Dockerfile for the creation of a GitHub Actions runner image to be deployed dynamically. [Find the full explanation and tutorial here](https://baccini-al.medium.com/creating-a-dockerfile-for-dynamically-creating-github-actions-self-hosted-runners-5994cc08b9fb).

To build the runner image:

```
# 1. (one-time, on the image-build host) Fetch the version-keyed native-lib cache
#    that ragflow's downloader produces (~/ragflow-native-libs/<lib>/v<version>/),
#    then drop that dir into THIS build context. This is what the runner image
#    ships for the Go build / CI — versions auto-align with ragflow, no manual
#    URL / dir / assertion sync across repos (see ragflow PR #22099).
$ cd <ragflow> && uv run tools/scripts/download_dev_deps.py
$ cp -r ~/ragflow-native-libs <this-repo>/ragflow-native-libs
# 2. Fetch the remaining build tools / DeepDoc models / nltk data.
$ uv run download_deps.py
# 3. Build.
$ docker build --build-arg NEED_MIRROR=1 -t infiniflow/github_action_runner .
```

> Note: `download_deps.py` here no longer fetches the native `*.a` libs
> (pdfium / pdf_oxide / office_oxide / ORT 1.29.0); only ONNX Runtime 1.23.2 is
> still fetched, kept solely for the legacy Python DeepDoc pipeline. The rest are
> supplied via the `ragflow-native-libs/` cache copied in step 1.

When running the docker image, or when executing docker compose, environment variables for repo-owner/repo-name and github-token must be included. 

Credit to [testdriven.io](https://testdriven.io/blog/github-actions-docker/) for the original start.sh script, which I slightly modified to make it work with a regular repository rather than with an enterprise. 

Whene generating your GitHub PAT you will need to include `repo`, `workflow`, and `admin:org` permissions.

A sample `.env` looks like:

```
REPO=infiniflow/ragflow
MY_GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EXTRA_LABELS=overseas
HOST_HOSTNAME=ragflow04
RUNNER_WORKSPACE_PREFIX=/opt/runners_work
TZ=Asia/Shanghai
KUBE_CONFIG_PATH=/home/infiniflow/.kube/config
```

If the runner needs Kubernetes access, store a valid kubeconfig on the host and expose it with `KUBE_CONFIG_PATH`. The runner will mount that file read-only and export both `KUBECONFIG` and `KUBE_CONFIG` from it at startup.

To start the runner:

```
$ docker compose up -d
```

# Alternatives
- https://github.com/myoung34/docker-github-actions-runner
- https://github.com/actions/runner/blob/v2.330.0/images/Dockerfile
- https://github.com/actions/runner-images
