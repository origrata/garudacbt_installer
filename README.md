# GarudaCBT Installer (Instance/VPS dalam kondisi Kosong)

## Cara Instalasi Untuk Versi Docker

Jalankan perintah berikut di terminal untuk mengunduh dan menjalankan installer untuk versi docker:

```
wget -O - "https://raw.githubusercontent.com/origrata/garudacbt_installer/refs/heads/main/install.sh" | sudo bash

```

Pastikan Anda memiliki koneksi internet yang stabil saat menjalankan perintah ini.

## Fitur
- Auto Config Database
- auto generate SSL dengan cara akses "https://ipserveranda"

## Stack
- Nginx
- php7.4-fpm
- mariadb11.4

## Cara Instalasi Untuk Versi LEMP STACK
Jalankan perintah berikut di terminal via root untuk proses installer otomatis LEMP STACK:

```
wget -O - "https://raw.githubusercontent.com/origrata/garudacbt_installer/refs/heads/main/garudacbt-lemp-installer.sh" | sudo bash

```
- Instalasi PHP 7.4 + Nginx + MariaDB
- Optimasi PHP-FPM dan Nginx
- Pembuatan database garudacbt, user acak garuda_xxxx, dan password acak
- Cloning repo GarudaCBT
- Setting SSL self-signed HTTPS

## Catatan
- Pastikan Anda memiliki akses root atau gunakan `sudo` jika diperlukan.
- Jika terjadi error, pastikan `wget` telah terinstal dengan menjalankan `sudo apt install wget` (untuk Debian/Ubuntu) atau `sudo yum install wget` (untuk CentOS/RHEL).
