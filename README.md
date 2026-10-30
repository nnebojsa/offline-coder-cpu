# offline-coder-cpu

Local AI environment for programming that works without an internet
connection. The models run on the CPU of the local machine in rootless
Podman containers. Open WebUI is the only user interface. It provides
projects (folders), custom system prompts, attached knowledge and memory,
similar to cloud chat services.

This version is designed for a notebook with 4 CPU cores and no dedicated
GPU (e.g. HP EliteBook 850 G8, i5-1135G7 with 16 GB of RAM).

A German version of this description is available in [README_de.md](README_de.md).

## 1. What it is

offline-coder-cpu consists of two containers, optionally three:

| Container                 | Purpose                                                              |
|---------------------------|----------------------------------------------------------------------|
| `offline-coder-cpu-webui` | Open WebUI, the web interface in the browser                         |
| `offline-coder-cpu-chat`  | llama-server (llama.cpp) with the chat model                         |
| `offline-coder-cpu-fim`   | optional: llama-server for code completion in VS Code (llama-vscode) |

Architecture:

```
Browser --> 127.0.0.1:3000 --> [ webui ] --> offline-coder-cpu-chat:8080
                                                (container network only)
VS Code --> 127.0.0.1:8012 --> [ fim ]          (only with AUTOCOMPLETE=1)
```

The chat container has no port on the host and no web interface of its
own. It is reachable only by Open WebUI.

## 2. What it does

- Chat with a local language model, also without a network connection.
  The default with 16 GB of RAM is Qwen3.5-9B, with 64 GB Qwen3.6-35B-A3B
  (selection see section 9).
- **Projects in Open WebUI:** folders with their own system prompt and
  attached knowledge. New chats in a folder inherit these settings.
- **Files and knowledge bases:** texts and source code are split into chunks
  and searched locally. The required embedding model is taken over from the
  Open WebUI image during setup.
- **No data leaves the machine:** models are downloaded once on the host.
  Afterwards llama-server (`--offline`) and Open WebUI (`OFFLINE_MODE`) work
  without internet access. Telemetry and update checks are disabled.
- By default, all ports are bound to `127.0.0.1` only.
- **Encrypted storage:** `setup.sh` checks whether the Open WebUI data and
  the project directory are located on a LUKS/dm-crypt encrypted device
  (`REQUIRE_ENCRYPTION`).

## 3. Requirements

### Hardware

- **Memory:** at least 16 GB. With 16 GB, a model of the 9B class with a 16K
  context is usable, but tight next to the desktop, a browser and VS Code.
  The MoE models from section 9 require 64 GB.
- **CPU:** x86_64 with AVX2 (recommended) or aarch64, at least 4 cores. On
  the CPU, memory bandwidth limits the speed, two RAM modules (dual channel)
  are considerably faster than one.
- **Disk space** in the project directory:

| Size           | Used for                                        |
|----------------|-------------------------------------------------|
| 6 - 34 GB      | chat model, depending on the selection (sec. 9) |
| approx. 2 GB   | model for code completion (optional)            |
| 2 GB or more   | Open WebUI data (grows with chats and uploads)  |

  When changing the model, the old and the new model temporarily exist side
  by side. The images (approx. 8 GB) are stored in the user's Podman storage
  (default: `~/.local/share/containers/storage`, `./setup.sh --check` shows
  the exact path).

### Encryption

Chats, uploads and knowledge are stored in the project directory
(`data/webui/`). The project therefore belongs on a LUKS-encrypted device,
e.g. a separate partition such as `/DATA` that is unlocked at boot by a key
file stored on the encrypted root partition (entries in `/etc/crypttab` and
`/etc/fstab`), or the home directory on an encrypted root partition.

With `REQUIRE_ENCRYPTION=1` (default), `setup.sh` aborts if the data is
located on an unencrypted device.

### Software

- Linux (designed for Linux Mint 22 / Ubuntu 24.04)
- Podman 4.0 or later, set up rootless (entries in `/etc/subuid` and
  `/etc/subgid` for the user)
