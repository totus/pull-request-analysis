document.addEventListener("DOMContentLoaded", () => {
  const progressCard = document.querySelector("[data-sync-run-poll-url]");
  if (!progressCard) return;

  const pollUrl = progressCard.dataset.syncRunPollUrl;
  const statusNode = progressCard.querySelector("[data-role='status']");
  const countsNode = progressCard.querySelector("[data-role='counts']");
  const currentNode = progressCard.querySelector("[data-role='current']");
  const errorNode = progressCard.querySelector("[data-role='error']");
  const barNode = progressCard.querySelector("[data-role='progress-bar']");

  const update = (payload) => {
    statusNode.textContent = payload.status;
    countsNode.textContent = `${payload.processed_count} / ${payload.total_count}`;
    currentNode.textContent = payload.current_pull_request_number ? `Processing PR #${payload.current_pull_request_number}` : "Waiting for next item";
    barNode.style.width = `${payload.progress_percentage}%`;
    errorNode.textContent = payload.error_message || "";

    if (!payload.active) {
      if (payload.status === "completed") {
        currentNode.textContent = "Sync completed. Reloading results...";
        window.setTimeout(() => window.location.reload(), 1200);
      }
      return false;
    }

    return true;
  };

  const tick = async () => {
    try {
      const response = await fetch(pollUrl, { headers: { Accept: "application/json" } });
      if (!response.ok) return;
      const payload = await response.json();
      if (update(payload)) window.setTimeout(tick, 2000);
    } catch (_error) {
      window.setTimeout(tick, 4000);
    }
  };

  tick();
});
