#!/bin/bash

set -e  # Hentikan skrip jika terjadi error

# Deteksi sistem operasi
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "Tidak dapat menentukan sistem operasi."
    exit 1
fi

# Fungsi untuk menginstal Docker di Ubuntu/Debian
install_docker_debian() {
    echo "Menginstal Docker di Ubuntu/Debian..."
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg

    # Tambahkan GPG key Docker
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Tambahkan repository Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Fungsi untuk menginstal Docker di AlmaLinux/RHEL/CentOS
install_docker_rhel() {
    echo "Menginstal Docker di AlmaLinux/RHEL/CentOS..."
    sudo dnf install -y dnf-utils
    sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

# Cek apakah Docker sudah terinstal
if ! command -v docker &> /dev/null; then
    echo "Docker tidak ditemukan. Menginstal Docker..."
    
    case "$OS" in
        ubuntu|debian)
            install_docker_debian
            ;;
        almalinux|centos|rhel)
            install_docker_rhel
            ;;
        *)
            echo "Distribusi $OS tidak didukung oleh skrip ini."
            exit 1
            ;;
    esac

    # Tambahkan pengguna ke grup Docker agar bisa menjalankan Docker tanpa sudo
    sudo usermod -aG docker $USER
    echo "Docker berhasil diinstal. Silakan logout dan login kembali untuk menggunakan Docker tanpa sudo."
else
    echo "Docker sudah terinstal."
fi

# Cek apakah Docker Compose sudah terinstal
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose tidak ditemukan. Menginstal Docker Compose..."
    
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose

    echo "Docker Compose berhasil diinstal."
else
    echo "Docker Compose sudah terinstal."
fi

# Cek apakah Git sudah terinstal
if ! command -v git &> /dev/null; then
    echo "Git tidak ditemukan. Menginstal Git..."
    
    case "$OS" in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y git
            ;;
        almalinux|centos|rhel)
            sudo dnf install -y git
            ;;
    esac

    echo "Git berhasil diinstal."
else
    echo "Git sudah terinstal."
fi

#Get Dockerfile
wget -c  https://raw.githubusercontent.com/origrata/garudacbt_installer/70f44ae0ed96990d0e0c4470f0ad2e3c8c57bd1c/Dockerfile

#Get Nginx Default
wget -c https://raw.githubusercontent.com/origrata/garudacbt_installer/70f44ae0ed96990d0e0c4470f0ad2e3c8c57bd1c/default.conf

#Get docker-compose.yml
wget -c https://raw.githubusercontent.com/origrata/garudacbt_installer/refs/heads/main/docker-compose.yml

#Get Init.sql
wget -c https://raw.githubusercontent.com/origrata/garudacbt_installer/refs/heads/main/init.sql

#!/bin/bash

REPO_URL="https://github.com/garudacbt/cbt.git"
TARGET_DIR="public"
TEMP_DIR="cbt"

# Periksa apakah folder public sudah ada
if [ -d "$TARGET_DIR" ]; then
    echo "Folder '$TARGET_DIR' sudah ada."

    # Pastikan direktori public adalah repository git
    if [ -d "$TARGET_DIR/.git" ]; then
        echo "Mengambil perubahan terbaru dari repository..."
        cd "$TARGET_DIR"
        git reset --hard
        git pull || { echo "Gagal melakukan git pull."; exit 1; }
        cd ..
    else
        echo "Folder '$TARGET_DIR' bukan repository git yang valid. Menggunakan metode clone ulang."

        # Clone ulang ke folder sementara
        git clone --depth 1 "$REPO_URL" "$TEMP_DIR" || { echo "Gagal clone repository."; exit 1; }

        # Salin isi folder cbt ke folder public
        rsync -a --delete "$TEMP_DIR/" "$TARGET_DIR/"

        # Hapus folder sementara
        rm -rf "$TEMP_DIR"
    fi
else
    echo "Folder '$TARGET_DIR' tidak ditemukan. Melakukan cloning repository..."
    
    # Clone ke folder sementara dulu
    git clone --depth 1 "$REPO_URL" "$TEMP_DIR" || { echo "Gagal clone repository."; exit 1; }

    # Rename folder cbt menjadi public
    mv "$TEMP_DIR" "$TARGET_DIR"
fi

# Pastikan folder public ada sebelum mengubah kepemilikan dan hak akses
if [ -d "$TARGET_DIR" ]; then
    echo "Mengatur kepemilikan dan izin folder '$TARGET_DIR'..."
    chown -R www-data:www-data "$TARGET_DIR"
    chmod -R 775 "$TARGET_DIR"
else
    echo "Error: Folder '$TARGET_DIR' tidak ditemukan setelah proses cloning atau update."
    exit 1
fi


echo "Menghasilkan password database..."
DB_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 8)
ROOT_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 10)

# Perbarui konfigurasi database dalam file PHP
echo "Memperbarui konfigurasi database..."
sed -i "s/'hostname' => '.*'/'hostname' => 'mariadb-container'/g" public/application/config/database.php
sed -i "s/'username' => '.*'/'username' => 'garudacbt'/g" public/application/config/database.php
sed -i "s/'password' => '.*'/'password' => '$DB_PASSWORD'/g" public/application/config/database.php
sed -i "s/'database' => '.*'/'database' => 'garudacbt'/g" public/application/config/database.php

# Config session folder pada TMP
sed -i "s/\$config\['sess_save_path'\] = NULL;/\$config\['sess_save_path'\] = '\/tmp';/" public/application/config/config.php

# Merubah ukuran dashboard admin dari 400 ke 150
sed -i '4s/height: 400px/height: 150px/' public/application/views/dashboard.php

# Merubah ukuran dashboard admin dari 400 ke 150
sed -i '4s/height: 400px/height: 150px/' public/application/views/members/guru/dashboard.php

# Buat file .env untuk Docker Compose
echo "Menulis file .env..."
cat <<EOL > .env
MYSQL_ROOT_PASSWORD=$ROOT_PASSWORD
MYSQL_DATABASE=garudacbt
MYSQL_USER=garudacbt
MYSQL_PASSWORD=$DB_PASSWORD
EOL

#Tempat simpan data mariadb docker
mkdir -p mariadb_data

echo "Proses instalasi garudacbt sedang berlangsung..."
docker-compose up -d --build

echo "Instalasi Garudacbt Telah selesai. Akses VPS anda Public IP: http://$(curl -s ifconfig.me) untuk melanjutkan konfigurasi identitas Instansi"
