



php composer.phar update
cp .env.example .env
php artisan key:generate
php artisan passport:keys

mkdir -p storage/framework/{sessions,views,cache}
chmod -R 775 framework

php artisan prepare:installable
chmod -R 755 .
zip -r ../storage/install.zip .

php artisan prepare:updatable
rm -rf installation