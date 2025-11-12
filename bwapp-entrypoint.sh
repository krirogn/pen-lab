#!/bin/bash
set -e

# Wait for database to be ready with retries
echo "Waiting for database connection..."

MAX_RETRIES=30
RETRY_COUNT=0
until mysqladmin ping -h bwa-db -u root -pbug --silent 2>/dev/null; do
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
if ! mysql -h bwa-db -u root -pbug -e "USE bWAPP; SELECT 1 FROM users LIMIT 1;" 2>/dev/null; then
    echo "Initializing bWAPP database..."
    
    # Start Apache in background
    apache2-foreground &
    APACHE_PID=$!
    
    # Wait for Apache to be ready
    sleep 5
    
    # Trigger the install
    # Use /bWAPP/install.php path
    curl -s "http://localhost/bWAPP/install.php?install=yes" > /dev/null || \
    wget -q -O- "http://localhost/bWAPP/install.php?install=yes" > /dev/null || true
    
    echo "bWAPP database initialized!"
    
    # Kill background Apache
    kill $APACHE_PID
    wait $APACHE_PID 2>/dev/null || true
    sleep 2
fi

echo "Starting Apache..."

# Start Apache normally
exec apache2-foreground
