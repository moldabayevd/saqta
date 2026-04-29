<script lang="ts">
  import { onMount } from "svelte";
  import {
    listRecordings,
    getConfig,
    type Recording,
    type Config,
  } from "./lib/api";
  import RecordingCard from "./lib/Recording.svelte";

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

  onMount(reload);
</script>

<main>
  <header>
    <div class="title-row">
      <h1>🎙️ Saqta</h1>
      <button class="reload" on:click={reload} disabled={loading}>
        {loading ? "↻" : "⟳"} Обновить
      </button>
    </div>
    {#if config}
      <div class="config-row">
        <span>📁 {config.recordings_dir}</span>
        <span>🤖 {config.summarizer_backend}/{config.summarizer_model}</span>
        <span>🇰🇿 {config.kk_backend}</span>
      </div>
    {/if}
  </header>

  {#if loading && recordings.length === 0}
    <div class="loader">
      <div class="spinner-big" />
      <p>Сканирую записи...</p>
    </div>
  {:else if error}
    <div class="error">
      <h3>⚠️ Ошибка</h3>
      <pre>{error}</pre>
    </div>
  {:else if recordings.length === 0}
    <div class="empty">
      <h2>Записей нет</h2>
      <p>Запиши встречу через QuickRecorder (⌘⇧R)</p>
      <p class="muted">Файлы появятся в {config?.recordings_dir}</p>
    </div>
  {:else}
    <section class="list">
      {#each recordings as rec (rec.path)}
        <RecordingCard {rec} onUpdate={reload} />
      {/each}
    </section>
  {/if}
</main>

<style>
  :global(:root) {
    --bg: #fafafa;
    --bg-card: #ffffff;
    --bg-secondary: #f3f4f6;
    --bg-secondary-hover: #e5e7eb;
    --border: #e5e7eb;
    --text: #1f2937;
    --text-muted: #6b7280;
    --accent: #ec4899;
    --accent-hover: #db2777;
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
      --accent: #f472b6;
      --accent-hover: #ec4899;
    }
  }

  :global(body) {
    font-family:
      -apple-system,
      BlinkMacSystemFont,
      "SF Pro Text",
      sans-serif;
    background: var(--bg);
    color: var(--text);
    margin: 0;
    padding: 0;
    -webkit-font-smoothing: antialiased;
  }

  main {
    max-width: 800px;
    margin: 0 auto;
    padding: 24px 20px 40px;
  }

  header {
    margin-bottom: 24px;
    border-bottom: 1px solid var(--border);
    padding-bottom: 16px;
  }
  .title-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  h1 {
    font-size: 22px;
    margin: 0;
    font-weight: 700;
  }
  .reload {
    background: var(--bg-secondary);
    border: 1px solid var(--border);
    color: var(--text);
    padding: 6px 14px;
    border-radius: 8px;
    font-size: 13px;
    cursor: pointer;
    font-family: inherit;
  }
  .reload:hover:not(:disabled) {
    background: var(--bg-secondary-hover);
  }
  .reload:disabled {
    opacity: 0.5;
    cursor: wait;
  }

  .config-row {
    display: flex;
    gap: 16px;
    margin-top: 10px;
    font-size: 12px;
    color: var(--text-muted);
    flex-wrap: wrap;
  }

  .list {
    display: flex;
    flex-direction: column;
  }

  .loader,
  .empty,
  .error {
    text-align: center;
    padding: 64px 24px;
    color: var(--text-muted);
  }
  .empty h2 {
    font-size: 18px;
    color: var(--text);
    margin: 0 0 8px;
  }
  .empty .muted {
    font-size: 12px;
    margin-top: 16px;
  }
  .error pre {
    background: var(--bg-card);
    padding: 12px;
    border-radius: 8px;
    text-align: left;
    overflow: auto;
    max-width: 100%;
  }

  .spinner-big {
    width: 32px;
    height: 32px;
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
