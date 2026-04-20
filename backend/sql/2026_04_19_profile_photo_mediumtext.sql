SET @schema_name = DATABASE();

SET @profile_photo_exists = (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = @schema_name
    AND table_name = 'users'
    AND column_name = 'profile_photo'
);

SET @sql = IF(
  @profile_photo_exists = 0,
  'ALTER TABLE users ADD COLUMN profile_photo MEDIUMTEXT NULL',
  'ALTER TABLE users MODIFY COLUMN profile_photo MEDIUMTEXT NULL'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
