#!/bin/bash

echo "=== Update OS dan Instalasi Dependensi Dasar ==="
apt update
apt upgrade -y
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

echo "=== Instalasi MariaDB dan Konfigurasi Awal ==="
DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server
systemctl enable --now mariadb

DB_NAME="garudacbt"
DB_USER="garuda_$(tr -dc a-z0-9 </dev/urandom | head -c 4)"
DB_PASS=$(pwgen -s 12 1)
ROOT_PASS=$(pwgen -s 16 1)

mysql -e "UPDATE mysql.user SET Password=PASSWORD('$ROOT_PASS') WHERE User='root';"
mysql -e "FLUSH PRIVILEGES;"
mysql -uroot -p"$ROOT_PASS" -e "CREATE DATABASE \`$DB_NAME\`;"
mysql -uroot -p"$ROOT_PASS" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -uroot -p"$ROOT_PASS" -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
mysql -uroot -p"$ROOT_PASS" -e "FLUSH PRIVILEGES;"

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
mkdir -p /var/www/phpmyadmin
wget https://www.phpmyadmin.net/downloads/phpMyAdmin-latest-all-languages.zip -O phpmyadmin.zip
unzip phpmyadmin.zip -d /var/www/
mv /var/www/phpMyAdmin-*-all-languages/* /var/www/dbpanel
rm -rf /var/www/phpMyAdmin-*-all-languages phpmyadmin.zip
chown -R www-data:www-data /var/www/dbpanel
chmod -R 755 /var/www/dbpanel


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

    ssl_certificate $SSL_DIR/selfsigned.crt;
    ssl_certificate_key $SSL_DIR/selfsigned.key;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }

    location /dbpanel {
      index index.php index.html index.htm;
      try_files $uri $uri/ /dbpanel/index.php?$query_string;
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

echo "=== SELESAI! Garuda CBT siap digunakan ==="
echo "Buka: https://<IP-server-kamu> (SSL Self-Signed)"
echo "Panel DB: https://<IP-server-kamu>/dbpanel"
echo "Server Monitor: http://<IP-server-kamu>:9000"
echo "Cek file database_akses.txt untuk kredensial DB"
