# 🖥️ Продолжить работу на Mac

Короткая шпаргалка — что сделать завтра, когда сядешь за мак.

## 1. Склонировать репо

```bash
cd ~/Projects   # или куда удобно
git clone https://github.com/moldabayevd/kt-recorder.git
cd kt-recorder
```

## 2. Настроить git (если ещё не)

```bash
git config user.name "moldabayevd"
git config user.email "moldabayevd@users.noreply.github.com"
```

Проверь что `gh` авторизован:

```bash
gh auth status
# если нет:
gh auth login
```

## 3. Установить зависимости

Нужны: **Homebrew**, **ffmpeg**, **whisper.cpp**, **BlackHole** (для захвата системного звука).

```bash
# Homebrew (если нет)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Зависимости
brew install ffmpeg
brew install --cask blackhole-2ch

# whisper.cpp
git clone https://github.com/ggml-org/whisper.cpp ~/whisper.cpp
cd ~/whisper.cpp && make -j && bash ./models/download-ggml-model.sh large-v3
```

## 4. Запустить установщик проекта

```bash
cd ~/Projects/kt-recorder
./install.sh
```

Скрипт настроит пути, launchagent и хоткеи. Если что-то сломается — см. [docs/troubleshooting.md](docs/troubleshooting.md).

## 5. Проверить что работает

```bash
# тестовая транскрибация любого аудио
./scripts/transcribe-file.sh path/to/test.m4a
```

## 6. Рабочий цикл

```bash
git pull                    # подтянуть изменения (если правил с другой машины)
# ... правишь код ...
git add -A
git commit -m "описание"
git push
```

## 📌 Что ещё на потом

- [ ] Записать демо-гифку → `assets/demo.gif` (см. TODO в README)
- [ ] Добавить скриншоты в `assets/`
- [ ] Прогнать `./install.sh` на чистой системе для проверки

## 🔗 Полезные ссылки

- Репо: https://github.com/moldabayevd/kt-recorder
- Архитектура: [docs/architecture.md](docs/architecture.md)
- Траблшутинг: [docs/troubleshooting.md](docs/troubleshooting.md)
- whisper.cpp: https://github.com/ggml-org/whisper.cpp
