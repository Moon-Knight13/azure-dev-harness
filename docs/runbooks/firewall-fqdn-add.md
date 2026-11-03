# Runbook: Request Firewall FQDN Addition

## When
Egress blocked to a domain you need. `curl` times out, `npm install` fails.

## Diagnose
```bash
curl -v --connect-timeout 5 https://<domain>/ 2>&1 | grep -E 'connect|timeout|refused'
```

## Required FQDNs (baseline)

### Azure services
- management.azure.com
- login.microsoftonline.com
- graph.microsoft.com
- *.blob.core.windows.net
- *.table.core.windows.net
- *.queue.core.windows.net
- *.azurecr.io
- mcr.microsoft.com
- *.data.mcr.microsoft.com
- *.vault.azure.net
- *.database.windows.net

### Dev package repos
- registry.npmjs.org
- pypi.org
- files.pythonhosted.org
- deb.nodesource.com
- archive.ubuntu.com
- security.ubuntu.com
- packages.microsoft.com
- aka.ms
- azurecliprod.blob.core.windows.net

### Git
- dev.azure.com
- *.visualstudio.com
- github.com
- *.githubusercontent.com

## Request template
```
Subject: Firewall FQDN allowlist addition — [project]

Blocked domain: <fqdn>
Source subnet: 10.0.1.0/24 (snet-devvms)
Protocol: HTTPS (443)
Reason: Required for <npm install | docker pull | az cli | etc>
Reference: Azure App Service Landing Zone Accelerator includes this FQDN
```

## Workaround (if slow to approve)
Use offline-packages/ via Bastion file copy.
