# Offline Docker Stack Archive

This directory contains everything needed to restore the Docker environment on another machine without an Internet connection.

## Contents

* `stacks/`  — Docker Compose projects, configuration, and persistent data.
* `images/` — Docker images saved as `.tar` archives, plus helper scripts to save and load them.
* `install/` — Offline Docker installation scripts and required packages.
* `compose.sh` — Runs `docker compose` commands across all detected Compose projects.
* `backup.sh` — Creates a backup archive of this directory.
* `readme.md` — This document.

## Restoring the Environment

### 1. Extract the archive

```bash
tar xzf docker_YYYYMMDD_HHMMSS.tar.gz -C ~/
```

The directory should be restored as:

```text
~/docker/
```

### 2. Install Docker (if needed)

```bash
cd ~/docker/install
sudo ./dockerinstall.sh
```

If Docker is already installed, this step can be skipped.

### 3. Load the Docker images

```bash
cd ~/docker/images
./load-images.sh
```

This imports all saved images into the local Docker image cache.

### 4. Start all services

```bash
cd ~/docker
./compose.sh up -d
```

The script automatically discovers Compose projects and runs the command in each one.

## Common Commands

Start all stacks:

```bash
./compose.sh up -d
```

Stop all stacks:

```bash
./compose.sh down
```

Restart all stacks:

```bash
./compose.sh restart
```

Pull updated images:

```bash
./compose.sh pull
```

View running containers:

```bash
docker ps
```

List available images:

```bash
docker images
```

## Notes

* The repository is designed to be portable and work completely offline after extraction.
* Persistent application data is stored alongside each Compose project.
* Docker images are restored from the `images/` directory, so no Internet connection is required.
