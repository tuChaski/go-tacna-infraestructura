FROM php:8.4-cli

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libonig-dev \
    libpng-dev \
    libpq-dev \
    unzip \
    zip \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        exif \
        gd \
        mbstring \
        pcntl \
        pdo_pgsql \
        pgsql \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY entrypoint.sh /usr/local/bin/gotacna-php-entrypoint

WORKDIR /var/www/html
EXPOSE 8000

RUN chmod +x /usr/local/bin/gotacna-php-entrypoint
ENTRYPOINT ["gotacna-php-entrypoint"]