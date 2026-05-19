<div align="right">

[![English](https://img.shields.io/badge/lang-English-blue?style=for-the-badge)](README.md)
[![Русский](https://img.shields.io/badge/lang-Русский-red?style=for-the-badge)](README.ru.md)

</div>

# Claude Code Notifications

Скилл-визард, который настраивает нативные десктоп-уведомления для [Claude Code](https://docs.claude.com/en/docs/claude-code) на **macOS**, **Linux** и **Windows**: всплывашка, когда Claude закончил ход, когда инструменту нужно подтверждение, или когда ждёт ответа на интерактивный вопрос.

Под капотом — хуки `Stop` / `PermissionRequest` в `~/.claude/settings.json`. Каждый хук вызывает небольшой скрипт-обёртку, который **подавляет уведомление, если в фокусе терминал** — как делают Slack или VS Code: приложение в фокусе само себя не пингует.

## Зачем это нужно

По умолчанию Claude Code молчит — если ты переключился в браузер пока он работает, ты упустишь момент когда он закончил или попросил подтверждение на команду. Этот скилл расставляет:

- 🔔 **Stop** — «ответ готов» сразу после конца хода
- 🚦 **PermissionRequest** — отдельные уведомления (и при желании разные звуки) для разрешения инструментов (`Bash`/`Edit`/`Write`/...) и для интерактивных вопросов (`AskUserQuestion`/`ExitPlanMode`)
- 🙈 **Гард по фокусу** — молча пропускается, когда терминал на экране
- 🔊 Звук на каждую категорию отдельно, на каждой ОС свои
- 🖼 Иконка (по желанию — из Claude Desktop, если он установлен)

## Установка

```bash
git clone https://github.com/<your-username>/claude-code-notifications.git ~/.claude/skills/claude-code-notifications
```

В любой сессии Claude Code:

```
/skill claude-code-notifications
```

Claude проведёт по шагам:

1. Определит ОС, проверит наличие `terminal-notifier` / `notify-send` / `BurntToast`. Если чего-то нет — предложит поставить через `brew` / `apt` / `Install-Module`. Без явного «да» — ничего не ставит.
2. Спросит, какие хуки включать (Stop / PermissionRequest на инструменты / PermissionRequest на вопросы / idle Notification).
3. Спросит язык текстов (English / Russian / свой).
4. Спросит, один звук на всё или разные по категориям, и какие именно.
5. Спросит про иконку — из Claude Desktop, свой PNG-файл или без иконки.
6. Спросит, подавлять ли уведомления при фокусе на терминале (рекомендуется).
7. Установит скрипт-обёртку в `~/.claude/bin/notify.<sh|ps1>` и пропатчит `~/.claude/settings.json`.
8. Прогонит pipe-тест каждого хука, чтобы ты подтвердил что плашки реально прилетают.

## Прослушать звуки macOS

Визард предлагает дефолт на категорию, но можно сначала прослушать все:

```bash
for s in /System/Library/Sounds/*.aiff; do
  echo "$(basename "$s" .aiff)"
  afplay "$s"
  sleep 0.3
done
```

Или открыть в Finder и тыкать пробел (QuickLook):

```bash
open /System/Library/Sounds/
```

## Платформы

| ОС | Бэкенд | Звук | Иконка | Focus guard |
|---|---|---|---|---|
| macOS 12+ | `terminal-notifier` (fallback — `osascript`) | `/System/Library/Sounds/*.aiff` | `-contentImage` (большая справа) — `-appIcon` macOS 13+ молча игнорирует | `osascript` по bundle ID |
| Linux (X11) | `notify-send` + `paplay`/`aplay` | имя event-звука или путь к `.wav`/`.ogg` | `notify-send -i` | `xdotool getactivewindow getwindowclassname` |
| Linux (Wayland) | `notify-send` + `paplay` | то же | то же | best-effort через `hyprctl` / `swaymsg`, иначе всегда уведомляет |
| Windows 10/11 | модуль `BurntToast` для PowerShell | имя пресета (`IM`, `Reminder`, …) или `.wav` | `-AppLogo` | `GetForegroundWindow` через P/Invoke |

## Подводные камни

- **macOS 13+ игнорирует `-appIcon`** — в левом верхнем углу всегда отправитель (terminal-notifier). Кастомизируется только `-contentImage` (большая картинка справа). Это ограничение системы, не скилла.
- **Wayland focus detection** ненадёжен вне Hyprland/Sway. В таких случаях обёртка не подавляет уведомления — будут приходить всегда.
- **BurntToast** требует Windows Store / MSIX-style отправителя — в плашке будет «PowerShell» как имя, если не зарегистрировать кастомный AppId. Визард про это говорит.
- **Иконка не идёт в комплекте**. Если выбрать «из Claude Desktop» — визард извлечёт её из твоего локального `/Applications/Claude.app` (только macOS). Авторские права на иконку — у Anthropic, остаются на твоей машине.

## Лицензия

MIT — см. [LICENSE](LICENSE).

## Помощь и развитие

Issues и PR приветствуются. Особенно:
- Новые bundle ID / WM-классы терминалов для focus guard
- Переводы фразбука уведомлений
- Полировка Windows-части (регистрация кастомного AppId для нормального имени отправителя)
