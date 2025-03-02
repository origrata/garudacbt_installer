# GarudaCBT Installer (Instance/VPS dalam kondisi Kosong)

## Cara Instalasi

Jalankan perintah berikut di terminal untuk mengunduh dan menjalankan installer:

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

## Catatan
- Pastikan Anda memiliki akses root atau gunakan `sudo` jika diperlukan.
- Jika terjadi error, pastikan `wget` telah terinstal dengan menjalankan `sudo apt install wget` (untuk Debian/Ubuntu) atau `sudo yum install wget` (untuk CentOS/RHEL).