- Network backend netavark with aardvark-dns
- podman-compose (recommended) or docker-compose v2 with an active Podman
  socket
- curl, coreutils, gawk, sed, grep, iproute2 (`ss`), util-linux (`lsblk`,
  `findmnt`)
- git (for cloning the repository)

Installation on Debian/Ubuntu/Mint:

```
sudo apt install podman podman-compose aardvark-dns curl iproute2 git
```

### Network

Only for the initial setup and for updates: access to `huggingface.co`
(models) and `ghcr.io` (images).

`setup.sh` checks all of these points before anything is changed.

## 4. Files

| File            | Purpose                                              |
|-----------------|------------------------------------------------------|
| `README.md`     | this description (English)                           |
| `README_de.md`  | description in German                                |
| `.gitignore`    | Git exclusions (models, data, keys, logs)            |
| `setup.conf`    | configuration with defaults (paths, ports, models)   |
| `setup.sh`      | requirement checks and setup                         |
| `ctl.sh`        | day-to-day operation (start, stop, status, logs)     |
| `cleanup.sh`    | complete removal                                     |
| `common.sh`     | shared functions of the scripts                      |
| `compose.yaml`  | container definitions                                |
| `Dockerfile`    | image for llama-server                               |
| `entrypoint.sh` | start script of llama-server inside the container    |

Generated by `setup.sh` (not to be edited manually):

| File / directory         | Content                                            |
|--------------------------|----------------------------------------------------|
| `.env`                   | values for compose.yaml, generated from setup.conf |
| `.webui_secret`          | session key for Open WebUI                         |
| `.offline-coder-cpu.log` | output of build and compose                        |
| `models/`                | models (default path)                              |
| `data/webui/`            | Open WebUI data (default path)                     |

None of these files belong in the repository, `.gitignore` excludes them.

## 5. Setup

Prerequisite: the target directory is located on a LUKS-encrypted, mounted
device. The path can be chosen freely, the example uses
`/DATA/offline-coder-cpu`.

```
TARGET=/DATA/offline-coder-cpu    # insert your own path
git clone https://github.com/<user>/offline-coder-cpu.git "$TARGET"
cd "$TARGET"
vim setup.conf          # optional, the defaults fit 16 GB of RAM
./setup.sh --check      # checks only
./setup.sh              # set up and start
```

`<user>` is the GitHub account that hosts the repository. If the parent
directory is owned by root (e.g. `/DATA`), the target directory is created
beforehand and handed over to the user:

```
sudo install -d -o "$USER" -g "$USER" "$TARGET"
```

Afterwards the interface is available at <http://127.0.0.1:3000>. The first
account created there becomes the administrator. The account is local and is
stored in `data/webui/webui.db`.

`setup.sh` can be run repeatedly. Existing models are not downloaded again,
interrupted downloads are resumed. The containers are recreated on every
run, data and models are preserved.

| Option                  | Effect                                      |
|-------------------------|---------------------------------------------|
| `./setup.sh --check`    | check requirements and configuration only   |
| `./setup.sh --no-start` | set up without starting the containers      |
| `./setup.sh --update`   | additionally pull the latest images         |

## 6. Configuration (setup.conf)

All values are documented in `setup.conf` (comments in German). After every
change:

```
./setup.sh
```

The most important values:

