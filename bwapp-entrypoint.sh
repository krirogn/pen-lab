#!/bin/bash
set -e

# Wait for database to be ready
echo "Waiting for database..."
while ! mysqladmin ping -h"bwa-db" -u"bwapp" -p"bug" --silent; do
    sleep 1
done
echo "Database is ready!"

# Check if database is already initialized
if ! mysql -h bwa-db -u bwapp -pbug -e "USE bwapp; SELECT 1 FROM users LIMIT 1;" 2>/dev/null; then
    echo "Initializing bWAPP database..."
    
    # Run the install script by making a local HTTP request
    sleep 2  # Give Apache a moment to start
    
    # Start Apache in background
    apache2-foreground &
    APACHE_PID=$!
    
    # Wait for Apache to be ready
    sleep 3
    
    # Trigger the install
    wget -O- "http://localhost/install.php?install=yes" > /dev/null 2>&1 || true
    
    echo "bWAPP database initialized!"
    sleep 3
    
    # Kill background Apache and restart properly
    kill $APACHE_PID
    wait $APACHE_PID 2>/dev/null || true
fi

# Start Apache normally
exec apache2-foreground
