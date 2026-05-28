# 🚀 Quickstart: Booting the Stack on macOS, Linux, and Windows

This guide helps you set up the Dockerized Zend Framework stack on the three most common operating systems: **macOS**, **Linux (Ubuntu/Debian)**, and **Windows**.

---

## 📋 Common Prerequisites

Before starting, ensure you have:
1. **Git** installed on your host system.
2. **Docker** and **Docker Compose** (included automatically in Docker Desktop).

---

## 🍎 1. macOS Setup

### Step A: Install Docker
- Download and install [Docker Desktop for Mac](https://www.docker.com/products/docker-desktop/) (choose Apple Silicon or Intel Chip version depending on your hardware).
- Launch Docker Desktop and accept the terms of service.

### Step B: Install GNU Make
macOS includes `make` via the Xcode Command Line Tools.
- Open your terminal and run:
  ```bash
  xcode-select --install
  ```
- Click **Install** on the popup dialog box.

### Step C: Run the Stack
- Clone the repository and navigate into the folder:
  ```bash
  git clone <repository-url> project-folder
  cd project-folder
  ```
- Copy your legacy codebase into `docroot/` (see [Dockerization Guide](file:///home/pinano/Documents/webroot/pinano-zend-app-dockerized/docs/dockerizing-legacy-app.md)).
- Run the setup tool to create `index.php`:
  ```bash
  make setup-index
  ```
- Start the containers:
  ```bash
  make start
  ```

---

## 🐧 2. Linux Setup (Ubuntu / Debian)

### Step A: Install Docker & Docker Compose
- Install Docker Engine and the Docker Compose plugin using the official guide or via helper commands:
  ```bash
  sudo apt-get update
  sudo apt-get install docker.io docker-compose-v2 -y
  ```
- Ensure the Docker service is running:
  ```bash
  sudo systemctl enable --now docker
  ```

### Step B: Configure Docker Permissions (Rootless Group)
To avoid running every `make` or `docker` command with `sudo`, add your user to the docker group:
- Run:
  ```bash
  sudo usermod -aG docker $USER
  ```
- **Crucial:** Log out and log back in, or run `newgrp docker` to apply the group membership changes to your current terminal session.

### Step C: Install GNU Make
- Install the development tools including `make`:
  ```bash
  sudo apt-get install build-essential -y
  ```

### Step D: Run the Stack
- Clone the repo, place your code in `docroot/`, and run:
  ```bash
  make setup-index
  make start
  ```

---

## 🏁 3. Windows Setup

For Windows development, **WSL2 (Windows Subsystem for Linux)** is highly recommended due to the I/O requirements of legacy PHP frameworks. Native Windows bind mounts (VirtualBox or Hyper-V) can suffer from major performance bottlenecks when handling hundreds of PHP includes.

---

### 🌟 Option A: Using WSL2 (Highly Recommended)

#### Step A: Install WSL2 & Ubuntu
- Open PowerShell or Windows Command Prompt as Administrator and run:
  ```cmd
  wsl --install
  ```
- Restart your computer when prompted.
- Set up your Ubuntu username and password when the Ubuntu terminal opens.

#### Step B: Install Docker Desktop & Connect WSL2
- Download and install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/).
- Open Docker Desktop Settings -> **General** -> Ensure **Use the WSL 2 based engine** is checked.
- Go to Settings -> **Resources** -> **WSL integration** -> Enable integration for your default Ubuntu distro.

#### Step C: Clone & Run inside the WSL2 Filesystem (ext4)
> [!IMPORTANT]
> **Performance Tip:** Do NOT clone the repository inside the Windows directory structure (e.g. `/mnt/c/Users/...`). Instead, clone it directly into your WSL2 home directory (e.g. `/home/ubuntu/...`) to bypass Windows file sharing overhead.

- Open your Ubuntu WSL2 terminal and run:
  ```bash
  sudo apt-get update && sudo apt-get install build-essential -y
  git clone <repository-url> project-folder
  cd project-folder
  ```
- Place your code in `docroot/` inside the WSL2 system.
- Run setup and start:
  ```bash
  make setup-index
  make start
  ```

---

### ⚙️ Option B: Native Windows (Git Bash + Make)

If you must run the stack directly inside the native Windows filesystem without WSL2:

#### Step A: Install Git & Git Bash
- Download and install [Git for Windows](https://gitforwindows.org/). This provides the **Git Bash** terminal emulator.

#### Step B: Install Make for Windows
- Download the `make` executable from [EzWinPorts](https://sourceforge.net/projects/ezwinports/files/) or use a package manager like [Chocolatey](https://chocolatey.org/):
  ```cmd
  choco install make
  ```
- Alternatively, you can use the docker-compose commands directly instead of the Makefile (e.g. `docker compose up -d` instead of `make start`).

#### Step C: Run the Stack
- Open a **Git Bash** terminal window.
- Clone the repository and navigate inside the folder.
- Run setup and start:
  ```bash
  make setup-index
  make start
  ```

---

## 🚦 Verification & Basic Troubleshooting

Once you run `make start`, you can check the container status by running:
```bash
make status
```

### Accessing the Web Interface
- If you have a Traefik reverse proxy running on your host, access the app at `http://app-project.localhost` (or your custom domain).
- If running standalone, map the port in `docker-compose.yml` (e.g. `ports: ["8080:8080"]`) and access:
  ```
  http://localhost:8080
  ```
