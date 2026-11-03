# Offline Packages

If the Azure VM has zero egress (no internet at all), prepare these on a
connected machine and transfer via USB or Azure Bastion file copy.

## Required packages

```bash
# Node.js LTS binary
wget https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-x64.tar.xz

# npm packages (from src/app/)
cd src/app && npm pack --pack-destination ../../offline-packages/

# Azure CLI container image
docker pull mcr.microsoft.com/azure-cli:latest
docker save mcr.microsoft.com/azure-cli:latest > az-cli.tar

# Azure Developer CLI
curl -fsSL https://aka.ms/install-azd.sh -o install-azd.sh
```

## Install on disconnected VM

```bash
# Node.js
sudo tar -xJf node-v20.18.0-linux-x64.tar.xz -C /usr/local --strip-components=1

# npm packages
cd src/app && npm install --offline --cache ../../offline-packages/

# Azure CLI (via Docker)
docker load < az-cli.tar
alias az='docker run -it --rm -v ~/.azure:/root/.azure mcr.microsoft.com/azure-cli az'
```
