-- TEOT: usable bandage item for fks_deadmoon bleeding treatment.
-- Standard VORP `items` table. Safe to re-run.
INSERT INTO `items` (`item`, `label`, `limit`, `can_remove`, `type`, `usable`, `desc`)
VALUES ('bandage', 'Бинт', 10, 1, 'item_standard', 1, 'Останавливает кровотечение после укуса заражённого.')
ON DUPLICATE KEY UPDATE
    `label` = VALUES(`label`),
    `usable` = 1,
    `desc` = VALUES(`desc`);
