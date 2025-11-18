# crs-dev-environment-setup

This script sets up a dev environment ready with all the tools needed for developing anything CRS related. It's meant to be run on a non-production dev environment without any existing Apache/NGINX/ModSecurity config. 

This has only been tested on Ubuntu 24.04 so this script might not work for other distros.

No rules are shipped with this script, and http services are disabled. You are expected to bring your own and start/stop the services as needed.

This script can be ran with this one-liner:
```
curl -s https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/setup.sh | bash
```
