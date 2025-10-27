-- Initialize MySQL for ActiveRecord Trilogis Adapter Tests
-- This script runs automatically when the MySQL container starts for the first time

-- Ensure the test database exists
CREATE DATABASE IF NOT EXISTS trilogis_adapter_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Create additional test database for tasks_test.rb
CREATE DATABASE IF NOT EXISTS trilogis_tasks_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Grant all privileges to root and trilogis users
GRANT ALL PRIVILEGES ON trilogis_adapter_test.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON trilogis_tasks_test.* TO 'root'@'%';
GRANT ALL PRIVILEGES ON trilogis_adapter_test.* TO 'trilogis'@'%';
GRANT ALL PRIVILEGES ON trilogis_tasks_test.* TO 'trilogis'@'%';

FLUSH PRIVILEGES;

-- Verify spatial support is available
SELECT VERSION();
SHOW VARIABLES LIKE 'version%';
