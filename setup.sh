#!/bin/bash

set -eEuo pipefail
trap 'echo "Error on line $LINENO with command: $BASH_COMMAND"; exit 1' ERR

modsecurity()
{
  # See: https://modsecurity.digitalwave.hu/
  sudo apt update
  sudo apt-get -y install apt-transport-https lsb-release ca-certificates curl
  sudo wget -q https://modsecurity.digitalwave.hu/dwmodsec.gpg -O /etc/apt/trusted.gpg.d/modsecurity-digitalwave.gpg
  echo "deb http://modsecurity.digitalwave.hu/ubuntu/ $(lsb_release -sc)-backports main" | sudo tee /etc/apt/sources.list.d/dwmodsec.list

  # Prefer digitalwave repository for modsec
  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/apt/99modsecurity -O /etc/apt/preferences.d/99modsecurity

  sudo apt update

  # Make sure both Apache and NGINX is disabled to avoid errors
  sudo apt install -y --no-install-recommends apache2 libapache2-mod-security2
  sudo systemctl disable apache2 --now
  sudo apt install -y --no-install-recommends nginx libnginx-mod-http-modsecurity
  sudo systemctl disable nginx --now

  sudo cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf

  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/modsecurity/main.conf -O /etc/modsecurity/main.conf

  # See: https://coreruleset.org/docs/6-development/6-5-testing-the-rule-set/
  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/modsecurity/dev.conf -O /etc/modsecurity/dev.conf

  # Configure ModSecurity
  sudo sed -i -E "s/SecRuleEngine.*/SecRuleEngine On/" /etc/modsecurity/modsecurity.conf
  sudo sed -i "s#/var/log/apache2/modsec_audit.log#/var/log/modsec_audit.log#" /etc/modsecurity/modsecurity.conf
  sudo sed -i -E "s#^SecResponseBodyMimeType.*#SecResponseBodyMimeType text/plain text/html text/xml application/json#" /etc/modsecurity/modsecurity.conf
  sudo sed -i "/SecRequestBodyInMemoryLimit/d" /etc/modsecurity/modsecurity.conf

  # See: https://github.com/owasp-modsecurity/modsecurity/issues/3109
  sudo sed -i -E "s/SecAuditLogParts .*/SecAuditLogParts ABCDEFHIJZ/" /etc/modsecurity/modsecurity.conf

}

nginx()
{

  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/nginx/default -O /etc/nginx/sites-enabled/default
  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/nginx/modsecurity.conf -O /etc/nginx/conf.d/modsecurity.conf
  sudo systemctl disable nginx --now

}

httpd()
{

  sudo a2enmod proxy proxy_http

  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/httpd/security.conf -O /etc/apache2/mods-enabled/security2.conf
  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/httpd/security.conf -O /etc/apache2/sites-enabled/000-default.conf

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
  wget "$go_ftw_download" -O "$tmp_dir/ftw-latest.deb"
  wget "$crs_toolchain_download" -O "$tmp_dir/crs-toolchain-latest.deb"
  wget "$albedo_download" -O "$tmp_dir/albedo-latest.deb"
  sudo dpkg -i "$tmp_dir/ftw-latest.deb"
  sudo dpkg -i "$tmp_dir/crs-toolchain-latest.deb"
  sudo dpkg -i "$tmp_dir/albedo-latest.deb"
 
  # ftw config
  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/ftw/.ftw.apache.yaml -O /etc/modsecurity/.ftw.apache.yaml
  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/ftw/.ftw.nginx.yaml -O /etc/modsecurity/.ftw.nginx.yaml

  # Albedo systemd config
  sudo wget https://raw.githubusercontent.com/EsadCetiner/crs-dev-environment-setup/refs/heads/main/config/albedo/albedo.service -O /etc/systemd/system/albedo.service
  sudo systemctl daemon-reload
  sudo systemctl disable albedo --now

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
