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
  cat << EOF | sudo tee /etc/apt/preferences.d/99modsecurity
Package: *libnginx-mod-http-modsecurity*
Pin: origin modsecurity.digitalwave.hu
Pin-Priority: 900

Package: *libapache2-mod-security2*
Pin: origin modsecurity.digitalwave.hu
Pin-Priority: 900

Package: *modsecurity-crs*
Pin: origin modsecurity.digitalwave.hu
Pin-Priority: 900

Package: *libmodsecurity*
Pin: origin modsecurity.digitalwave.hu
Pin-Priority: 900
EOF

  sudo apt update

  # Make sure both Apache and NGINX is disabled to avoid errors
  sudo apt install -y --no-install-recommends apache2 libapache2-mod-security2
  sudo systemctl disable apache2 --now
  sudo apt install -y --no-install-recommends nginx libnginx-mod-http-modsecurity
  sudo systemctl disable nginx --now

  sudo cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf

  cat <<EOF | sudo tee /etc/modsecurity/main.conf
include /etc/modsecurity/coreruleset/crs-setup.conf
include /etc/modsecurity/dev.conf
include /etc/modsecurity/coreruleset/plugins/*-config.conf
include /etc/modsecurity/coreruleset/plugins/*-before.conf
include /etc/modsecurity/modsecurity.conf
include /etc/modsecurity/coreruleset/rules/*.conf
include /etc/modsecurity/coreruleset/plugins/*-after.conf
EOF

  # See: https://coreruleset.org/docs/6-development/6-5-testing-the-rule-set/
  cat <<EOF | sudo tee /etc/modsecurity/dev.conf
SecAction \\
    "id:900005,\\
    phase:1,\\
    nolog,\\
    pass,\\
    ctl:ruleEngine=DetectionOnly,\\
    ctl:ruleRemoveById=910000,\\
    setvar:tx.blocking_paranoia_level=4,\\
    setvar:tx.crs_validate_utf8_encoding=1,\\
    setvar:tx.arg_name_length=100,\\
    setvar:tx.arg_length=400,\\
    setvar:tx.total_arg_length=64000,\\
    setvar:tx.max_num_args=255,\\
    setvar:tx.max_file_size=64100,\\
    setvar:tx.combined_file_sizes=65535"

SecRule REQUEST_HEADERS:X-CRS-Test "@rx ^.*$" \\
    "id:999999,\\
    phase:1,\\
    pass,\\
    t:none,\\
    log,\\
    msg:'%{MATCHED_VAR}'"
EOF

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

  cat <<EOF | sudo tee /etc/nginx/sites-enabled/default
server
{
    listen 8080 default_server;
    listen [::]:8080 default_server;
    server_name _;

    root /var/www/html/;
    index index.html;

    location /reflect
    {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header Proxy "";
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_http_version 1.1;
        proxy_buffering off;
        proxy_connect_timeout 60s;
        proxy_read_timeout 36000s;
        proxy_redirect off;

        proxy_pass_header Authorization;
    }

    error_log /var/log/nginx/error.log info;
}
EOF

  sudo systemctl disable nginx --now

# Configure NGINX to use ModSecurity
  cat << EOF | sudo tee /etc/nginx/conf.d/modsecurity.conf
modsecurity on;
modsecurity_rules_file /etc/modsecurity/main.conf;
EOF

}

httpd()
{

  # Make apache2 use main modsec file
  cat <<EOF | sudo tee /etc/apache2/mods-enabled/security2.conf
<IfModule security2_module>
  # Default Debian dir for modsecurity's persistent data
  SecDataDir /var/cache/modsecurity

  Include /etc/modsecurity/main.conf
</IfModule>
EOF

  sudo a2enmod proxy proxy_http
  cat <<EOF | sudo tee /etc/apache2/sites-enabled/000-default.conf
<VirtualHost *:80>
  DocumentRoot /var/www/html/

  ProxyPreserveHost On
  ProxyPass /reflect http://127.0.0.1:8000/reflect
  ProxyPassReverse /reflect http://127.0.0.1:8000/reflect
  ServerName localhost

  ErrorLog \${APACHE_LOG_DIR}/error.log
  CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

  sudo systemctl disable apache2 --now

}

crs_tools()
{

  # Fetch download URls
  go_ftw_download="$(curl -s https://api.github.com/repos/coreruleset/go-ftw/releases/latest | jq -r ".assets[].browser_download_url" | grep "amd64.deb")"
  crs_toolchain_download="$(curl -s https://api.github.com/repos/coreruleset/crs-toolchain/releases/latest | jq -r ".assets[].browser_download_url" | grep "amd64.deb")"
  albedo_download="$(curl -s https://api.github.com/repos/coreruleset/albedo/releases/latest | jq -r ".assets[].browser_download_url" | grep "amd64.deb")"

  tmp_dir="$(mktemp -d)"
  wget "$go_ftw_download" -O "$tmp_dir/ftw-latest.deb"
  wget "$crs_toolchain_download" -O "$tmp_dir/crs-toolchain-latest.deb"
  wget "$albedo_download" -O "$tmp_dir/albedo-latest.deb"
  sudo dpkg -i "$tmp_dir/ftw-latest.deb"
  sudo dpkg -i "$tmp_dir/crs-toolchain-latest.deb"
  sudo dpkg -i "$tmp_dir/albedo-latest.deb"
 
  cat <<EOF | sudo tee /etc/systemd/system/albedo.service
[Unit]
Description=Albedo is a simple HTTP server used as a reverse-proxy backend in testing web application firewalls (WAFs).
Documentation=https://github.com/coreruleset/albedo
ConditionFileIsExecutable=/usr/bin/albedo

[Service]
ExecStart=/usr/bin/albedo -p 8000 -b localhost
DynamicUser=true

[Install]
WantedBy=apache2.service nginx.service
EOF

  sudo systemctl daemon-reload

  # FTW configs for apache and NGINX
  cat <<EOF | sudo tee /etc/modsecurity/.ftw.apache.yaml
logfile: /var/log/apache2/error.log
logmarkerheadername: X-CRS-TEST
testoverride:
  input:
    dest_addr: "127.0.0.1"
    port: 80
EOF

  cat <<EOF | sudo tee /etc/modsecurity/.ftw.nginx.yaml
logfile: /var/log/nginx/error.log
logmarkerheadername: X-CRS-TEST
testoverride:
  input:
    dest_addr: "127.0.0.1"
    port: 8080
EOF

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
