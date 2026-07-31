CREATE TABLE IF NOT EXISTS `millennium_punishments` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `target_identifier` VARCHAR(100) NOT NULL,
  `target_name` VARCHAR(100) NULL,
  `staff_identifier` VARCHAR(100) NOT NULL,
  `staff_name` VARCHAR(100) NOT NULL,
  `type` ENUM('warning','ban') NOT NULL,
  `reason` VARCHAR(500) NOT NULL,
  `evidence` VARCHAR(1000) NULL,
  `appeal_reference` VARCHAR(100) NULL,
  `expires_at` DATETIME NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_punishment_target` (`target_identifier`, `active`, `type`),
  INDEX `idx_punishment_expiry` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `millennium_audit` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `staff_identifier` VARCHAR(100) NOT NULL,
  `staff_name` VARCHAR(120) NOT NULL,
  `target_identifier` VARCHAR(100) NULL,
  `target_name` VARCHAR(120) NULL,
  `action` VARCHAR(80) NOT NULL,
  `reason` VARCHAR(500) NULL,
  `coordinates` VARCHAR(100) NULL,
  `previous_value` JSON NULL,
  `new_value` JSON NULL,
  `evidence` VARCHAR(1000) NULL,
  `session_id` VARCHAR(100) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_audit_staff` (`staff_identifier`),
  INDEX `idx_audit_target` (`target_identifier`),
  INDEX `idx_audit_action` (`action`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `millennium_notes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `target_identifier` VARCHAR(100) NOT NULL,
  `staff_identifier` VARCHAR(100) NOT NULL,
  `staff_name` VARCHAR(100) NOT NULL,
  `note` VARCHAR(500) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_note_target` (`target_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `millennium_staff` (
  `identifier` VARCHAR(100) NOT NULL,
  `role` VARCHAR(50) NOT NULL,
  `display_name` VARCHAR(100) NULL,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
