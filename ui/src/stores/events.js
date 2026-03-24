import { defineStore } from 'pinia';
import { listRecords } from '../services/admin-api';

const EVENTS_ENTITY = 'events';
const FETCH_PAGE_SIZE = 30;

export const useEventsStore = defineStore('events', {
  state: () => ({
    events: [],
    loading: false,
    error: ''
  }),
  actions: {
    async fetchEvents() {
      this.loading = true;
      this.error = '';

      try {
        const { data } = await listRecords(EVENTS_ENTITY, {
          _page: 1,
          _perPage: FETCH_PAGE_SIZE,
          _sortField: 'last_rx',
          _sortDir: 'DESC'
        });
        this.events = Array.isArray(data) ? data : [];
        return this.events;
      } catch (err) {
        this.error = err instanceof Error ? err.message : String(err);
        throw err;
      } finally {
        this.loading = false;
      }
    }
  }
});
