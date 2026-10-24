# LRRP_GhostHunting v0.1.20 FREE

# LRRP_GhostHunting v0.1.19 DEV

Story-driven RedM paranormal investigation resource.

## Edition
**FREE:** Full Case 1 (Mary Hargrove) is playable. After Mary's Locket is returned to the Van Horn Ghost Hunter, the locket is deleted from inventory, Case 1 is recorded complete, Case 2 remains locked, and the player is shown: **Please upgrade to premium to carry on the quest line.**

Replacing FREE with PREMIUM preserves progress and automatically unlocks Case 2.

**Resource/folder name must remain:** `LRRP_GhostHunting`

## Locked design
- Permanent Ghost Hunter NPC at `2945.2383, 517.5995, 45.3310, 11.8799` in Van Horn.
- NPC uses a smoking idle and stops/turns to the player during dialogue.
- v0.1.3: investigator uses a non-apron Van Horn male model, is grounded before freezing, and uses native bottom-right G prompts instead of floating world text.
- v0.1.6: detector pulse upgraded to a brighter dual-layer core + halo light for much clearer hot/cold feedback.
- v0.1.4: dialogue now uses the medic-style vertical choice layout fully inside the parchment inner panel.
- v0.1.4: journal now uses the exact square notebook aspect ratio/page boxes from the supplied medic notebook, fixing right-page overflow.
- v0.1.4: detector now equips the real native `WEAPON_KIT_METAL_DETECTOR` instead of creating a guessed prop model.
- First accepted interaction gives `ghost_journal` + `ghost_detector`.
- Journal opens by using the inventory item. It reuses the LRRP medical notebook visual foundation supplied for this build.
- Investigator and spirit conversations reuse the LRRP medical multiple-choice dialogue visual foundation.
- Ghost activity is mechanically limited to 20:00-05:00. The story does not bluntly tell players this; case reports contain nighttime sighting clues.
- Hunter Vision default key: CAPS LOCK.
- Ghosts are normally hidden; Hunter Vision reveals them at ~30% opacity.
- Detector signal speeds up as the player approaches paranormal sources. At direct contact the detector light remains continuously on.
- Evidence changes journal data dynamically: Unknown Spirit -> first name -> full name, plus cause-of-death notes.
- Each case ends with a quest relic. The relic is NOT the reward. It must be returned to Van Horn.
- On a successful hand-in the server verifies the item, deletes it from inventory, records it as delivered, and unlocks the next case.
- After all eight relics are delivered, all eight spirits form a visible circle around the player without Hunter Vision, thank the player, fade through the same proven `SCR_ADV_SOK / scr_adv_sok_torchsmoke` family used by LRRP_Vampire, and the player receives the exclusive `spirit_hunters_relic`.

## Install - VORP
1. Put `LRRP_GhostHunting` in resources.
2. Import `install_vorp.sql`.
3. Copy the PNGs from `inventory_images/` into your inventory image folder if required by your inventory UI.
4. Ensure `vorp_core` and `vorp_inventory` start first.
5. `ensure LRRP_GhostHunting`

## Install - RSG
1. Set `Config.Framework = 'rsg'`.
2. Merge `rsg_items.lua` into your RSG item definitions.
3. Copy inventory icons as required.
4. Ensure `rsg-core` and `rsg-inventory` start first.

## Important test notes
The full eight-case quest engine is wired and the case coordinates are editable in `config.lua`. This is a DEV/test build so each location should be walked once in your server and coordinates adjusted for your map/MLO setup if needed.

The detector uses the native RedM held weapon `WEAPON_KIT_METAL_DETECTOR`. The resource gives/equips it while the inventory detector item is active and removes the temporary native weapon again when put away.

Progress is stored per-character in server KVP storage, with `data/progress.json` retained only as a legacy fallback. No extra progression SQL table is required.


