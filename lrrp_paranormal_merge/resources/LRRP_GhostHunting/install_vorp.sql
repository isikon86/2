-- LRRP_GhostHunting VORP inventory items
INSERT INTO `items` (`item`,`label`,`limit`,`can_remove`,`type`,`usable`) VALUES
('ghost_journal','Ghost Hunter Journal',1,1,'item_standard',1),
('ghost_detector','Ghost Hunting Device',1,1,'item_standard',1),
('ghost_relic_locket','Mary''s Locket',1,1,'item_standard',0),
('ghost_relic_medal','Broken Cavalry Medal',1,1,'item_standard',0),
('ghost_relic_funeral_token','Black Funeral Token',1,1,'item_standard',0),
('ghost_relic_bone_charm','Carved Bone Charm',1,1,'item_standard',0),
('ghost_relic_watch','Cracked Miner''s Watch',1,1,'item_standard',0),
('ghost_relic_coin','Waterlogged Silver Coin',1,1,'item_standard',0),
('ghost_relic_iron_sigil','Hangman''s Iron Sigil',1,1,'item_standard',0),
('ghost_relic_black_key','Blackened Key',1,1,'item_standard',0),
('spirit_hunters_relic','Spirit Hunter''s Relic',1,1,'item_standard',0)
ON DUPLICATE KEY UPDATE `label`=VALUES(`label`),`can_remove`=1,`type`='item_standard',`usable`=VALUES(`usable`);
