# LinkedIn Post #1 — Launch Announcement

**Время постить:** вторник-четверг, 9-11 утра по Алматы
**Тон:** уверенный, без выпендрёжа, с цифрами
**CTA:** GitHub link + комментарий «попробуйте, дайте фидбек»
**Hashtags:** #opensource #ai #kazakhstan #whisper #productivity

---

## 🇷🇺 Версия на русском

🚀 Зарелизил **Saqta v0.1** — open-source локальный транскрайбер встреч для macOS с поддержкой казахского языка и kk/ru code-switching.

Контекст: устал платить $20/мес за Otter и каждый раз гадать "а сейчас он передаст слова Марата в облако или нет?". Особенно когда встреча на смеси казахского и русского — большинство облачных решений казахский **вообще не понимают**.

За 3 дня собрал свой пайплайн на bash + whisper.cpp:
✅ Запись через QuickRecorder (хоткей ⌘⇧R)
✅ Транскрипция через Whisper-large-v3-russian (antony66 fine-tune)
✅ Казахский + kk/ru code-switching через Qwen3-ASR-1.7B
✅ Автороутер языков — встреча на ru уходит на whisper, на kk — на Qwen3
✅ Markdown с YAML frontmatter — открывается в Obsidian
✅ Красивая TUI-менюшка через gum (никакого терминала)
✅ Двойной клик ярлычок на десктопе — записал → кликнул → готово

100% локально. Ноль облака. Ноль подписок.

**Бенчмарк на реальной часовой встрече Казахтелекома:**
- Whisper-russian (локально, бесплатно): baseline
- Qwen3.5-Omni-Plus (DashScope API, $0.30): 96.7% сходство
- Разница 3.3% — не оправдывает деньги для рутинных встреч

GitHub: https://github.com/moldabayevd/saqta

В планах (см. ROADMAP):
🔜 Tauri native UI вместо терминала (v0.2)
🔜 Speaker diarization без 2 дорожек (v0.3) — то за что Meetily берёт деньги
🔜 Live транскрипция во время записи (v0.4)
🔜 Personal LoRA на твоих встречах (v0.6)

Если работаете в Казахстане и устали что транскрайберы не понимают казахский — попробуйте, дайте фидбек. PR welcome.

#opensource #ai #kazakhstan #whisper #productivity #macos #privacyfirst

---

## 🇬🇧 English version

🚀 Released **Saqta v0.1** — open-source local meeting transcriber for macOS with native Kazakh language and kk/ru code-switching support.

Context: I got tired of paying $20/month for Otter and wondering each time "is it sending Marat's words to the cloud right now?". Especially when meetings happen in mixed Kazakh and Russian — most cloud solutions **don't understand Kazakh at all**.

In 3 days I built my own pipeline on bash + whisper.cpp:
✅ Recording via QuickRecorder (⌘⇧R hotkey)
✅ Transcription via Whisper-large-v3-russian (antony66 fine-tune)
✅ Kazakh + kk/ru code-switching via Qwen3-ASR-1.7B
✅ Auto language router — RU meetings go to whisper, KK to Qwen3
✅ Markdown with YAML frontmatter — opens in Obsidian
✅ Beautiful TUI menu via gum (no terminal needed)
✅ Double-click desktop shortcut — record → click → done

100% local. Zero cloud. Zero subscriptions.

**Benchmark on a real 1-hour Kazakhtelecom meeting:**
- Whisper-russian (local, free): baseline
- Qwen3.5-Omni-Plus (DashScope API, $0.30): 96.7% similarity
- 3.3% delta — not worth the cash for routine meetings

GitHub: https://github.com/moldabayevd/saqta

Roadmap:
🔜 Tauri native UI instead of terminal (v0.2)
🔜 Speaker diarization without 2 tracks (v0.3) — what Meetily charges for
🔜 Live transcription during recording (v0.4)
🔜 Personal LoRA on your own meetings (v0.6)

If you work in Central Asia and your transcriber doesn't speak Kazakh — try it, send feedback. PRs welcome.

#opensource #ai #centralasia #whisper #productivity #macos #privacyfirst

---

## 🇰🇿 Қазақша нұсқа (черновик, нужна редактура носителя)

🚀 **Saqta v0.1** жарияладым — macOS үшін ашық кодты, локалды
жиналыс транскрайбері. Қазақша және қазақша-орысша аралас сөйлеуді (code-switching)
қолдайды.

Otter сияқты бұлтты сервистерге айына $20 төлеуден шаршадым. Жиналыс
қазақ-орыс аралас өткенде, көп шетелдік сервистер қазақ тілін **мүлдем
түсінбейді**.

3 күнде bash + whisper.cpp негізінде өз пайплайнымды жинадым:
✅ QuickRecorder арқылы жазу (⌘⇧R)
✅ Whisper-large-v3-russian (antony66 fine-tune) арқылы транскрипция
✅ Qwen3-ASR-1.7B арқылы қазақ тілі мен code-switching
✅ Тіл автороутері — жиналыс орысша болса whisper-ге, қазақша болса Qwen3-ке
✅ Markdown шығу — Obsidian-да ашылады
✅ gum арқылы әдемі TUI меню (терминалсыз)

100% локалды. Бұлт жоқ. Жазылым жоқ.

GitHub: https://github.com/moldabayevd/saqta

Қазақстанда жұмыс істейтіндер үшін — байқап көріңіз, пікір жазыңыз.

#ашықкод #жасанды_интеллект #қазақстан

---

## 📸 Что приложить к посту

1. **Скриншот** TUI-меню `saqta` со списком записей и статусами
2. **GIF**: запуск меню → выбор записи → спиннер транскрибации → готовый .md в Obsidian (15-20 сек)
3. **Скриншот** результирующего .md в Obsidian с frontmatter и структурой
4. (опц) **Скриншот** сравнительной таблицы из ROADMAP «Meetily vs Saqta»

## 💡 Тактика

- Запостить **сначала по-русски** (твоя кор-аудитория в LinkedIn)
- Через 3-4 дня — английская версия с пометкой "EN version of last week's post"
- Казахская — через 1-2 недели как третий пост, выделит тебя в нише
- Закрепить (pin) лучший пост в профиле на месяц
- Ответить **первые 24 часа** на каждый комментарий — алгоритм буст
- Сделать reply-пост через неделю с **одной интересной метрикой** ("за неделю звёзд: X, форков: Y, скачали 3 человека из Турции — открываем международку")
