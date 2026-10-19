const byId = (id) => document.getElementById(id);
const setText = (id, value) => { byId(id).textContent = value; };
const formatBytes = (bytes) => {
  if (bytes === null || !Number.isFinite(bytes)) return "Unavailable";
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit += 1; }
  return `${value.toFixed(1)} ${units[unit]}`;
};
const formatDuration = (seconds) => {
  if (!Number.isFinite(seconds)) return "Unavailable";
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return `${days ? `${days}d ` : ""}${hours}h ${minutes}m`;
};
const setMetric = (id, metric, formatter, barId) => {
  const value = metric?.status === "available" ? metric.value : null;
  setText(id, formatter(value));
  if (barId) {
    const bar = byId(barId);
    bar.style.width = value === null ? "0%" : `${Math.max(0, Math.min(100, value))}%`;
    bar.classList.toggle("unavailable", value === null);
  }
};
const setIntegration = (name, integration) => {
  const state = integration?.status || "unavailable";
  setText(`${name}-state`, state.replaceAll("_", " "));
  setText(`${name}-detail`, integration?.detail || "Status unavailable");
  byId(`${name}-state`).className = `integration-state ${state.replaceAll("_", "-")}`;
};

async function refreshDashboard() {
  try {
    const [healthResponse, metricsResponse, infoResponse] = await Promise.all([
      fetch("/health", { headers: { Accept: "application/json" } }),
      fetch("/api/metrics", { headers: { Accept: "application/json" } }),
      fetch("/api/info", { headers: { Accept: "application/json" } }),
    ]);
    if (!healthResponse.ok || !metricsResponse.ok || !infoResponse.ok) throw new Error("API response unavailable");
    const [health, data, info] = await Promise.all([healthResponse.json(), metricsResponse.json(), infoResponse.json()]);
    const healthy = health.status === "healthy";
    setText("health-status", healthy ? "HEALTHY" : "DEGRADED");
    setText("health-detail", healthy ? "Application process is responding normally" : "Application health check failed");
    byId("health-status").className = `status-pill ${healthy ? "healthy" : "degraded"}`;
    setMetric("cpu-value", data.metrics.cpu_percent, (v) => v === null ? "Unavailable" : `${v.toFixed(1)}%`, "cpu-bar");
    setMetric("memory-value", data.metrics.memory_rss_bytes, formatBytes);
    setMetric("disk-value", data.metrics.disk_percent, (v) => v === null ? "Unavailable" : `${v.toFixed(1)}%`, "disk-bar");
    setMetric("uptime-value", data.metrics.uptime_seconds, formatDuration);
    setText("last-updated", new Date(data.generated_at).toLocaleTimeString());
    setText("refresh-status", "Live");
    setText("runtime-version", `Python ${info.runtime}`);
    Object.entries(data.integrations).forEach(([name, status]) => setIntegration(name, status));
    const cloudwatchMetric = data.metrics.cloudwatch_ec2_cpu_percent;
    if (cloudwatchMetric?.status === "available") {
      setText("cloudwatch-detail", `EC2 instance CPU: ${cloudwatchMetric.value.toFixed(1)}%`);
    }
    if (info.deployment.release) {
      setText("release-status", info.deployment.status.replaceAll("_", " ").toUpperCase());
      setText("release-value", info.deployment.release);
    }
  } catch {
    setText("refresh-status", "Unavailable");
    setText("health-status", "UNAVAILABLE");
    setText("health-detail", "Unable to retrieve current application data");
    byId("health-status").className = "status-pill degraded";
  }
}

refreshDashboard();
window.setInterval(refreshDashboard, 15000);