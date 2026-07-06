# Offline Docker Stack Archive

This repository contains everything required to restore a complete Docker environment on another machine, including Docker itself, Docker images, Compose projects, and persistent application data.

The archive is designed to work completely offline after extraction.

## Contents

* `stacks/` — Docker Compose projects, configuration, and persistent application data.
* `images/` — Docker images saved as `.tar` archives, plus helper scripts to save and load them.
* `install/` — Offline Docker installation scripts and required packages for supported Ubuntu and Debian releases.
* `compose.sh` — Runs `docker compose` commands across all detected Compose projects.
* `backup.sh` — Creates a complete backup archive of this repository.
* `deploy.sh` — Installs Docker (if required), loads Docker images, and starts all Compose stacks.
* `backup-restore.sh` — Verifies and extracts a backup archive.
* `readme.md` — This document.

---

## Creating a Backup

```bash
sudo ./backup.sh
```

The backup process:

* Saves the current Docker images.
* Stops all Docker stacks cleanly.
* Creates a compressed archive of the entire `docker/` directory.
* Generates a SHA-256 checksum.
* Keeps the newest three backups.
* Restarts all Docker stacks automatically.

Each backup is completely self-contained and can be restored without Internet access.

---

## Recovering a Backup

`backup-restore.sh` is intended to be stored alongside the backup archives.

Run it without arguments to choose a backup interactively:

```bash
bash backup-restore.sh
```

Or restore a specific archive:

```bash
bash backup-restore.sh docker_YYYYMMDD_HHMMSS.tar.zst
```

The script will:

* Verify the SHA-256 checksum.
* Ask for confirmation before overwriting the destination.
* Extract the archive into:

```text
~/docker-restored/docker_YYYYMMDD_HHMMSS/
```

---

## Deploying the Restored Environment

After extraction:

```bash
cd ~/docker-restored/docker_YYYYMMDD_HHMMSS/docker
./deploy.sh
```

The deployment script automatically:

1. Installs or upgrades Docker using the offline packages (if required).
2. Loads all archived Docker images.
3. Starts every Docker Compose project.

---

## Updating Offline Docker Packages

To refresh the offline Docker installation packages:

```bash
cd install
./update-offline-packages.sh
```

Packages are stored by operating system, architecture, and distribution codename:

```text
install/packages/
├── ubuntu/
│   └── amd64/
│       └── noble/
└── debian/
    └── amd64/
        └── bookworm/
```

This makes it possible to maintain offline installers for multiple supported systems in the same repository.

---

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

---

## Notes

* The repository is intended to be the source of truth for the Docker environment.
* Docker images are archived separately so deployments work without Internet access.
* Persistent application data is stored alongside each Compose project.
* Backup archives include the complete repository, making each snapshot portable and self-contained.
