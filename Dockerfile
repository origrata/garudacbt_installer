
FROM php:7.4-fpm

# Install ekstensi PHP jika diperlukan
RUN docker-php-ext-install pdo pdo_mysql

# Set permission agar PHP dapat mengakses file
RUN chown -R www-data:www-data /var/www/html && chmod -R 755 /var/www/html

# Install dependencies
RUN apt-get update && apt-get install -y \
    libzip-dev \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libxml2-dev \
    libicu-dev \
    libmcrypt-dev \
    libonig-dev \
    libxslt1-dev \
    libc-client-dev \
    libkrb5-dev \
    unzip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) \
       pdo_mysql \
       mysqli \
       gd \
       zip \
       xml \
       mbstring \
       intl \
       imap \
       xsl \
       exif \
    && pecl install apcu mcrypt \
    && docker-php-ext-enable apcu mcrypt \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /var/www/html

