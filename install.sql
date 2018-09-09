-- Creates tables for storing skin data
CREATE TABLE `skins` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`name` VARCHAR(250) NULL DEFAULT NULL,
	`skin` TEXT NULL,
	`active` INT(1) NULL DEFAULT NULL,
	`identifier` VARCHAR(250) NULL DEFAULT NULL,
	PRIMARY KEY (`id`),
	INDEX `identifier` (`identifier`),
	INDEX `active` (`active`)
);

-- Copies all users current skins from users table and inserts them into skins table
INSERT INTO skins (skin, identifier, active) SELECT skin, identifier, 1 FROM users WHERE skin IS NOT NULL;
