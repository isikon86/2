# LRRP Paranormal Merge

Это объединённый пакет для RedM/RDR3. Он сохраняет исходные ресурсы и добавляет общий слой игрового процесса:

- призраки из `LRRP_GhostHunting` выступают как отдельные боссы из `config.lua`;
- поезд создаётся нативным `CreateMissionTrain` и просто движется по рельсам;
- координаты `ricx_ghostship` превращены в данжи: после входа идут три волны зомби.

## Установка

1. Скопируйте три вложенных ресурса рядом с ресурсом-обвязкой:
   - `LRRP_GhostHunting` (имя папки менять нельзя);
   - `ricx_ghostship`;
   - `lrrp_paranormal_merge`.
2. Оставьте исходную настройку фреймворка в `LRRP_GhostHunting` и `ricx_ghostship`.
3. В `server.cfg` запускайте в таком порядке:

   ```cfg
   ensure ricx_ghostship
   ensure LRRP_GhostHunting
   ensure lrrp_paranormal_merge
   ```

`LRRP_GhostHunting` и `ricx_ghostship` содержат Cfx escrow-файлы (`FXAP`), поэтому их исходную логику нельзя безопасно переписать в этом пакете. Обвязка добавляет боссов и данж поверх них. Если нужна только новая boss-логика без оригинального квеста охоты, не запускайте `LRRP_GhostHunting`; координаты и модели боссов всё равно настраиваются в `lrrp_paranormal_merge/config.lua`.

4. Проверьте `config.lua`: координаты боссов должны соответствовать вашим кейсам и карте, а точки `Config.Train.route` должны находиться на существующих рельсах.
5. Для VORP импортируйте `LRRP_GhostHunting/install_vorp.sql`; для RSG перенесите `rsg_items.lua` в конфигурацию предметов.

## Про `GhostTrainOdds.asi`

`GhostTrainOdds.asi` — Windows ASI/DLL, а не RedM resource. Он не подключается через `fxmanifest.lua` и не запускается в Linux-среде RedM. В этом пакете поезд реализован нативным RedM-скриптом; `.asi` сохранён в `optional/GhostTrainOdds.asi` только как исходный необязательный файл для отдельного совместимого ASI-loader на Windows.

## Настройка наград

После убийства босса сервер вызывает событие `lrrp_paranormal_merge:rewardBoss` и отправляет клиентское событие `lrrp_paranormal_merge:bossReward`. Добавьте выдачу предмета в серверном обработчике под используемый инвентарь. Защищённые escrow-файлы исходных ресурсов не изменяются.
