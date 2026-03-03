#!/bin/bash

set -eEuo pipefail
trap 'echo "Error on line $LINENO with command: $BASH_COMMAND"; exit 1' ERR

modsecurity()
{

  # Install binaries
  sudo dnf install -y -q httpd mod_security.x86_64 nginx nginx-mod-modsecurity.x86_64
  sudo systemctl disable httpd nginx --now

  # Download configs
  sudo mkdir -p /etc/modsecurity/
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/modsecurity/main.conf -O /etc/modsecurity/main.conf
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/modsecurity/modsecurity.conf -O /etc/modsecurity/modsecurity.conf
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/modsecurity/dev.conf -O /etc/modsecurity/dev.conf
  sudo wget -q https://github.com/owasp-modsecurity/ModSecurity/raw/refs/heads/v3/master/unicode.mapping -O /etc/modsecurity/unicode.mapping

}

nginx()
{

  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/nginx/default -O /etc/nginx/conf.d/default.conf
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/nginx/modsecurity.conf -O /etc/nginx/conf.d/modsecurity.conf
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/nginx/nginx.conf -O /etc/nginx/nginx.conf

}

httpd()
{

  echo "Define APACHE_LOG_DIR /var/log/httpd" | sudo tee /etc/httpd/conf.d/000-env.conf > /dev/null
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/httpd/security2.conf -O /etc/httpd/conf.d/mod_security.conf
  sudo wget -q https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/httpd/000-default.conf -O /etc/httpd/conf.d/999-default.conf

}

crs_tools()
{

  # Fetch download URls
  go_ftw_download="$(curl -s https://api.github.com/repos/coreruleset/go-ftw/releases/latest | jq -r ".assets[].browser_download_url" | grep "x86_64.rpm")"
  crs_toolchain_download="$(curl -s https://api.github.com/repos/coreruleset/crs-toolchain/releases/latest | jq -r ".assets[].browser_download_url" | grep "x86_64.rpm")"
  albedo_download="$(curl -s https://api.github.com/repos/coreruleset/albedo/releases/latest | jq -r ".assets[].browser_download_url" | grep "x86_64.rpm")"

  # Install tools
  tmp_dir="$(mktemp -d)"
  wget -q "$go_ftw_download" -O "$tmp_dir/ftw-latest.rpm"
  wget -q "$crs_toolchain_download" -O "$tmp_dir/crs-toolchain-latest.rpm"
  wget -q "$albedo_download" -O "$tmp_dir/albedo-latest.rpm"
  sudo dnf install -y \
  "$tmp_dir/ftw-latest.rpm" \
  "$tmp_dir/crs-toolchain-latest.rpm" \
  "$tmp_dir/albedo-latest.rpm"

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