| Key                      | Meaning                                            |
|--------------------------|----------------------------------------------------|
| `MODELS_DIR`             | model storage (default: `./models`)                |
| `WEBUI_DATA_DIR`         | Open WebUI data (default: `./data/webui`)          |
| `BIND_ADDRESS`           | `127.0.0.1` = reachable locally only               |
| `WEBUI_PORT`             | port of the interface (default: 3000)              |
| `WEBUI_IMAGE`            | Open WebUI version                                 |
| `WEBUI_AUTH`             | 1 = login, 0 = no login (fresh installs only)      |
| `WEBUI_OFFLINE`          | 1 = no downloads by Open WebUI                     |
| `WEBUI_TITLE_GENERATION` | automatic chat titles generated by the model       |
| `WEBUI_BACKGROUND_TASKS` | tags, follow-up questions, search queries          |
| `CHAT_MODEL_REPO/_FILE`  | chat model on Hugging Face                         |
| `CHAT_CTX`               | context size in tokens                             |
| `CHAT_SAMPLING`          | sampling profile: qwen, qwen-coder, gemma, default |
| `CHAT_ALIAS`             | model name shown in Open WebUI                     |
| `CHAT_THREADS`           | CPU threads, `auto` = physical cores               |
| `CHAT_THINKING`          | thinking mode (slower, more thorough)              |
| `AUTOCOMPLETE`           | 1 = container for VS Code code completion          |
| `MIN_RAM_GB`             | minimum RAM for the check (default: 16)            |
| `RESERVED_RAM_GB`        | RAM for system, desktop, browser, VS Code (6)      |
| `REQUIRE_ENCRYPTION`     | 1 = abort if the storage is not encrypted          |

> **Note on Open WebUI:** values such as title generation, background tasks
> or the default model are applied by Open WebUI only on the first start.
> Afterwards the settings in the admin panel take precedence. With
> `WEBUI_CONFIG_FROM_ENV=1` the values from `setup.conf` apply on every
> start, but changes made in the admin panel are then lost on restart.

## 7. Operation

| Command             | Effect                                          |
|---------------------|-------------------------------------------------|
| `./ctl.sh start`    | start, e.g. after a reboot of the machine       |
| `./ctl.sh stop`     | stop, the memory is released                    |
| `./ctl.sh restart`  | stop and start again                            |
| `./ctl.sh status`   | state, readiness, RAM and CPU usage             |
| `./ctl.sh logs chat`| log of the chat container (also: webui, fim)    |

After a reboot the containers do not start automatically, they are started
with `./ctl.sh start`. Loading the model takes between 20 seconds and a few
minutes, depending on its size.

## 8. Projects in Open WebUI

- Create a new folder in the sidebar, then use **Edit** in the folder menu to
  set name, system prompt and knowledge.
- Knowledge is created under **Workspace > Knowledge**: upload files there
  and assign the knowledge base to the folder.
- Chats in this folder automatically receive the system prompt and the
  knowledge.

Recommendations for CPU operation:

- One new chat per topic. The entire history is sent with every answer and
  increases the waiting time.
- For knowledge bases, the standard search (RAG) is preferable to the full
  context mode. Full context quickly exceeds `CHAT_CTX`.
- Few, targeted files per project.

## 9. Models and changing the model

`setup.conf` contains a block of four lines for each model
(`CHAT_MODEL_REPO`, `CHAT_MODEL_FILE`, `CHAT_CTX`, `CHAT_SAMPLING`). Exactly
one block is active.

| Model            | Vendor  | Total / active | File          | RAM   | Use                              |
|------------------|---------|----------------|---------------|-------|----------------------------------|
| Qwen3.5-9B       | Alibaba | 9B (dense)     | approx. 6 GB  | 16 GB | default with 16 GB of RAM        |
| Qwen3.6-35B-A3B  | Alibaba | 35B / 3B       | approx. 21 GB | 64 GB | default with 64 GB of RAM        |
| Gemma 4 26B-A4B  | Google  | 25B / 3.8B     | approx. 16 GB | 64 GB | alternative for comparison       |
| Qwen3-Coder-Next | Alibaba | 80B / 3B       | approx. 34 GB | 64 GB | coding specialist, 3-bit, tight  |

All models are licensed under Apache 2.0. On the CPU, only models with few
active parameters per token are fast enough, which is why dense models such
as Qwen3.8-27B are not included. Qwen3-Coder-Next needs about 34 GB for the
model file alone and is only useful when few other programs are running. It
has no thinking mode.

Changing the model, e.g. after a RAM upgrade to 64 GB:

1. In `setup.conf`, comment out the block "16 GB RAM: Standard" and activate
   the block "64 GB RAM: Standard".
2. `./setup.sh --check`, then `./setup.sh`.

