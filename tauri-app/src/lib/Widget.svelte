<script lang="ts">
  import { onMount } from "svelte";
  import { invoke } from "@tauri-apps/api/core";

  let source = "встрече";
  let recording = false;
  let elapsed = 0;
  let timer: number | undefined;

  onMount(async () => {
    try {
      source = await invoke<string>("meeting_source");
    } catch {
      source = "встрече";
    }
  });

  async function startRecording() {
    try {
      await invoke("start_quick_recorder");
      recording = true;
      const startTs = Date.now();
      timer = window.setInterval(() => {
        elapsed = Math.floor((Date.now() - startTs) / 1000);
      }, 1000);
    } catch (e) {
      alert(`Не удалось запустить QuickRecorder: ${e}`);
    }
  }

  async function stopRecording() {
    // QuickRecorder останавливается своим хоткеем, мы просто закрываем виджет
    if (timer) clearInterval(timer);
    recording = false;
    elapsed = 0;
    closeWidget();
  }

  async function closeWidget() {
    try {
      // Cooldown 2 минуты чтобы детектор не дёргал снова
      await invoke("dismiss_widget");
    } catch {}
    // Закрываем окно
    const { getCurrentWindow } = await import("@tauri-apps/api/window");
    await getCurrentWindow().close();
  }

  function formatTime(s: number): string {
    const m = Math.floor(s / 60);
    const sec = s % 60;
    return `${m}:${sec.toString().padStart(2, "0")}`;
  }
</script>

<div class="widget" data-tauri-drag-region>
  {#if !recording}
    <!-- Стартовое состояние: предлагаем записать -->
    <div class="content">
      <div class="icon">🔴</div>
      <div class="text">
        <div class="title">Записать {source}?</div>
        <div class="subtitle">Saqta заметил активную встречу</div>
      </div>
    </div>
    <div class="actions">
      <button class="dismiss" on:click={closeWidget} title="Не записывать (на 2 мин не беспокоить)">
        ✕
      </button>
      <button class="record" on:click={startRecording}>
        🎬 Записать
      </button>
    </div>
  {:else}
    <!-- Идёт запись -->
    <div class="content">
      <div class="icon recording-pulse">🔴</div>
      <div class="text">
        <div class="title">Идёт запись</div>
        <div class="timer">{formatTime(elapsed)}</div>
      </div>
    </div>
    <div class="actions">
      <button class="stop" on:click={stopRecording}>
        ⏹ Остановить
      </button>
    </div>
  {/if}
</div>

<style>
  :global(body) {
    background: transparent;
    margin: 0;
    overflow: hidden;
    font-family:
      -apple-system,
      BlinkMacSystemFont,
      sans-serif;
    -webkit-font-smoothing: antialiased;
  }

  .widget {
    width: calc(100vw - 4px);
    height: calc(100vh - 4px);
    margin: 2px;
    background: rgba(255, 255, 255, 0.95);
    backdrop-filter: blur(20px) saturate(180%);
    -webkit-backdrop-filter: blur(20px) saturate(180%);
    border: 1px solid rgba(0, 0, 0, 0.08);
    border-radius: 16px;
    box-shadow: 0 12px 40px rgba(0, 0, 0, 0.18);
    padding: 14px 16px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    gap: 10px;
    box-sizing: border-box;
    user-select: none;
    -webkit-app-region: drag;
  }

  @media (prefers-color-scheme: dark) {
    .widget {
      background: rgba(28, 28, 32, 0.95);
      border-color: rgba(255, 255, 255, 0.08);
    }
  }

  .content {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .icon {
    font-size: 22px;
    width: 36px;
    height: 36px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(239, 68, 68, 0.12);
    border-radius: 10px;
    flex-shrink: 0;
  }

  .recording-pulse {
    animation: pulse 1.5s ease-in-out infinite;
  }
  @keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
  }

  .text {
    flex: 1;
    min-width: 0;
  }
  .title {
    font-weight: 600;
    font-size: 14px;
    color: #1f2937;
    margin-bottom: 2px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .subtitle {
    font-size: 12px;
    color: #6b7280;
  }
  .timer {
    font-size: 13px;
    color: #ef4444;
    font-variant-numeric: tabular-nums;
    font-weight: 500;
  }

  @media (prefers-color-scheme: dark) {
    .title { color: #f4f4f5; }
    .subtitle { color: #a1a1aa; }
  }

  .actions {
    display: flex;
    gap: 6px;
    -webkit-app-region: no-drag;
  }

  button {
    border: none;
    border-radius: 8px;
    font-size: 13px;
    font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    padding: 8px 14px;
    transition: transform 0.1s ease;
  }
  button:hover { transform: translateY(-1px); }
  button:active { transform: translateY(0); }

  button.record {
    background: #1f3a5f;
    color: white;
    flex: 1;
  }
  button.record:hover { background: #142847; }

  button.stop {
    background: #ef4444;
    color: white;
    flex: 1;
  }
  button.stop:hover { background: #dc2626; }

  button.dismiss {
    background: rgba(0, 0, 0, 0.06);
    color: #6b7280;
    width: 32px;
    padding: 0;
  }
  button.dismiss:hover {
    background: rgba(0, 0, 0, 0.1);
    color: #1f2937;
  }

  @media (prefers-color-scheme: dark) {
    button.dismiss {
      background: rgba(255, 255, 255, 0.08);
      color: #a1a1aa;
    }
    button.dismiss:hover {
      background: rgba(255, 255, 255, 0.12);
      color: #f4f4f5;
    }
  }
</style>
