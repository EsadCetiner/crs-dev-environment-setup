# crs-dev-environment-setup

This script is a personal script used to setup a dev environment for working with CRS rules, plugins, and anything ModSecurity related. This script is not meant for a production server and should be ran on an install without an existing Apache/NGINX/ModSecurity setup.

No rules are shipped with this script, and http services are disabled. You are expected to bring your own and start/stop the services as needed.

Two scripts are available, one for Ubuntu, and another for Fedora. They can be ran with a one-liner

## Ubuntu

```
curl -s https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/setup.sh | bash
```

## Fedora
```
curl -s https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/setup-fedora.sh | bash
```