## v0.1.11 DEV
- Fixed RDR3 CREATE_PED signature for ghost entities (missing pedType was preventing Mary/other ghosts from spawning).
- Added visible particle glow inside the native metal detector glass while the signal is active.
- Increased Hunter Vision ghost alpha for clearer testing.


### v0.1.11 test fixes
- Ghost spawning now uses the same RedM CreatePed path as the working investigator, with raw fallbacks.
- Hunter Vision forces full ghost alpha and attaches the native Agnes Dowd ghost haze.
- Detector chamber uses confirmed RDR3 scr_generic/scr_gen_shiny_bling PTFX plus a local vertical light fill through the glass.


## v0.1.13 persistence fix
- Story progress now persists in server KVP storage and survives resource folder updates/replacements.
- Automatically recovers Case 1 when an older DEV update wiped progress but the character still owns the Ghost Hunter journal or detector.
- This restores Hunter Vision, Mary spawning and the custom detector hot/cold glow for affected test characters.

## v0.1.14 gameplay cleanup
- Mary now wanders within a 12m haunted area again.
- Hunter Vision reveals Mary at approximately 30% opacity.
- First contact is no longer an automatic journal trigger. Walk close while using Hunter Vision and press G to speak to Mary.
- Mary stops, faces the player and remains manifested during the parchment dialogue, then resumes wandering after the conversation closes.
- Mary's opening line is: “Wait… you can see me?”
- The first conversation updates the journal from Unknown Spirit to Mary.
- Case 1 clue progression after first contact now waits until Mary has been spoken to.
- Detector world spill has been drastically reduced. The visible effect is concentrated inside the native metal detector glass with only a small local halo.


## v0.1.16 dialogue + quest guidance
- Ghost Hunter and ghost replies no longer auto-dismiss.
- After selecting a dialogue option, the reply remains on screen until the player clicks Continue or presses Enter.
- Closing the parchment before continuing does not complete or advance the conversation.
- Added a clear NEXT STEP section to the active journal case with simple instructions that adapt as the investigation progresses.
- Investigator advice now explains the basic loop clearly without directly revealing the global 20:00-05:00 rule.


## v0.1.17 DEV
- Fixed first Investigator handoff on VORP: journal and detector now use the same synchronous inventory export pattern as LRRP Medic.
- The server verifies both items were actually added before Case 1 begins.
- Investigator explicitly tells the player he is handing over the journal and detector.


## v0.1.18 DEV fixes
- Fixed recovered quest relics being added to inventory without updating the journal/progression.
- Fixed relic hand-in so the quest item is verified as removed before the next case advances.
- Fixed final exclusive reward handoff to use the same synchronous VORP inventory pattern.
- Added automatic recovery: if the current quest relic is already in inventory, the journal marks it recovered on state load.


## v0.1.19 EASY QUEST PASS
- All eight cases now show a named LOCATION and clear SEARCH AREA in the journal.
- Initial objectives name the actual town/region and landmark instead of saying only “reported location”.
- Every post-conversation clue is sequential and uses a bottom-right G interaction prompt.
- Detector hot/cold guidance now tracks the next active clue, not just the final relic, so it leads the player through the case step by step.
- Clue interaction radii were increased for easier discovery.
- Relic pickup prompts only appear after the spirit has been fully identified.
- Before a ghost gives its name, the interaction prompt says “Speak to Spirit”; after learning it, the prompt uses the ghost’s name.
- Investigator “What should I do next?” dialogue now repeats the named location and search area.

## v0.1.23 - Investigator item handoff fix
- Fixed incorrect argument order in VORP getItemCount checks.
- Correctly verifies journal and detector delivery at first interaction, along with quest relic pickup/hand-in and final reward delivery.
- Existing character progress is preserved.
- Install install_vorp.sql item definitions if the items are not present in the inventory database.


v0.1.24: Restores missing journal and detector for players with previously started quests on Hunter interaction; failed addItem results now logged. Install install_vorp.sql into the SAME database used by LRRP_Inventory, then restart LRRP_Inventory / vorp_inventory bridge and Ghost Hunting.