The model is downloaded and the containers are recreated. The model name in
Open WebUI (`CHAT_ALIAS`) stays the same, so projects and the default model
still match. The previously used model file can then be deleted from
`MODELS_DIR`.

`setup.sh` warns if `CHAT_SAMPLING` does not match the model and estimates
the RAM requirement (model, context, Open WebUI and `RESERVED_RAM_GB`).

## 10. Code completion in VS Code (optional)

```
# AUTOCOMPLETE=1 in setup.conf, then:
./setup.sh
code --install-extension ggml-org.llama-vscode
```

The extension uses `http://127.0.0.1:8012` by default. The extension's offer
to install llama.cpp is to be declined, since the server already runs in the
container. Requires approx. 2 GB of additional RAM.

## 11. Offline operation and data protection

- After setup, no internet connection is required.
- `OFFLINE_MODE` and `--offline` prevent downloads but do not block
  connections. A strict separation requires firewall rules.
- Chats and uploaded files are stored in `WEBUI_DATA_DIR`. Sensitive content
  (e.g. logs containing personal data) should be deleted after analysis.
- `WEBUI_DATA_DIR` and the session key `.webui_secret` are located in the
  project directory on the encrypted device. With the machine switched off,
  they cannot be read without the passphrase. While the machine is running,
  they are accessible like any other file.
- Whether confidential data may be processed on the machine is governed by
  internal policies, even if the model runs locally.

## 12. Updates

```
./setup.sh --update
```

Pulls the Open WebUI image specified in `WEBUI_IMAGE` and the llama.cpp base
image again and rebuilds the llama-server image. For a new Open WebUI
version, adjust `WEBUI_IMAGE` in `setup.conf` first. Before a version change,
a backup of `WEBUI_DATA_DIR` with stopped containers (`./ctl.sh stop`) is
recommended.

## 13. Removal

| Command                       | Effect                       |
|-------------------------------|------------------------------|
| `./cleanup.sh`                | remove everything            |
| `./cleanup.sh --keep-models`  | keep the models              |
| `./cleanup.sh --keep-data`    | keep the Open WebUI data     |
| `./cleanup.sh -y`             | no confirmation prompt       |

Removes containers, pod, network, images, models, the Open WebUI data and the
generated files. If containers are still running, they are listed and a
confirmation prompt (y/n) follows. Without running containers, removal
proceeds without a prompt. The project files themselves are preserved.

If `MODELS_DIR` is located outside the project directory, only the configured
model files are deleted there, not the whole directory.

## 14. Troubleshooting

**Requirement check**

```
./setup.sh --check
```

**Logs**

```
./ctl.sh logs chat
./ctl.sh logs webui
less .offline-coder-cpu.log
```

**Model does not appear in Open WebUI**

The chat container is still loading the model. `./ctl.sh status` shows
whether it is ready. Reload the page afterwards.

**"aardvark pid not found" or Open WebUI cannot reach the chat**

```
podman rm -f offline-coder-cpu-chat offline-coder-cpu-webui offline-coder-cpu-fim
podman network rm offline-coder-cpu_default
rm -rf /run/user/$(id -u)/containers/networks/aardvark-dns
./setup.sh
```

**Error "context size exceeded" in the chat**

History and attachments are larger than `CHAT_CTX`. Start a new chat, attach
fewer files or increase `CHAT_CTX` (requires more RAM).

**Answers are cut off after a few minutes**

Increase `WEBUI_REQUEST_TIMEOUT` in `setup.conf`, then run `./setup.sh`.

**"liegt auf einem unverschlüsselten Datenträger" (unencrypted device)**

The device holding the project directory is not LUKS-encrypted. Check in the
project directory:

```
findmnt --target .
lsblk -f
```

Expected: the source is a device below `/dev/mapper/`, and `lsblk -f` shows
a partition of type `crypto_LUKS` above it.

**How fast is the model?**

After every answer, `./ctl.sh logs chat` shows the values `prompt eval`
(reading the prompt) and `eval` (writing the answer) in tokens per second.
