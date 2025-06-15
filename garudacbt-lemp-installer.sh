#!/bin/bash

echo "=== Update OS dan Instalasi Dependensi Dasar GarudaCBT ==="
apt update
apt install -y software-properties-common curl lsb-release ca-certificates gnupg2 pwgen git unzip wget

echo "=== Tambah Repository PHP Ondřej ==="
add-apt-repository ppa:ondrej/php -y
apt update

echo "=== Instalasi PHP 7.4 dan Ekstensi ==="
apt install -y php7.4-{cli,common,curl,zip,gd,mysql,xml,mbstring,intl,mcrypt,imap,xsl,apcu,fpm}

echo "=== Aktifkan PHP-FPM ==="
systemctl enable --now php7.4-fpm

echo "=== Instalasi dan Konfigurasi Nginx ==="
apt install -y nginx
systemctl enable --now nginx

echo "=== Instalasi mkpasswd dengan whois ==="
apt install -y whois

echo "=== Deteksi RAM dan CPU ==="
RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM=$(awk -v ram_kb="$RAM_KB" 'BEGIN {ram=int(ram_kb/1024/1024); print (ram < 1) ? 1 : ram}')
CPU=$(nproc)

echo "=== Optimasi PHP-FPM ==="
PHP_FPM_CONF="/etc/php/7.4/fpm/pool.d/www.conf"
sed -i "s/^pm = .*/pm = dynamic/" $PHP_FPM_CONF
sed -i "s/^pm.max_children = .*/pm.max_children = $((CPU * 5))/" $PHP_FPM_CONF
sed -i "s/^pm.start_servers = .*/pm.start_servers = $((CPU * 2))/" $PHP_FPM_CONF
sed -i "s/^pm.min_spare_servers = .*/pm.min_spare_servers = $CPU/" $PHP_FPM_CONF
sed -i "s/^pm.max_spare_servers = .*/pm.max_spare_servers = $((CPU * 4))/" $PHP_FPM_CONF
systemctl restart php7.4-fpm

echo "=== Optimasi Nginx Dasar ==="
NGINX_CONF="/etc/nginx/nginx.conf"
sed -i "s/worker_processes .*/worker_processes $CPU;/" $NGINX_CONF
sed -i "s/# multi_accept on;/multi_accept on;/" $NGINX_CONF
sed -i "s/# use epoll;/use epoll;/" $NGINX_CONF

echo "=== Add Repository MARIADB 11.8 ==="
apt-get install apt-transport-https curl -y
mkdir -p /etc/apt/keyrings
curl -o /etc/apt/keyrings/mariadb-keyring.pgp 'https://mariadb.org/mariadb_release_signing_key.pgp'

cat > /etc/apt/sources.list.d/mariadb.sources <<EOF
# MariaDB 11.8 repository list - created 2025-05-30 03:30 UTC
# https://mariadb.org/download/
X-Repolib-Name: MariaDB
Types: deb
# deb.mariadb.org is a dynamic mirror if your preferred mirror goes offline. See https://mariadb.org/mirrorbits/ for details.
# URIs: https://deb.mariadb.org/11.rc/ubuntu
URIs: https://sg-mirrors.vhost.vn/mariadb/repo/11.8/ubuntu
Suites: noble
Components: main main/debug
Signed-By: /etc/apt/keyrings/mariadb-keyring.pgp
EOF


echo "=== Instalasi MariaDB dan Konfigurasi Awal ==="
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server
systemctl enable --now mariadb

DB_NAME="garudacbt"
DB_USER="garuda_$(tr -dc a-z0-9 </dev/urandom | head -c 4)"
DB_PASS=$(pwgen -s 12 1)
ROOT_PASS=$(pwgen -s 16 1)

mariadb -uroot -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$ROOT_PASS') WITH GRANT OPTION;"
mariadb -uroot -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"
mariadb -uroot -p"$ROOT_PASS" -e "CREATE DATABASE \`$DB_NAME\`;"
mariadb -uroot -p"$ROOT_PASS" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mariadb -uroot -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
mariadb -uroot -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"

echo "=== Simpan Informasi Akses Database ==="
cat > database_akses.txt <<EOF
[ROOT]
Username: root
Password: $ROOT_PASS

[GARUDACBT]
Database: $DB_NAME
Username: $DB_USER
Password: $DB_PASS
EOF
chmod 600 database_akses.txt

echo "=== Clone Repo GarudaCBT ==="
rm -rf /var/www/html/*
git clone https://github.com/garudacbt/cbt.git /var/www/html
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

echo "=== Install dan Setup phpMyAdmin ==="
mkdir -p /var/www/html/dbpanel
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip -O phpmyadmin.zip
unzip phpmyadmin.zip -d /var/www/
mv /var/www/phpMyAdmin-*-all-languages/* /var/www/html/dbpanel
rm -rf /var/www/phpMyAdmin-*-all-languages phpmyadmin.zip
mv /var/www/html/dbpanel/config.sample.inc.php /var/www/html/dbpanel/config.inc.php
chown -R www-data:www-data /var/www/html/dbpanel
chmod -R 755 /var/www/html/dbpanel


echo "=== Membuat SSL Self-Signed untuk Dev ==="
SSL_DIR="/etc/nginx/ssl"
mkdir -p $SSL_DIR
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout $SSL_DIR/selfsigned.key \
  -out $SSL_DIR/selfsigned.crt \
  -subj "/C=ID/ST=Garuda/L=CBT/O=Development/CN=localhost"

echo "=== Konfigurasi Nginx dengan SSL ==="
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;

    root /var/www/html;
    index index.php index.html index.htm;
    server_name _;

    error_log /var/log/nginx/garudacbt-error.log warn;

    ssl_certificate $SSL_DIR/selfsigned.crt;
    ssl_certificate_key $SSL_DIR/selfsigned.key;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }

    location /dbpanel {
        index index.php index.html index.htm;
        try_files \$uri \$uri/ /dbpanel/index.php?$query_string;
    }

    
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
}

server {
    listen 80;
    return 301 https://\$host\$request_uri;
}
EOF
systemctl restart nginx

echo "=== Update Konfigurasi database.php ==="
DB_CONFIG="/var/www/html/application/config/database.php"
sed -i "s/'hostname' => '.*'/'hostname' => 'localhost'/" $DB_CONFIG
sed -i "s/'username' => '.*'/'username' => '$DB_USER'/" $DB_CONFIG
sed -i "s/'password' => '.*'/'password' => '$DB_PASS'/" $DB_CONFIG
sed -i "s/'database' => '.*'/'database' => '$DB_NAME'/" $DB_CONFIG

echo "=== Import Struktur Database master.sql ==="
mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" < /var/www/html/assets/app/db/master.sql

echo "=== Proses Install Monitoring Server == "
bash -c "$(curl -L https://raw.githubusercontent.com/0xJacky/nginx-ui/main/install.sh)" @ install

echo "=== Update Konfigurasi NGINX LOG ==="
sed -i 's|^ErrorLogPath[[:space:]]*=.*|ErrorLogPath    = /var/log/nginx/error.log|' /usr/local/etc/nginx-ui/app.ini
systemctl restart nginx-ui

echo "=== SELESAI! Garuda CBT siap digunakan ==="
echo "Buka: https://$(curl -s ifconfig.me) (SSL Self-Signed)"
echo "Panel DB: https://$(curl -s ifconfig.me)/dbpanel"
echo "Server Monitor: http://$(curl -s ifconfig.me):9000"
echo "Cek file database_akses.txt untuk kredensial DB"
