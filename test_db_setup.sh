#!/bin/bash

# Try different MySQL connection methods
echo "Attempting to create test database..."

# Method 1: No password
mysql -u root -e "CREATE DATABASE IF NOT EXISTS trilogis_adapter_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null && echo "✅ Database created (no password)" && exit 0

# Method 2: Empty password
mysql -u root -p'' -e "CREATE DATABASE IF NOT EXISTS trilogis_adapter_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null && echo "✅ Database created (empty password)" && exit 0

# Method 3: Socket connection
mysql --socket=/tmp/mysql.sock -u root -e "CREATE DATABASE IF NOT EXISTS trilogis_adapter_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null && echo "✅ Database created (socket)" && exit 0

echo "❌ Failed to connect to MySQL. Please set up manually:"
echo "   mysql -u root -p -e \"CREATE DATABASE IF NOT EXISTS trilogis_adapter_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;\""
exit 1
