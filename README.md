# crs-dev-environment-setup

This script is a personal script used to setup a dev environment for working with CRS rules, plugins, and anything ModSecurity related. This script is not meant for a production server and should be ran on an install without an existing Apache/NGINX/ModSecurity setup, assume any existing config will be overwritten or broken.

No rules are shipped with this script, and http services are disabled by default. You are expected to bring your own ModSecurity ruleset and start/stop the services as needed.

## Installation:

Two scripts are available, one for Ubuntu, and another for Fedora. They can be ran with a one-liner

Debian based:
```
curl -s https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/setup.sh | bash
```

Fedora:
```
curl -s https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/setup-fedora.sh | bash
```

**Note:** This script has only been tested on Fedora and Ubuntu.

## Features:

### modsecurity.digitalwave.hu (Debian/Ubuntu only)

[modsecurityl.digitalwave.hu](https://modsecurity.digitalwave.hu/) is a 3rd party ModSecurity repository which provides up to date versions of ModSecurity. It's maintained by [airween](https://github.com/airween), a CRS developer and ModSecurity co-lead. This repository is not installed on unsupported OS's.

### generate-template-tests.sh

A helper script is also shipped with this setup script which helps you generate new boilerplate tests. This is useful if you've written multiple new SecLang rules and you need to add tests for them, this is tedious to do manually. It can be found in `/etc/modsecurity/bin/`.
