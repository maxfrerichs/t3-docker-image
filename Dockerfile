FROM debian:11

ENV PHP php81
ENV TERM linux
ENV DEBIAN_FRONTEND noninteractive
ENV TYPO3_CONTEXT Production

ENV APACHE_RUN_USER www-data
ENV APACHE_RUN_GROUP www-data
RUN usermod -u 1000 www-data
RUN groupmod -g 1000 www-data


##
# Locale setings
##


RUN apt-get -qq update \
    && apt-get -yqq upgrade \
    && apt-get -yqq install locales sudo apt-transport-https lsb-release ca-certificates \
        cron nano unzip gnupg wget

# Add third-party repository for PHP 8.1 support
RUN echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/sury-php.list
RUN wget -qO - https://packages.sury.org/php/apt.gpg | apt-key add -
RUN apt-get update -y

RUN echo "de_DE.UTF-8 UTF-8\nen_US.UTF-8 UTF-8" >> /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US
ENV LC_CTYPE=de_DE.UTF-8
ENV LC_NUMERIC=de_DE.UTF-8
ENV LC_TIME=de_DE.UTF-8
ENV LC_COLLATE=de_DE.UTF-8
ENV LC_MONETARY=de_DE.UTF-8
ENV LC_MESSAGES=en_US.UTF-8
ENV LC_PAPER=de_DE.UTF-8
ENV LC_NAME=de_DE.UTF-8
ENV LC_ADDRESS=de_DE.UTF-8
ENV LC_TELEPHONE=de_DE.UTF-8
ENV LC_MEASUREMENT=de_DE.UTF-8
ENV LC_IDENTIFICATION=de_DE.UTF-8

ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
RUN dpkg-reconfigure -f noninteractive tzdata


##
# PHP
##

RUN apt-get -qq update && apt-get -yqq install php8.1 '^php8.1-(zip|bz2|gd|iconv|soap|mysqli|intl|mbstring|xml|curl|xsl|dba|pgsql|opcache)' \
    libpcre3 libpcre3-dev libxml2-dev zlib1g-dev libmcrypt-dev libpq-dev libzip-dev \
    imagemagick graphicsmagick libfreetype6-dev libjpeg62-turbo-dev libpng-dev

RUN touch /var/log/php.log && chmod a+rw /var/log/php.log
COPY config/php_apache.ini /etc/php/8.1/apache2/conf.d/90-custom.ini
COPY config/php_cli.ini /etc/php/8.1/cli/conf.d/90-custom.ini

##
# Apache
##

RUN apt-get -yqq install apache2
RUN a2enmod rewrite
RUN mkdir /var/log/typo3 && \
    chmod -R a+rw /var/log/typo3 && \
    echo "ServerName $PHP\n ErrorLog /var/log/typo3/error.log\n CustomLog /var/log/typo3/access.log combined" >> /etc/apache2/apache2.conf


##
# Cron
##

RUN echo "* * * * * www-data /var/www/*/www-data/typo3/cli_dispatch.phpsh scheduler" > /etc/cron.d/typo3 && \
    chmod -R a=rwx /etc/cron.d/
RUN cron


##
# System configuration
## 

# Composer & git config
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
        php composer-setup.php --install-dir=/usr/local/bin/ --filename=composer && \
        php -r "unlink('composer-setup.php');" && \
        mkdir -p /root/.composer/ && \
        ln -s /opt/composer/auth.json /root/.composer/auth.json

COPY config/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY config/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf


WORKDIR /var/www/typo3
COPY config/composer.json /var/www/typo3
COPY entrypoint.sh .
RUN chown www-data . -R
EXPOSE 80
EXPOSE 443

ENTRYPOINT [ "/bin/bash" ]
CMD [ "entrypoint.sh" ]