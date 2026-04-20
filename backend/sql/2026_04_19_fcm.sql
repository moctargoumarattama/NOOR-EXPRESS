SET @column_exists = (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'users'
    AND column_name = 'fcm_token'
);

SET @sql = IF(
  @column_exists = 0,
  'ALTER TABLE users ADD COLUMN fcm_token VARCHAR(500) NULL',
  'SELECT "fcm_token column already exists"'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @index_exists = (
  SELECT COUNT(*)
  FROM information_schema.statistics
  WHERE table_schema = DATABASE()
    AND table_name = 'users'
    AND index_name = 'idx_fcm_token'
);

SET @sql = IF(
  @index_exists = 0,
  'ALTER TABLE users ADD INDEX idx_fcm_token (fcm_token(100))',
  'SELECT "idx_fcm_token already exists"'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
