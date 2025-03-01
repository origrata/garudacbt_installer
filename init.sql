-- Pastikan menggunakan database yang benar
USE mysql;

-- Hapus user jika sudah ada untuk menghindari konflik
DROP USER IF EXISTS '${MYSQL_USER}'@'%' ;

-- Buat ulang user agar bisa diakses dari semua host
CREATE USER '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';

-- Berikan semua hak akses ke database yang ditentukan
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';

-- Terapkan perubahan
FLUSH PRIVILEGES;
