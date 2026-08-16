#!/bin/bash

set -eEuo pipefail
trap 'echo "Error on line $LINENO with command: $BASH_COMMAND"; exit 1' ERR
distro_id=$(lsb_release -a | grep -oE "Distributor ID:.+" | sed -E "s/Distributor ID:\s+//")

modsecurity()
{

  # Digitwave's repository only supports Ubuntu/Debian.
  # See: https://modsecurity.digitalwave.hu/
  if [[ "$distro_id" = "Ubuntu" || "$distro_id" = "Debian" ]];then
    sudo apt update -q
    sudo apt-get -y -q install apt-transport-https lsb-release ca-certificates curl
    sudo wget -q https://modsecurity.digitalwave.hu/dwmodsec.gpg -O /etc/apt/trusted.gpg.d/modsecurity-digitalwave.gpg
    echo "deb http://modsecurity.digitalwave.hu/ubuntu/ $(lsb_release -sc)-backports main" | sudo tee /etc/apt/sources.list.d/dwmodsec.list

    # Prefer digitalwave repository for modsec
    sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/apt/99modsecurity -O /etc/apt/preferences.d/99modsecurity
  else
    echo "Warning: Skipped installation of Digitalwave ModSecurity repository, an outdated version of ModSecurity will be installed!"
  fi

  sudo apt update

  # Make sure both Apache and NGINX is disabled to avoid errors
  sudo apt install -y -q --no-install-recommends apache2 libapache2-mod-security2 jq
  sudo systemctl disable apache2 --now
  sudo apt install -y -q --no-install-recommends nginx libnginx-mod-http-modsecurity
  sudo systemctl disable nginx --now

  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/modsecurity/main.conf -O /etc/modsecurity/main.conf
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/modsecurity/modsecurity.conf -O /etc/modsecurity/modsecurity.conf
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/modsecurity/dev.conf -O /etc/modsecurity/dev.conf

}

nginx()
{

  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/nginx/default -O /etc/nginx/sites-enabled/default
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/nginx/modsecurity.conf -O /etc/nginx/conf.d/modsecurity.conf
  sudo systemctl disable nginx --now

}

httpd()
{

  sudo a2enmod proxy proxy_http

  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/httpd/security2.conf -O /etc/apache2/mods-enabled/security2.conf
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/httpd/000-default.conf -O /etc/apache2/sites-enabled/000-default.conf
  sudo systemctl disable apache2 --now

}

crs_tools()
{

  # Fetch download URls
  go_ftw_download="$(curl -s https://api.github.com/repos/coreruleset/go-ftw/releases/latest | jq -r ".assets[].browser_download_url" | grep "amd64.deb")"
  crs_toolchain_download="$(curl -s https://api.github.com/repos/coreruleset/crs-toolchain/releases/latest | jq -r ".assets[].browser_download_url" | grep "amd64.deb")"
  albedo_download="$(curl -s https://api.github.com/repos/coreruleset/albedo/releases/latest | jq -r ".assets[].browser_download_url" | grep "amd64.deb")"

  # Install tools
  tmp_dir="$(mktemp -d)"
  wget -q "$go_ftw_download" -O "$tmp_dir/ftw-latest.deb"
  wget -q "$crs_toolchain_download" -O "$tmp_dir/crs-toolchain-latest.deb"
  wget -q "$albedo_download" -O "$tmp_dir/albedo-latest.deb"
  sudo dpkg -i "$tmp_dir/ftw-latest.deb"
  sudo dpkg -i "$tmp_dir/crs-toolchain-latest.deb"
  sudo dpkg -i "$tmp_dir/albedo-latest.deb"

  # ftw config
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/ftw/.ftw.apache.yaml -O /etc/modsecurity/.ftw.apache.yaml
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/ftw/.ftw.nginx.yaml -O /etc/modsecurity/.ftw.nginx.yaml

  # Albedo systemd config
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/albedo/albedo.service -O /etc/systemd/system/albedo.service
  sudo systemctl daemon-reload
  sudo systemctl disable albedo --now

  sudo mkdir -p /etc/modsecurity/bin/
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/bin/generate-template-tests.sh -O /etc/modsecurity/bin/generate-template-tests.sh
  sudo chmod 0755 /etc/modsecurity/bin/generate-template-tests.sh
  
  # regexploit to test for ReDoS
  sudo apt install -y pipx
  pipx ensurepath
  pipx install regexploit

}

main()
{

  if [ "$(whoami)" == "root" ];then
    echo "error: Please run this script as an unprivileged user without sudo"
    exit 1
  fi

  modsecurity
  nginx
  httpd
  crs_tools

  # Set ownership to current user for convenience
  non_root="$(whoami)"
  sudo chown -R "$non_root":"$non_root" /etc/modsecurity/

}

main
