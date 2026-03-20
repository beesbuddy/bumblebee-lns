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
          <div ref="timelineContainer" class="dashboard-timeline" />
          <div v-if="timelineError" class="alert alert-danger timeline-error">
            {{ timelineError }}
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
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { ensureVisScript } from '../services/vis-loader';

const timelineContainer = ref(null);
const timelineError = ref('');

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
