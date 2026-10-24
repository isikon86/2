# Paranormal RedM bundle

Вся игровая логика теперь находится внутри ресурса `fks_deadmoon`:

- призрачные боссы появляются только во время `fksDeadmoonWeather` — красного Deadmoon-события на каждом седьмом игровом дне;
- поезд создаётся нативным RedM каждую ночь с 00:00 до 03:00;
- два места `ricx_ghostship` добавлены в `fks_deadmoon` как компактные зомби-данжи;
- модели, AI, звуки, сетевое владение и лут зомби остаются из вашего `fks_deadmoon`.

## Установка

1. Из этого каталога скопируйте соседние ресурсы в папку `resources`:
   - `LRRP_GhostHunting` (имя папки менять нельзя);
   - `ricx_ghostship`;
   - `fks_deadmoon`.
2. Оставьте исходную настройку фреймворка в `LRRP_GhostHunting` и `ricx_ghostship`.
3. В `server.cfg` запускайте в таком порядке:

   ```cfg
   ensure ricx_ghostship
   ensure LRRP_GhostHunting
   ensure fks_deadmoon
   ```

`fks_deadmoon` нужно запускать после фреймворка и инвентаря. В его `config.lua` сейчас включён
круглосуточный режим (`Config.Time.alwaysOn = true`), поэтому зомби работают и на корабле.
Два корабля добавлены в `Config.CitySpawns.zones` как зоны радиусом 65 м и лимитом 16 зомби.
После зачистки Deadmoon запускает свою стандартную двухволновую схему данжа.
Управление: `/deadmoon on`, `/deadmoon off`, `/deadmoon horde`.
Для проверки призрачного события без ожидания седьмого дня используйте `/deadmoon ghost on`,
а затем верните расписание командой `/deadmoon ghost auto`.

`LRRP_GhostHunting` и `ricx_ghostship` содержат Cfx escrow-файлы (`FXAP`), поэтому их исходную логику нельзя безопасно переписать в этом пакете. Координаты призраков, закрытые escrow в исходном охотничьем ресурсе, нельзя автоматически извлечь; два доступных босса заданы в `fks_deadmoon/config.lua` и редактируются вручную.

4. Проверьте `fks_deadmoon/config.lua`: координаты боссов должны соответствовать вашей карте, а точки `Config.GhostTrain.route` должны находиться на существующих рельсах.
5. Для VORP импортируйте `LRRP_GhostHunting/install_vorp.sql`; для RSG перенесите `rsg_items.lua` в конфигурацию предметов.

## Файлы внутри `fks_deadmoon`

- `config.lua` — расписание, точки боссов, маршрут поезда, зоны кораблей и параметры зомби;
- `client/ghosts.lua` — спавн, бой и удаление призрачных боссов;
- `client/ghost_train.lua` — ночной поезд и выбор одного сетевого контроллера;
- `server/ghosts.lua` — проверка победы над боссом и серверное событие награды;
- `client/zombies.lua`, `server/main.lua`, `server/city_population.lua` — исходная логика Deadmoon.

## Про `GhostTrainOdds.asi`

`GhostTrainOdds.asi` — Windows ASI/DLL, а не RedM resource. Он не подключается через `fxmanifest.lua` и не запускается в Linux-среде RedM. Поезд реализован в `fks_deadmoon/client/ghost_train.lua`.

## Настройка наград

После убийства босса сервер вызывает событие `lrrp_paranormal_merge:rewardBoss` и отправляет клиентское событие `lrrp_paranormal_merge:bossReward`. Добавьте выдачу предмета в серверном обработчике под используемый инвентарь. Защищённые escrow-файлы исходных ресурсов не изменяются.
