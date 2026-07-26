CREATE TABLE IF NOT EXISTS `mscore_users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `license` VARCHAR(64) NOT NULL,
  `last_seen` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_mscore_users_license` (`license`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_characters` (
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
  KEY `idx_mscore_characters_user` (`user_id`),
  CONSTRAINT `fk_mscore_characters_user`
    FOREIGN KEY (`user_id`) REFERENCES `mscore_users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ms_bank_accounts` (
  `character_id` BIGINT UNSIGNED NOT NULL,
  `account_number` VARCHAR(24) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`),
  UNIQUE KEY `uq_ms_bank_accounts_number` (`account_number`),
  CONSTRAINT `fk_ms_bank_accounts_character`
    FOREIGN KEY (`character_id`) REFERENCES `mscore_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ms_bank_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `account_character_id` BIGINT UNSIGNED NOT NULL,
  `transaction_type` VARCHAR(24) NOT NULL,
  `amount` INT NOT NULL,
  `balance_after` INT UNSIGNED NOT NULL,
  `counterparty_account` VARCHAR(24) NULL,
  `description` VARCHAR(100) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ms_bank_transactions_account` (`account_character_id`, `id`),
  CONSTRAINT `fk_ms_bank_transactions_account`
    FOREIGN KEY (`account_character_id`)
    REFERENCES `ms_bank_accounts` (`character_id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_map_objects` (
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
  KEY `idx_mscore_map_objects_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_world_npcs` (
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
  KEY `idx_mscore_world_npcs_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_storages` (
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
  KEY `idx_mscore_storages_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_storage_inventories` (
  `storage_id` BIGINT UNSIGNED NOT NULL,
  `owner_key` VARCHAR(64) NOT NULL,
  `items` LONGTEXT NOT NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`storage_id`, `owner_key`),
  CONSTRAINT `fk_mscore_storage_inventory_storage`
    FOREIGN KEY (`storage_id`) REFERENCES `mscore_storages` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_doors` (
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
  KEY `idx_mscore_doors_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_admin_permissions` (
  `identifier` VARCHAR(100) NOT NULL,
  `display_name` VARCHAR(80) NOT NULL,
  `permissions` LONGTEXT NOT NULL,
  `assigned_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_support_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `event_type` VARCHAR(32) NOT NULL,
  `actor_source` INT UNSIGNED NULL,
  `actor_character_id` BIGINT UNSIGNED NULL,
  `actor_identifier` VARCHAR(100) NULL,
  `actor_name` VARCHAR(80) NOT NULL,
  `target_source` INT UNSIGNED NULL,
  `target_character_id` BIGINT UNSIGNED NULL,
  `target_identifier` VARCHAR(100) NULL,
  `target_name` VARCHAR(80) NULL,
  `damage_amount` INT UNSIGNED NULL,
  `weapon_hash` BIGINT NULL,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_mscore_support_logs_created` (`created_at`),
  KEY `idx_mscore_support_logs_type_time` (`event_type`, `created_at`),
  KEY `idx_mscore_support_logs_actor` (`actor_character_id`, `created_at`),
  KEY `idx_mscore_support_logs_target` (`target_character_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_items` (
  `name` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `description` VARCHAR(255) NULL,
  `category` VARCHAR(32) NOT NULL DEFAULT 'general',
  `rarity` ENUM('common','uncommon','rare','epic','legendary') NOT NULL DEFAULT 'common',
  `max_stack` INT UNSIGNED NOT NULL DEFAULT 1,
  `weight` INT UNSIGNED NOT NULL DEFAULT 0,
  `usable` TINYINT(1) NOT NULL DEFAULT 0,
  `consumable` TINYINT(1) NOT NULL DEFAULT 0,
  `unique_item` TINYINT(1) NOT NULL DEFAULT 0,
  `tradable` TINYINT(1) NOT NULL DEFAULT 1,
  `prop_model` VARCHAR(100) NULL,
  `image` VARCHAR(255) NULL,
  `metadata` LONGTEXT NULL,
  `is_system` TINYINT(1) NOT NULL DEFAULT 0,
  `created_by` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`name`),
  KEY `idx_mscore_items_category` (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `mscore_crafting_recipes` (
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

CREATE TABLE IF NOT EXISTS `mscore_crafting_points` (
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
  KEY `idx_mscore_crafting_points_position` (`x`, `y`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ms_stable_horses` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `name` VARCHAR(32) NOT NULL,
  `horse_key` VARCHAR(64) NOT NULL,
  `coat_key` VARCHAR(64) NOT NULL,
  `model` VARCHAR(100) NOT NULL,
  `owned_equipment` LONGTEXT NOT NULL,
  `equipped` LONGTEXT NOT NULL,
  `owned_coats` LONGTEXT NOT NULL,
  `purchased_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ms_stable_horses_character` (`character_id`),
  CONSTRAINT `fk_ms_stable_horses_character`
    FOREIGN KEY (`character_id`) REFERENCES `mscore_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ms_stable_wagons` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `character_id` BIGINT UNSIGNED NOT NULL,
  `wagon_key` VARCHAR(64) NOT NULL,
  `label` VARCHAR(64) NOT NULL,
  `model` VARCHAR(100) NOT NULL,
  `purchased_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_ms_stable_wagons_character` (`character_id`),
  CONSTRAINT `fk_ms_stable_wagons_character`
    FOREIGN KEY (`character_id`) REFERENCES `mscore_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ms_telegram_accounts` (
  `character_id` BIGINT UNSIGNED NOT NULL,
  `telegram_number` VARCHAR(16) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`),
  UNIQUE KEY `uq_ms_telegram_accounts_number` (`telegram_number`),
  CONSTRAINT `fk_ms_telegram_accounts_character`
    FOREIGN KEY (`character_id`) REFERENCES `mscore_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ms_telegrams` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `sender_character_id` BIGINT UNSIGNED NOT NULL,
  `sender_number` VARCHAR(16) NOT NULL,
  `sender_name` VARCHAR(80) NOT NULL,
  `recipient_character_id` BIGINT UNSIGNED NOT NULL,
  `recipient_number` VARCHAR(16) NOT NULL,
  `recipient_name` VARCHAR(80) NOT NULL,
  `subject` VARCHAR(64) NOT NULL,
  `body` TEXT NOT NULL,
  `sent_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `read_at` TIMESTAMP NULL DEFAULT NULL,
  `deleted_by_sender` TINYINT(1) NOT NULL DEFAULT 0,
  `deleted_by_recipient` TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_ms_telegrams_sender` (`sender_character_id`, `sent_at`),
  KEY `idx_ms_telegrams_recipient` (`recipient_character_id`, `sent_at`),
  KEY `idx_ms_telegrams_unread` (`recipient_character_id`, `read_at`),
  CONSTRAINT `fk_ms_telegrams_sender`
    FOREIGN KEY (`sender_character_id`) REFERENCES `mscore_characters` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_ms_telegrams_recipient`
    FOREIGN KEY (`recipient_character_id`) REFERENCES `mscore_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ms_medic_diseases` (
  `character_id` BIGINT UNSIGNED NOT NULL,
  `disease_key` VARCHAR(64) NOT NULL,
  `severity` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `contracted_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`, `disease_key`),
  KEY `idx_ms_medic_diseases_key` (`disease_key`),
  CONSTRAINT `fk_ms_medic_diseases_character`
    FOREIGN KEY (`character_id`) REFERENCES `mscore_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `ms_jail_sentences` (
  `character_id` BIGINT UNSIGNED NOT NULL,
  `jailed_by` VARCHAR(100) NOT NULL,
  `reason` VARCHAR(180) NOT NULL,
  `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `release_at` TIMESTAMP NULL,
  `remaining_seconds` INT UNSIGNED NOT NULL DEFAULT 0,
  `last_update_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`character_id`),
  KEY `idx_ms_jail_release` (`release_at`),
  CONSTRAINT `fk_ms_jail_character`
    FOREIGN KEY (`character_id`) REFERENCES `mscore_characters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
