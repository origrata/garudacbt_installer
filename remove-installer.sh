#!/bin/bash

echo "=== Menghapus Instalasi GarudaCBT dan Dependensi ==="

# Hentikan layanan
systemctl stop nginx php7.4-fpm mariadb

# Nonaktifkan layanan dari startup
systemctl disable nginx php7.4-fpm mariadb

# Hapus paket yang terinstal
apt purge -y nginx php7.4* mariadb-server mariadb-client phpmyadmin unzip git pwgen software-properties-common curl lsb-release ca-certificates gnupg2
apt autoremove -y
apt clean

# Hapus direktori dan file konfigurasi terkait
rm -rf /etc/nginx /var/www/html /var/www/phpmyadmin /etc/php /etc/mysql /var/lib/mysql /etc/nginx/ssl /etc/nginx/sites-available/default /var/www/phpMyAdmin-*-all-languages

# Hapus file kredensial database
rm -f database_akses.txt

# Bersihkan log
rm -rf /var/log/nginx /var/log/mysql /var/log/php7.4-fpm.log

# Informasi selesai
echo "=== Uninstall selesai. Semua file dan konfigurasi telah dihapus. ==="
