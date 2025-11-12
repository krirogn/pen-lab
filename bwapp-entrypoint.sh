#!/bin/bash
set -e

# Wait for database to be ready with retries
echo "Waiting for database connection..."

MAX_RETRIES=30
RETRY_COUNT=0
until mysqladmin ping -h bwa-db -u root --silent 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Could not connect to database after $MAX_RETRIES attempts"
        exit 1
    fi

    echo "Waiting for database... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

echo "Database is ready!"

# Check if database is already initialized
if ! mysql -h bwa-db -u root -e "USE bWAPP; SELECT 1 FROM users LIMIT 1;" 2>/dev/null; then
    echo "Initializing bWAPP database..."

    mysql -h bwa-db -u root bWAPP < /usr/local/bin/bWAPP.sql

    if [ $? -eq 0 ]; then
        echo "Database restored successfully"
    else
        echo "Database restoration failed"
        exit 1
    fi
fi

echo "Starting Apache..."

# Start Apache normally
exec apache2-foreground
