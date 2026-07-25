-- Einmalige Migration für bestehende Installationen des früheren
-- Frontier-Namensraums. Vor der Ausführung den Server stoppen und ein
-- vollständiges Datenbank-Backup erstellen.

DROP PROCEDURE IF EXISTS `mscore_rename_legacy_table`;
DROP PROCEDURE IF EXISTS `mscore_assert_no_table_conflicts`;

DELIMITER $$

CREATE PROCEDURE `mscore_rename_legacy_table`(
  IN legacy_table_name VARCHAR(64),
  IN current_table_name VARCHAR(64)
)
BEGIN
  DECLARE legacy_exists INT DEFAULT 0;

  SELECT COUNT(*)
    INTO legacy_exists
    FROM information_schema.TABLES
   WHERE TABLE_SCHEMA = DATABASE()
     AND TABLE_NAME = legacy_table_name;

  IF legacy_exists > 0 THEN
    SET @mscore_rename_sql = CONCAT(
      'RENAME TABLE `',
      REPLACE(legacy_table_name, '`', '``'),
      '` TO `',
      REPLACE(current_table_name, '`', '``'),
      '`'
    );
    PREPARE mscore_rename_statement FROM @mscore_rename_sql;
    EXECUTE mscore_rename_statement;
    DEALLOCATE PREPARE mscore_rename_statement;
  END IF;
END$$

CREATE PROCEDURE `mscore_assert_no_table_conflicts`()
BEGIN
  DECLARE table_conflicts INT DEFAULT 0;

  SELECT COUNT(*)
    INTO table_conflicts
    FROM information_schema.TABLES AS legacy_table
    JOIN information_schema.TABLES AS current_table
      ON current_table.TABLE_SCHEMA = legacy_table.TABLE_SCHEMA
     AND current_table.TABLE_NAME = CONCAT(
       'mscore_',
       SUBSTRING(legacy_table.TABLE_NAME, 10)
     )
   WHERE legacy_table.TABLE_SCHEMA = DATABASE()
     AND legacy_table.TABLE_NAME IN (
       'frontier_users',
       'frontier_characters',
       'frontier_map_objects',
       'frontier_world_npcs',
       'frontier_storages',
       'frontier_storage_inventories',
       'frontier_doors',
       'frontier_admin_permissions',
       'frontier_support_logs',
       'frontier_items',
       'frontier_crafting_recipes',
       'frontier_crafting_points'
     );

  IF table_conflicts > 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT =
        'Migration stopped: legacy and MSCore tables exist at the same time';
  END IF;
END$$

DELIMITER ;

CALL `mscore_assert_no_table_conflicts`();

CALL `mscore_rename_legacy_table`('frontier_users', 'mscore_users');
CALL `mscore_rename_legacy_table`('frontier_characters', 'mscore_characters');
CALL `mscore_rename_legacy_table`('frontier_map_objects', 'mscore_map_objects');
CALL `mscore_rename_legacy_table`('frontier_world_npcs', 'mscore_world_npcs');
CALL `mscore_rename_legacy_table`('frontier_storages', 'mscore_storages');
CALL `mscore_rename_legacy_table`('frontier_storage_inventories', 'mscore_storage_inventories');
CALL `mscore_rename_legacy_table`('frontier_doors', 'mscore_doors');
CALL `mscore_rename_legacy_table`('frontier_admin_permissions', 'mscore_admin_permissions');
CALL `mscore_rename_legacy_table`('frontier_support_logs', 'mscore_support_logs');
CALL `mscore_rename_legacy_table`('frontier_items', 'mscore_items');
CALL `mscore_rename_legacy_table`('frontier_crafting_recipes', 'mscore_crafting_recipes');
CALL `mscore_rename_legacy_table`('frontier_crafting_points', 'mscore_crafting_points');

DROP PROCEDURE `mscore_rename_legacy_table`;
DROP PROCEDURE `mscore_assert_no_table_conflicts`;

SELECT 'MSCore database migration completed' AS status;
