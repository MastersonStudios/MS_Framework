CREATE TABLE IF NOT EXISTS `frontier_users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `license` VARCHAR(64) NOT NULL,
  `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_frontier_users_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_characters` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL,
  `firstname` VARCHAR(32) NOT NULL,
  `lastname` VARCHAR(32) NOT NULL,
  `date_of_birth` DATE NULL,
  `sex` ENUM('male','female') NOT NULL DEFAULT 'male',
  `job` VARCHAR(32) NOT NULL DEFAULT 'unemployed',
  `job_grade` INT NOT NULL DEFAULT 0,
  `group_name` VARCHAR(32) NOT NULL DEFAULT 'user',
  `cash` INT UNSIGNED NOT NULL DEFAULT 50,
  `bank` INT UNSIGNED NOT NULL DEFAULT 250,
  `health` INT NOT NULL DEFAULT 200,
  `coords` LONGTEXT NULL,
  `metadata` LONGTEXT NULL,
  `is_deleted` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_frontier_characters_user` (`user_id`),
  CONSTRAINT `fk_frontier_characters_user`
    FOREIGN KEY (`user_id`) REFERENCES `frontier_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_map_objects` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `model` VARCHAR(100) NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `rot_x` DOUBLE NOT NULL DEFAULT 0,
  `rot_y` DOUBLE NOT NULL DEFAULT 0,
  `rot_z` DOUBLE NOT NULL DEFAULT 0,
  `collision_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `frozen` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_frontier_map_objects_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_world_npcs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(64) NOT NULL,
  `model` VARCHAR(100) NOT NULL,
  `scenario` VARCHAR(100) NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `heading` DOUBLE NOT NULL DEFAULT 0,
  `created_by` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_frontier_world_npcs_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_storages` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(64) NOT NULL,
  `storage_type` ENUM('global','private') NOT NULL DEFAULT 'global',
  `capacity` INT UNSIGNED NOT NULL DEFAULT 100,
  `access_job` VARCHAR(32) NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `heading` DOUBLE NOT NULL DEFAULT 0,
  `interact_radius` DOUBLE NOT NULL DEFAULT 2,
  `created_by` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_frontier_storages_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_storage_inventories` (
  `storage_id` BIGINT UNSIGNED NOT NULL,
  `owner_key` VARCHAR(64) NOT NULL,
  `items` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`storage_id`, `owner_key`),
  CONSTRAINT `fk_frontier_storage_inventory_storage`
    FOREIGN KEY (`storage_id`) REFERENCES `frontier_storages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_doors` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(64) NOT NULL,
  `model_hash` BIGINT NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `heading` DOUBLE NOT NULL DEFAULT 0,
  `locked` TINYINT(1) NOT NULL DEFAULT 1,
  `access_job` VARCHAR(32) NULL,
  `interact_radius` DOUBLE NOT NULL DEFAULT 2,
  `created_by` VARCHAR(64) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_frontier_doors_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_admin_permissions` (
  `identifier` VARCHAR(100) NOT NULL,
  `display_name` VARCHAR(80) NOT NULL,
  `permissions` LONGTEXT NOT NULL,
  `assigned_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_crafting_recipes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(64) NOT NULL,
  `description` VARCHAR(255) NULL,
  `output_item` VARCHAR(64) NOT NULL,
  `output_amount` INT UNSIGNED NOT NULL DEFAULT 1,
  `ingredients` LONGTEXT NOT NULL,
  `duration_ms` INT UNSIGNED NOT NULL DEFAULT 1000,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `frontier_crafting_points` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `label` VARCHAR(64) NOT NULL,
  `x` DOUBLE NOT NULL,
  `y` DOUBLE NOT NULL,
  `z` DOUBLE NOT NULL,
  `heading` DOUBLE NOT NULL DEFAULT 0,
  `interact_radius` DOUBLE NOT NULL DEFAULT 2,
  `access_job` VARCHAR(32) NULL,
  `recipe_ids` LONGTEXT NOT NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_frontier_crafting_points_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
