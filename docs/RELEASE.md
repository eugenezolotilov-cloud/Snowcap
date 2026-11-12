# GitHub About and release text · Описание и текст релиза

## About — English

Interactive desktop snowfall for macOS with window drifts, adjustable wind and throwable snowballs. A Swift and Metal fork of Snowhush.

## About — Русский

Интерактивный снегопад для macOS со снегом на окнах, регулируемым направлением и снежками. Форк Snowhush на Swift и Metal.

## Release notes — English

Snowcap brings interactive snowfall to the macOS menu bar. Adjust intensity, fall speed and direction, or pause with one click. Hold Control to collect settled snow into a snowball, then release it to throw. Advanced Settings groups the controls into five sections. The installer features a winter landscape and “Let it snow” lettering.

Built on [Snowhush by Mykhailo Bezruchko](https://github.com/mbezruchko/Snowhush). The universal app targets macOS 14 and later on Apple silicon and Intel. Distributed under the [PolyForm Noncommercial License 1.0.0](../LICENSE).

## Описание релиза — Русский

Snowcap добавляет интерактивный снегопад в строку меню macOS. Настраивайте интенсивность, скорость и направление или ставьте снегопад на паузу одной кнопкой. Удерживайте Control, чтобы собрать лежащий снег в снежок, и отпустите клавишу для броска. Расширенные настройки разбиты на пять разделов. В установочном образе — зимний пейзаж и надпись «Let it snow».

В основе — [Snowhush Михаила Безручко](https://github.com/mbezruchko/Snowhush). Универсальная сборка рассчитана на macOS 14 и новее с Apple silicon или Intel. Лицензия — [PolyForm Noncommercial 1.0.0](../LICENSE).

## Preparing the release · Подготовка релиза

Publish the source tree as the repository and attach `Snowcap.dmg` to a GitHub Release. Choose a tag matching the app version you intend to distribute. The default local DMG contains an ad hoc signed app. Before distributing a public binary, build with your Developer ID Application identity, notarize the DMG and verify it on a clean Mac. Keep `LICENSE` and the third-party notices in both the source and the application bundle.

Загрузите дерево исходников в репозиторий, а `Snowcap.dmg` прикрепите к GitHub Release. Выберите тег, соответствующий версии публикуемого приложения. В локальном DMG используется подпись ad hoc. Для публичной раздачи готового приложения используйте свой Developer ID Application, нотариализируйте DMG и проверьте установку на чистом Mac. Сохраните `LICENSE` и уведомления о сторонних лицензиях в исходниках и внутри приложения.
