# LinkedIn Post #2 — Tech Deep Dive (через 1-2 недели после launch)

**Тема:** «Как я выбирал модель для казахского — research, бенчи, цифры»
**Цель:** показать инженерный подход, не "вайб-кодинг"
**CTA:** ссылка на research-доку в репо

---

## 🇷🇺 Версия

🧪 На прошлой неделе зарелизил Saqta. Сегодня — почему я **не** взял топовый Qwen3.5-Omni-Plus и оставил локальный Whisper.

TL;DR: 96.7% сходство при 0$ vs $0.30 на встречу. Дельта 3.3% — мусор после саммари.

**Сетап эксперимента:**
- 1 час реальной встречи Казахтелекома (русский + казахские термины)
- Whisper-large-v3-russian (antony66) + Silero VAD + initial prompt словарь
- Qwen3.5-Omni-Plus через DashScope API (10-минутные чанки)
- difflib.SequenceMatcher на нормализованном тексте

**Результаты:**
| Метрика | Whisper | Qwen3.5-Omni |
|---|---|---|
| Слов | 6 874 | 7 368 |
| Время | 5 мин | 7 мин |
| Стоимость | 0₸ | ~150₸ |
| Сходство | base | **96.7%** |

**Где Qwen побеждает:**
✓ «Smallworld» одним словом vs «смолворд»
✓ Микро-диалоги на стыках («Простите — Да, слушаю»)
✓ Естественнее пунктуация

**Где Whisper не уступает:**
✓ Имена коллег — оба точны (Марат, Канат, Татьяна Викторовна)
✓ Цифры (47 млн тенге, 16%, приказ № 236) — оба ок
✓ Покрытие основного смысла идентично

**Итог:**
Для рутинных встреч Whisper-russian + словарь = ~97% задачи **бесплатно**.
3% от Qwen3.5-Omni не оправдывают $0.30/встреча × N в месяц, особенно если транскрипт всё равно идёт через LLM для саммари (LLM нивелирует мелкие огрехи ASR).

**Когда я бы взял Qwen3.5-Omni:**
1. Шумная запись / плохой микрофон
2. Юридический / медицинский транскрипт
3. Корпоративная инфра с GPU (Qwen3.5-Omni Light open weights через vLLM = бесплатно для всей команды)

**Также проверял и выкинул:**
❌ Qwen3-ASR-1.7B локально на M4 Pro — в 8-10 раз медленнее whisper.cpp (50 мин vs 5 мин на час). Качество между, скорость не оправдывает.
❌ qwen3:14b как локальный саммаризатор через Ollama — context truncation отъедала половину встречи

Полный research: https://github.com/moldabayevd/saqta/blob/main/docs/research-qwen3.5-omni.md

Главный takeaway: **бенчмарк на чужом датасете ≠ работает на твоих данных**. На LMSys Arena Qwen3.5-Omni красавчик, на твоей часовой встрече разница в шум.

#mlops #ai #benchmarking #opensource #cost_optimization

---

## 🇬🇧 EN

🧪 Last week I released Saqta. Today — why I **didn't** use top-tier Qwen3.5-Omni-Plus and stuck with local Whisper.

TL;DR: 96.7% similarity at $0 vs $0.30 per meeting. The 3.3% delta is noise after summarization.

**Experiment setup:**
- 1-hour real Kazakhtelecom meeting (Russian + Kazakh terms)
- Whisper-large-v3-russian (antony66) + Silero VAD + initial prompt vocab
- Qwen3.5-Omni-Plus via DashScope API (10-min chunks)
- difflib.SequenceMatcher on normalized text

**Results:**
| Metric | Whisper | Qwen3.5-Omni |
|---|---|---|
| Words | 6,874 | 7,368 |
| Time | 5 min | 7 min |
| Cost | $0 | ~$0.30 |
| Similarity | base | **96.7%** |

**Where Qwen wins:**
✓ Complex terms ("Smallworld" vs phonetic spelling)
✓ Micro-dialogs at boundaries
✓ More natural punctuation

**Where Whisper doesn't lose:**
✓ Proper names — both correct
✓ Numbers (47M KZT, 16%, decree #236) — both fine
✓ Core meaning coverage — identical

**Conclusion:**
For routine meetings Whisper-russian + vocab = ~97% of the job for **free**. The 3% Qwen advantage doesn't justify $0.30/meeting × N per month — especially if the transcript goes through an LLM for summarization anyway (LLM smooths over small ASR mistakes).

**When I would use Qwen3.5-Omni:**
1. Noisy recording / bad mic
2. Legal / medical transcript
3. Corporate GPU infra (Qwen3.5-Omni Light open weights via vLLM = free for the team)

**Also tested and dropped:**
❌ Qwen3-ASR-1.7B locally on M4 Pro — 8-10x slower than whisper.cpp
❌ qwen3:14b as local summarizer via Ollama — context truncation issues

Full research: https://github.com/moldabayevd/saqta/blob/main/docs/research-qwen3.5-omni.md

Main takeaway: **benchmark on someone else's dataset ≠ works on yours**. On LMSys Arena Qwen3.5-Omni is great. On your 1-hour meeting the difference is noise.

#mlops #ai #benchmarking #opensource

---

## 📸 Картинки

1. **Bar chart**: Whisper bars vs Qwen bars по метрикам
2. **Скриншот** двух транскриптов side-by-side с подсвеченными отличиями
3. (опц) **Diff** таблицы из research-доки
