<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/core";
  import {
    listRecordings,
    getConfig,
    type Recording,
    type Config,
  } from "./lib/api";
  import { HEADER, EMPTY_STATE } from "./lib/strings";
  import RecordingCard from "./lib/Recording.svelte";
  import Widget from "./lib/Widget.svelte";

  let widgetMode: boolean | null = null;

  let recordings: Recording[] = [];
  let config: Config | null = null;
  let loading = true;
  let error = "";

  async function reload() {
    loading = true;
    error = "";
    try {
      recordings = await listRecordings();
      if (!config) config = await getConfig();
    } catch (e) {
      error = String(e);
    } finally {
      loading = false;
    }
  }

  onMount(async () => {
    try {
      widgetMode = await invoke<boolean>("is_widget_mode");
    } catch {
      widgetMode = false;
    }
    if (!widgetMode) await reload();
  });

  async function openQuickRecorder() {
    try {
      await invoke("start_quick_recorder");
    } catch {
      // Fallback на URL-схему если приложения нет
      window.open("quickrecorder://", "_self");
    }
  }
</script>

{#if widgetMode === null}
  <!-- Ничего не показываем пока не определились с режимом -->
{:else if widgetMode}
  <Widget />
{:else}
<main>
  <header>
    <div class="brand">
      <img src="/saqta-logo.png" alt="" class="logo" />
      <div>
        <h1>{HEADER.title}</h1>
        <p class="subtitle">{HEADER.subtitle}</p>
      </div>
    </div>
    <button
      class="reload"
      on:click={reload}
      disabled={loading}
      title="Обновить список записей"
      aria-label="Обновить"
    >
      {loading ? "↻" : "⟳"}
    </button>
  </header>

  {#if loading && recordings.length === 0}
    <div class="loader">
      <div class="spinner-big" />
      <p>Ищу ваши записи...</p>
    </div>
  {:else if error}
    <div class="error-box">
      <h3>⚠️ Что-то пошло не так</h3>
      <pre>{error}</pre>
      <button class="primary" on:click={reload}>Попробовать снова</button>
    </div>
  {:else if recordings.length === 0}
    <!-- Onboarding: пользователь зашёл первый раз -->
    <section class="onboarding">
      <div class="welcome-card">
        <h2>{EMPTY_STATE.title}</h2>
        <p class="welcome-sub">
          Запишите встречу через QuickRecorder — она автоматически появится здесь.
        </p>

        <ol class="steps">
          {#each EMPTY_STATE.steps as step, i}
            <li>
              <div class="step-icon">{step.icon}</div>
              <div class="step-content">
                <div class="step-title">
                  <span class="step-num">{i + 1}.</span>
                  {step.title}
                </div>
                <div class="step-desc">{step.description}</div>
              </div>
            </li>
          {/each}
        </ol>

        <div class="privacy-badge">
          🔒 {EMPTY_STATE.privacyNote}
        </div>

        <div class="empty-actions">
          <button class="primary" on:click={openQuickRecorder}>
            🎬 Открыть QuickRecorder
          </button>
          <button class="secondary" on:click={reload}>
            🔍 Я уже записал — найди файл
          </button>
        </div>
      </div>

      {#if config}
        <details class="config-details">
          <summary>Текущие настройки</summary>
          <ul>
            <li>Папка с записями: <code>{config.recordings_dir}</code></li>
            <li>
              Модель распознавания: <code>{config.whisper_model.split("/").pop()}</code>
            </li>
            <li>
              AI для заметок: <code
                >{config.summarizer_backend} / {config.summarizer_model}</code
              >
            </li>
          </ul>
          <p class="config-help">
            Настройки правятся в <code>~/.config/saqta/config.sh</code>
          </p>
        </details>
      {/if}
    </section>
  {:else}
    <!-- Есть записи: показываем список с большой кнопкой сверху -->
    <div class="primary-action">
      <button class="big-record" on:click={openQuickRecorder}>
        <span class="big-icon">🎬</span>
        <span class="big-label">
          <strong>Записать новую встречу</strong>
          <small>Откроет QuickRecorder · хоткей ⌘⇧R</small>
        </span>
      </button>
    </div>

    <section class="list-section">
      <h2 class="list-header">Мои встречи <span class="count">{recordings.length}</span></h2>
      <div class="list">
        {#each recordings as rec (rec.path)}
          <RecordingCard {rec} onUpdate={reload} />
        {/each}
      </div>
    </section>
  {/if}
</main>
{/if}

<style>
  :global(:root) {
    --bg: #fafaf7;
    --bg-card: #ffffff;
    --bg-secondary: #f3f4f6;
    --bg-secondary-hover: #e5e7eb;
    --border: #e5e7eb;
    --text: #1f2937;
    --text-muted: #6b7280;
    --accent: #1f3a5f;          /* Samruk navy */
    --accent-hover: #142847;
    --accent-soft: #e5edf6;
    --gold: #a98b5c;
  }

  @media (prefers-color-scheme: dark) {
    :global(:root) {
      --bg: #0f0f12;
      --bg-card: #1a1a1f;
      --bg-secondary: #27272a;
      --bg-secondary-hover: #3f3f46;
      --border: #2a2a30;
      --text: #f4f4f5;
      --text-muted: #a1a1aa;
      --accent: #c9a961;        /* Samruk gold (brighter for dark) */
      --accent-hover: #d4b87a;
      --accent-soft: #2a2419;
      --gold: #c9a961;
    }
  }

  :global(body) {
    font-family:
      -apple-system,
      BlinkMacSystemFont,
      "SF Pro Text",
      "SF Pro Display",
      sans-serif;
    background: var(--bg);
    color: var(--text);
    margin: 0;
    padding: 0;
    -webkit-font-smoothing: antialiased;
  }

  main {
    max-width: 760px;
    margin: 0 auto;
    padding: 28px 24px 60px;
  }

  /* === Header ============================================================= */

  header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 32px;
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 14px;
  }
  .logo {
    width: 48px;
    height: 48px;
    object-fit: contain;
  }
  h1 {
    font-size: 24px;
    margin: 0;
    font-weight: 700;
    letter-spacing: -0.02em;
  }
  .subtitle {
    margin: 2px 0 0;
    font-size: 13px;
    color: var(--text-muted);
  }
  .reload {
    background: var(--bg-secondary);
    border: 1px solid var(--border);
    color: var(--text);
    width: 36px;
    height: 36px;
    border-radius: 10px;
    font-size: 16px;
    cursor: pointer;
    font-family: inherit;
    transition: all 0.15s;
  }
  .reload:hover:not(:disabled) {
    background: var(--bg-secondary-hover);
  }
  .reload:disabled {
    opacity: 0.5;
    cursor: wait;
  }

  /* === Big primary record button ========================================= */

  .primary-action {
    margin-bottom: 28px;
  }
  .big-record {
    width: 100%;
    background: linear-gradient(135deg, var(--accent), var(--accent-hover));
    color: white;
    border: none;
    padding: 20px 24px;
    border-radius: 16px;
    font-family: inherit;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 16px;
    text-align: left;
    transition: all 0.18s;
    box-shadow: 0 4px 12px rgba(31, 58, 95, 0.18);
  }
  .big-record:hover {
    transform: translateY(-2px);
    box-shadow: 0 8px 20px rgba(31, 58, 95, 0.25);
  }
  .big-icon {
    font-size: 32px;
    line-height: 1;
  }
  .big-label {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .big-label strong {
    font-size: 16px;
    font-weight: 600;
  }
  .big-label small {
    font-size: 12px;
    opacity: 0.8;
  }

  /* === Onboarding ======================================================== */

  .onboarding {
    margin-top: 8px;
  }
  .welcome-card {
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 20px;
    padding: 36px 32px;
  }
  .welcome-card h2 {
    font-size: 22px;
    margin: 0 0 8px;
    font-weight: 700;
  }
  .welcome-sub {
    margin: 0 0 28px;
    color: var(--text-muted);
    font-size: 15px;
  }
  .steps {
    list-style: none;
    padding: 0;
    margin: 0 0 24px;
  }
  .steps li {
    display: flex;
    gap: 16px;
    padding: 14px 0;
    border-bottom: 1px solid var(--border);
  }
  .steps li:last-child {
    border-bottom: none;
  }
  .step-icon {
    width: 44px;
    height: 44px;
    background: var(--accent-soft);
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 22px;
    flex-shrink: 0;
  }
  .step-content {
    flex: 1;
  }
  .step-title {
    font-weight: 600;
    margin-bottom: 4px;
    font-size: 15px;
  }
  .step-num {
    color: var(--text-muted);
    font-weight: 500;
    margin-right: 4px;
  }
  .step-desc {
    color: var(--text-muted);
    font-size: 13px;
    line-height: 1.5;
  }
  .privacy-badge {
    background: var(--accent-soft);
    color: var(--accent);
    padding: 12px 16px;
    border-radius: 10px;
    font-size: 13px;
    margin-bottom: 24px;
    text-align: center;
    font-weight: 500;
  }
  @media (prefers-color-scheme: dark) {
    .privacy-badge {
      color: var(--gold);
    }
  }
  .empty-actions {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
  }
  .empty-actions button {
    flex: 1;
    min-width: 200px;
    border: none;
    padding: 12px 18px;
    border-radius: 10px;
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    font-family: inherit;
    transition: all 0.15s;
  }
  .empty-actions button.primary {
    background: var(--accent);
    color: white;
  }
  .empty-actions button.primary:hover {
    background: var(--accent-hover);
  }
  .empty-actions button.secondary {
    background: var(--bg-secondary);
    color: var(--text);
  }
  .empty-actions button.secondary:hover {
    background: var(--bg-secondary-hover);
  }

  /* === Config disclosure ================================================= */

  .config-details {
    margin-top: 16px;
    padding: 12px 16px;
    background: var(--bg-card);
    border: 1px solid var(--border);
    border-radius: 12px;
    font-size: 13px;
  }
  .config-details summary {
    cursor: pointer;
    color: var(--text-muted);
    user-select: none;
  }
  .config-details ul {
    margin: 12px 0 0;
    padding-left: 18px;
  }
  .config-details li {
    margin-bottom: 4px;
    color: var(--text-muted);
  }
  .config-details code {
    background: var(--bg-secondary);
    padding: 1px 6px;
    border-radius: 4px;
    font-size: 12px;
    color: var(--text);
  }
  .config-help {
    margin: 10px 0 0;
    color: var(--text-muted);
    font-size: 12px;
  }

  /* === List ============================================================== */

  .list-section {
    margin-top: 8px;
  }
  .list-header {
    font-size: 14px;
    font-weight: 600;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
    margin: 0 0 14px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .count {
    background: var(--bg-secondary);
    color: var(--text-muted);
    padding: 2px 8px;
    border-radius: 999px;
    font-size: 12px;
    text-transform: none;
    letter-spacing: 0;
  }

  .list {
    display: flex;
    flex-direction: column;
  }

  /* === Loader / Error =================================================== */

  .loader,
  .error-box {
    text-align: center;
    padding: 64px 24px;
    color: var(--text-muted);
  }
  .error-box h3 {
    color: var(--text);
    margin: 0 0 12px;
  }
  .error-box pre {
    background: var(--bg-card);
    padding: 12px;
    border-radius: 8px;
    text-align: left;
    overflow: auto;
    max-width: 100%;
    margin: 0 0 16px;
    font-size: 12px;
  }
  .error-box button {
    background: var(--accent);
    color: white;
    border: none;
    padding: 10px 20px;
    border-radius: 10px;
    cursor: pointer;
    font-family: inherit;
    font-size: 14px;
  }

  .spinner-big {
    width: 36px;
    height: 36px;
    border: 3px solid var(--border);
    border-top-color: var(--accent);
    border-radius: 50%;
    animation: spin 0.8s linear infinite;
    margin: 0 auto 16px;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }
</style>
