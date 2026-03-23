<template>
  <div>
    <div class="row list-header">
      <div class="col-lg-12">
        <div class="page-header">
          <h1>Dashboard</h1>
        </div>
      </div>
    </div>

    <div class="row lit-view">
      <div class="col-lg-12">
        <div class="panel panel-default">
          <div v-if="timelineError" class="alert alert-danger timeline-error">
            {{ timelineError }}
          </div>
          <div ref="timelineContainer" class="dashboard-timeline" />
        </div>
      </div>
    </div>

    <div class="row list-view">
      <div class="col-lg-6">
        <div class="panel panel-default">
          <div class="panel-heading">Servers</div>
          <div class="panel-body">
            <div v-if="serversStore.error" class="alert alert-danger">
              {{ serversStore.error }}
            </div>
            <div v-else-if="serversStore.loading" class="text-muted">Loading servers...</div>
            <div v-else-if="servers.length === 0" class="text-muted">No servers available.</div>
            <div v-else class="table-responsive">
              <table class="table table-striped table-hover">
                <thead>
                  <tr>
                    <th>Server Name</th>
                    <th>Version</th>
                    <th>Memory</th>
                    <th>Disk</th>
                    <th>Status</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(server, index) in servers" :key="server.sname || `server-${index}`">
                    <td>{{ server.sname || '-' }}</td>
                    <td>{{ getServerVersion(server) }}</td>
                    <td>{{ formatMemory(server.memory) }}</td>
                    <td>{{ formatDisk(server.disk) }}</td>
                    <td>
                      <span class="server-status" :class="serverStatusClass(server)">
                        <span class="glyphicon" :class="serverStatusIcon(server)" aria-hidden="true" />
                        <span>{{ serverStatusLabel(server) }}</span>
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
      <div class="col-lg-6">
        <div class="panel panel-default">
          <div class="panel-heading">Recent Events</div>
          <div class="panel-body">
            <div class="placeholder-box">Events list placeholder</div>
          </div>
        </div>
      </div>
    </div>

    <div class="row list-view">
      <div class="col-lg-6">
        <div class="panel panel-default">
          <div class="panel-heading">Recent Events</div>
          <div class="panel-body">
            <div class="placeholder-box">Events list placeholder</div>
          </div>
        </div>
      </div>
      <div class="col-lg-6">
        <div class="panel panel-default">
          <div class="panel-heading">Recent Frames</div>
          <div class="panel-body">
            <div class="placeholder-box">Frames list placeholder</div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { ensureVisScript } from '../services/vis-loader';
import { useServersStore } from '../stores/servers';

const timelineContainer = ref(null);
const timelineError = ref('');
const serversStore = useServersStore();

const toFiniteNumber = (value) => {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
};

const formatBytes = (bytes) => {
  const value = toFiniteNumber(bytes);
  if (value === null || value < 0) {
    return '-';
  }
  if (value === 0) {
    return '0 Bytes';
  }

  const units = ['Bytes', 'KB', 'MB', 'GB', 'TB', 'PB'];
  const exponent = Math.min(units.length - 1, Math.floor(Math.log(value) / Math.log(1024)));
  const scaled = value / 1024 ** exponent;
  const rounded = scaled >= 10 ? Math.round(scaled) : Math.round(scaled * 10) / 10;
  return `${rounded} ${units[exponent]}`;
};

const getServerVersion = (server) =>
  server?.modules?.bumblebee || server?.modules?.['bumblebee'] || '-';

const formatMemory = (memory) => {
  if (!memory || typeof memory !== 'object') {
    return '-';
  }

  const freeMemory = toFiniteNumber(memory.free_memory) || 0;
  const bufferedMemory = toFiniteNumber(memory.buffered_memory) || 0;
  const cachedMemory = toFiniteNumber(memory.cached_memory) || 0;
  const totalMemory = toFiniteNumber(memory.total_memory);

  const free = freeMemory + bufferedMemory + cachedMemory;
  if (totalMemory && totalMemory > 0) {
    const freePercent = Math.max(0, Math.min(100, (100 * free) / totalMemory));
    return `${formatBytes(free)} (${Math.round(freePercent)}%)`;
  }

  return free > 0 ? formatBytes(free) : '-';
};

const formatDisk = (disks) => {
  if (!Array.isArray(disks) || disks.length === 0) {
    return '-';
  }

  const rootDisk = disks.find((disk) => disk?.id === '/') || disks[0];
  const sizeKb = toFiniteNumber(rootDisk?.size_kb);
  const percentUsed = toFiniteNumber(rootDisk?.percent_used);
  if (sizeKb === null || percentUsed === null) {
    return '-';
  }

  const freePercent = Math.max(0, Math.min(100, 100 - percentUsed));
  const freeBytes = sizeKb * 1024 * (freePercent / 100);
  return `${formatBytes(freeBytes)} (${Math.round(freePercent)}%)`;
};

