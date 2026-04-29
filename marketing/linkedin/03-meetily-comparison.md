# LinkedIn Post #3 — «Сделал Meetily PRO бесплатно за выходные»

**Время:** после релиза v0.3 (когда фичи реально готовы — не врать)
**Тон:** провокативный, цифры, таблица
**CTA:** "сравните сами / скачайте"

---

## 🇷🇺 Версия

🥷 Зарелизил v0.3 Saqta. Сделал за выходные то, за что Meetily просит подписку:

✅ Speaker diarization без 2 дорожек (pyannote.audio v3)
✅ PDF / DOCX экспорт (pandoc + кастомные шаблоны)
✅ Custom summary templates (protocol / 1on1 / interview / lecture)
✅ Гибкие LLM-провайдеры (Groq / OpenRouter / vLLM / LM Studio / Ollama / Claude)

|  | Meetily Free | Meetily PRO 💰 | Saqta v0.3 |
|---|---|---|---|
| Native UI | ✅ | ✅ | 🔜 v0.2 |
| Auto-detect | ❌ | ✅ | 🔜 v0.2 |
| Speaker diarization | ❌ | ✅ | **✅ free** |
| PDF/DOCX | ❌ | ✅ | **✅ free** |
| Custom templates | ❌ | ✅ | **✅ free** |
| Казахский язык | ❌ | ❌ | **✅** |
| kk+ru code-switching | ❌ | ❌ | **✅** |
| Initial prompt vocab | ❌ | ❌ | **✅** |
| Цена | 0 | $$$ | **0** |

Я не против чтобы Meetily зарабатывали — продукт у них хороший, ребята красиво упаковали Tauri-приложение. Но фичи которые они спрятали в PRO **не должны быть платными в 2026**:
- pyannote.audio v3.1 = open source, рабочая diarization
- pandoc → PDF/DOCX = это команда из 1 строки в bash
- Custom prompts = текстовые файлы в папке

Главное где они нас всё ещё бьют — **UX**: native app vs мой TUI. Но v0.2 (Tauri-обёртка) уже в роадмапе.

Где **мы** их бьём навсегда:
✓ Казахский + kk/ru code-switching (у них вообще не упомянуто)
✓ Whisper-russian fine-tune вместо vanilla
✓ Корпоративный словарь имён/терминов (initial prompt)
✓ 2-track diarization бесплатно
✓ Хакабельность — bash скрипты vs Rust+Next.js

GitHub: https://github.com/moldabayevd/saqta

Если ваша компания собирается купить Meetily PRO для 50 человек ($Х × 50 = большой счёт) — попробуйте сначала бесплатный аналог. PR welcome.

#opensource #productivity #ai #saas

---

## 🇬🇧 EN

🥷 Released v0.3 of Saqta. Built over the weekend everything Meetily charges a subscription for:

✅ Speaker diarization without 2 tracks (pyannote.audio v3)
✅ PDF / DOCX export (pandoc + custom templates)
✅ Custom summary templates (protocol / 1on1 / interview / lecture)
✅ Flexible LLM providers (Groq / OpenRouter / vLLM / LM Studio / Ollama / Claude)

[same table]

I'm not against Meetily making money — their product is good, they shipped a nice Tauri app. But features they locked behind PRO **shouldn't be paywalled in 2026**:
- pyannote.audio v3.1 = open source, working diarization out of the box
- pandoc → PDF/DOCX = one bash line
- Custom prompts = literally text files in a folder

Where they still beat us — **UX**: native app vs my TUI. But v0.2 (Tauri wrapper) is on the roadmap.

Where **we** beat them permanently:
✓ Kazakh + kk/ru code-switching (not mentioned in their product at all)
✓ Whisper-russian fine-tune instead of vanilla
✓ Corporate term/name vocabulary (initial prompt)
✓ 2-track diarization free
✓ Hackable — bash scripts vs Rust+Next.js

GitHub: https://github.com/moldabayevd/saqta

If your company is about to buy Meetily PRO for 50 people — try the free alternative first.

#opensource #productivity #ai #saas

---

## ⚠️ Дисклеймер

Не публикуй пока **реально** не сделал v0.3 фичи. Если переобещаешь — словишь хейт в комментах от Meetily-юзеров. Сначала commit, потом пост.
