import { defineStore } from 'pinia';
import { listRecords } from '../services/admin-api';

const SERVERS_ENTITY = 'servers';
const FETCH_PAGE_SIZE = 30;

export const useServersStore = defineStore('servers', {
  state: () => ({
    servers: [],
    loading: false,
    error: ''
  }),
  actions: {
    async fetchServers() {
      this.loading = true;
      this.error = '';

      try {
        let page = 1;
        let total = Number.POSITIVE_INFINITY;
        const collected = [];

        while (collected.length < total) {
          const { data, headers } = await listRecords(SERVERS_ENTITY, {
            _page: page,
            _perPage: FETCH_PAGE_SIZE
          });

          const chunk = Array.isArray(data) ? data : [];
          collected.push(...chunk);

          const totalFromHeader = Number(headers.get('x-total-count') || collected.length);
          total = Number.isFinite(totalFromHeader) ? totalFromHeader : collected.length;

          if (chunk.length === 0 || chunk.length < FETCH_PAGE_SIZE) {
            break;
          }

          page += 1;
        }

        this.servers = collected;
        return this.servers;
      } catch (err) {
        this.error = err instanceof Error ? err.message : String(err);
        throw err;
      } finally {
        this.loading = false;
      }
    }
  }
});