const getHealthDecay = (server) => toFiniteNumber(server?.health_decay);

const serverStatus = (server) => {
  const decay = getHealthDecay(server);
  const alerts = Array.isArray(server?.health_alerts) ? server.health_alerts : [];

  if (decay === null && alerts.length === 0) {
    return 'unknown';
  }
  if (decay !== null && decay > 50) {
    return 'critical';
  }
  if ((decay !== null && decay > 0) || alerts.length > 0) {
    return 'warning';
  }
  return 'online';
};

const serverStatusLabel = (server) => {
  const status = serverStatus(server);
  if (status === 'critical') {
    return 'Critical';
  }
  if (status === 'warning') {
    return 'Warning';
  }
  if (status === 'online') {
    return 'Online';
  }
  return 'Unknown';
};

const serverStatusIcon = (server) => {
  const status = serverStatus(server);
  if (status === 'critical') {
    return 'glyphicon-remove-sign';
  }
  if (status === 'warning') {
    return 'glyphicon-warning-sign';
  }
  if (status === 'online') {
    return 'glyphicon-ok-sign';
  }
  return 'glyphicon-question-sign';
};

const serverStatusClass = (server) => {
  const status = serverStatus(server);
  if (status === 'critical') {
    return 'text-danger';
  }
  if (status === 'warning') {
    return 'text-warning';
  }
  if (status === 'online') {
    return 'text-success';
  }
  return 'text-muted';
};

const servers = computed(() =>
  [...serversStore.servers].sort((left, right) =>
    String(left?.sname || '').localeCompare(String(right?.sname || ''), undefined, {
      sensitivity: 'base'
    })
  )
);

let timeline = null;
let items = null;
let pollTimer = null;

const POLL_INTERVAL_MS = 5000;
const TIMELINE_ZOOM_MAX_MS = 2592000000;
const TIMELINE_ZOOM_MIN_MS = 1000;

const syncTimelineItems = (nextItems) => {
  const nextIds = new Set(nextItems.map((entry) => entry.id));
  const existingIds = items.getIds();
  const removedIds = existingIds.filter((id) => !nextIds.has(id));

  if (removedIds.length > 0) {
    items.remove(removedIds);
  }
  items.update(nextItems);
};

const fetchTimelineItems = async () => {
  if (!timeline) {
    return;
  }

  const range = timeline.getWindow();
  const params = new URLSearchParams({
    start: range.start.toISOString(),
    end: range.end.toISOString()
  });

  const response = await fetch(`/admin/timeline?${params.toString()}`);
  if (!response.ok) {
    throw new Error(`Timeline request failed (${response.status})`);
  }

  const payload = await response.json();
  const nextItems = Array.isArray(payload?.items) ? payload.items : [];
  syncTimelineItems(nextItems);
};

const refreshTimeline = async () => {
  try {
    await fetchTimelineItems();
    timelineError.value = '';
  } catch (error) {
    timelineError.value = error instanceof Error ? error.message : 'Failed to load timeline data';
  }
};

const startTimelinePolling = () => {
  pollTimer = window.setInterval(() => {
    void refreshTimeline();
  }, POLL_INTERVAL_MS);
};

const stopTimelinePolling = () => {
  if (pollTimer !== null) {
    window.clearInterval(pollTimer);
    pollTimer = null;
  }
};

const mountTimeline = async () => {
  const vis = await ensureVisScript();

  if (!timelineContainer.value) {
    return;
  }

  items = new vis.DataSet([]);
  timeline = new vis.Timeline(timelineContainer.value, items, {
    start: new Date(Date.now() - 600000),
    end: new Date(),
    rollingMode: { follow: true, offset: 0.95 },
    selectable: false,
    height: '300px',
    zoomMax: TIMELINE_ZOOM_MAX_MS,
    zoomMin: TIMELINE_ZOOM_MIN_MS
  });

  timeline.on('rangechanged', (properties) => {
    if (properties?.byUser) {
      void refreshTimeline();
    }
  });

  await refreshTimeline();
  startTimelinePolling();
};

onMounted(async () => {
  try {
    await mountTimeline();
  } catch (error) {
    timelineError.value = error instanceof Error ? error.message : 'Failed to initialize timeline';
  }

  try {
    await serversStore.fetchServers();
  } catch (_error) {
    // Error is reflected via serversStore.error.
  }
});

onBeforeUnmount(() => {
  stopTimelinePolling();
  if (timeline) {
    timeline.destroy();
    timeline = null;
  }
  items = null;
});
</script>

<style scoped>
.server-status {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}
</style>
