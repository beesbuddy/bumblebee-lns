<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { RouterLink } from 'vue-router';
import {
  getEntityLabel,
  getEntityLabelKey,
  humanizeFieldName,
  resolveEntityDefinition,
  resolveFieldLabelKey
} from '../../models/entity-definitions';
import { deleteRecord, listRecords } from '../../services/admin-api';
import { t } from '../../i18n';

const props = defineProps({
  entity: {
    type: String,
    required: true
  },
  definition: {
    type: Object,
    default: null
  },
  initialPage: {
    type: Number,
    default: 1
  }
});

const emit = defineEmits(['loaded', 'load-error', 'deleted', 'delete-error']);

const rows = ref([]);
const loading = ref(false);
const error = ref('');
const currentPage = ref(props.initialPage);
const totalCount = ref(0);
const sortField = ref('');
const sortDir = ref('ASC');

const mergedDefinition = computed(() => ({
  ...resolveEntityDefinition(props.entity),
  ...(props.definition || {})
}));
const idField = computed(() => mergedDefinition.value.idField);
const columns = computed(() => {
  const explicit = mergedDefinition.value.listFields || [];
  if (explicit.length > 0) {
    return explicit;
  }
  const first = rows.value[0] || {};
  return Object.keys(first).slice(0, 6);
});

const totalPages = computed(() =>
  Math.max(1, Math.ceil(totalCount.value / Math.max(1, mergedDefinition.value.perPage)))
);
const entityLabel = computed(() =>
  t(getEntityLabelKey(props.entity), getEntityLabel(props.entity))
);
const title = computed(() => `${entityLabel.value} ${t('ui.list', 'List')}`);
const canCreate = computed(() => mergedDefinition.value.canCreate);
const canEdit = computed(() => mergedDefinition.value.canEdit);
const canDelete = computed(() => mergedDefinition.value.canDelete);
const createTo = computed(() => `/${props.entity}/create`);

const readNestedValue = (record, path) => {
  if (!record || !path) {
    return null;
  }
  return path.split('.').reduce((acc, key) => (acc == null ? null : acc[key]), record);
};

const formatValue = (value) => {
  if (value === null || value === undefined) {
    return '';
  }
  if (typeof value === 'boolean') {
    return value ? 'yes' : 'no';
  }
  if (typeof value === 'object') {
    const text = JSON.stringify(value);
    return text.length > 80 ? `${text.slice(0, 77)}...` : text;
  }
  return String(value);
};

const fieldLabel = (field) => {
  const key = resolveFieldLabelKey(props.entity, field, 'list');
  return key ? t(key, humanizeFieldName(field)) : humanizeFieldName(field);
};

const editPathFor = (row) => {
  const id = row?.id ?? row?.[idField.value];
  return `/${props.entity}/edit/${encodeURIComponent(String(id || ''))}`;
};

const loadList = async () => {
  loading.value = true;
  error.value = '';
  try {
    const params = {
      _page: currentPage.value,
      _perPage: mergedDefinition.value.perPage
    };
    if (sortField.value) {
      params._sortField = sortField.value;
      params._sortDir = sortDir.value;
    }
    const { data, headers } = await listRecords(props.entity, params);
    rows.value = Array.isArray(data) ? data : [];
    totalCount.value = Number(headers.get('x-total-count') || rows.value.length);
    emit('loaded', rows.value);
  } catch (err) {
    rows.value = [];
    totalCount.value = 0;
    error.value = err instanceof Error ? err.message : String(err);
    emit('load-error', error.value);
  } finally {
    loading.value = false;
  }
};

const resetAndReload = () => {
  currentPage.value = 1;
  sortField.value = '';
  sortDir.value = 'ASC';
  loadList();
};

const changeSort = (column) => {
  if (sortField.value === column) {
    sortDir.value = sortDir.value === 'ASC' ? 'DESC' : 'ASC';
  } else {
    sortField.value = column;
    sortDir.value = 'ASC';
  }
  currentPage.value = 1;
  loadList();
};

const goToPage = (page) => {
  currentPage.value = Math.min(Math.max(1, page), totalPages.value);
  loadList();
};

const deleteRow = async (row) => {
  const id = row?.id ?? row?.[idField.value];
  if (!id) {
    return;
  }
  const ok = window.confirm(`Delete ${props.entity} "${id}"?`);
  if (!ok) {
    return;
  }
  try {
    await deleteRecord(props.entity, String(id));
    emit('deleted', row);
    await loadList();
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
    emit('delete-error', error.value);
  }
};

watch(
  () => props.entity,
  () => {
    resetAndReload();
  }
);

onMounted(loadList);
</script>

<template>
  <div>
    <div class="row list-header">
      <div class="col-lg-12">
        <div class="page-header">
          <div class="pull-right">
            <slot
              name="header-actions"
              :entity="props.entity"
              :definition="mergedDefinition"
              :create-to="createTo"
              :can-create="canCreate"
              :refresh="loadList"
            >
              <RouterLink v-if="canCreate" class="btn btn-default" :to="createTo">
                <span class="glyphicon glyphicon-plus" aria-hidden="true" />
                <span class="hidden-xs">{{ t('ui.create', 'Create') }}</span>
              </RouterLink>
            </slot>
          </div>
          <h1>{{ title }}</h1>
        </div>
      </div>
    </div>

    <slot
      name="before-table"
      :rows="rows"
      :loading="loading"
      :refresh="loadList"
      :error="error"
    />

    <div class="row list-view">
      <div class="col-lg-12">
        <div v-if="error" class="alert alert-danger">{{ error }}</div>

        <table class="grid table table-condensed table-hover table-striped">
          <thead>
            <tr>
              <th
                v-for="column in columns"
                :key="column"
                class="sortable-header"
                @click="changeSort(column)"
              >
                {{ fieldLabel(column) }}
                <span v-if="sortField === column">{{ sortDir === 'ASC' ? '▲' : '▼' }}</span>
              </th>
              <th v-if="canDelete || canEdit">{{ t('ui.actions', 'Actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading">
              <td :colspan="columns.length + 1">{{ t('ui.loading', 'Loading...') }}</td>
            </tr>
            <tr v-else-if="rows.length === 0">
              <td :colspan="columns.length + 1"><strong>{{ t('ui.no_records', 'No record found') }}</strong></td>
            </tr>
            <tr v-for="row in rows" :key="row.id ?? row[idField]">
              <td v-for="column in columns" :key="column">
                <slot
                  name="cell"
                  :row="row"
                  :column="column"
                  :value="readNestedValue(row, column)"
                  :formatted-value="formatValue(readNestedValue(row, column))"
                  :can-edit="canEdit"
                  :id-field="idField"
                  :edit-to="editPathFor(row)"
                >
                  <RouterLink v-if="canEdit && column === idField" :to="editPathFor(row)">
                    {{ formatValue(readNestedValue(row, column)) }}
                  </RouterLink>
                  <span v-else>{{ formatValue(readNestedValue(row, column)) }}</span>
                </slot>
              </td>
              <td v-if="canDelete || canEdit" class="row-actions">
                <slot
                  name="row-actions"
                  :row="row"
                  :can-edit="canEdit"
                  :can-delete="canDelete"
                  :edit-to="editPathFor(row)"
                  :delete-row="() => deleteRow(row)"
                >
                  <RouterLink
                    v-if="canEdit"
                    class="btn btn-xs btn-default"
                    :to="editPathFor(row)"
                  >
                    {{ t('ui.edit', 'Edit') }}
                  </RouterLink>
                  <button
                    v-if="canDelete"
                    type="button"
                    class="btn btn-xs btn-danger"
                    @click="deleteRow(row)"
                  >
                    {{ t('ui.delete', 'Delete') }}
                  </button>
                </slot>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <slot
      name="after-table"
      :rows="rows"
      :loading="loading"
      :refresh="loadList"
      :error="error"
    />

    <div class="row">
      <div class="col-lg-12">
        <nav class="pagination-bar">
          <div class="total">
            <strong>{{ t('ui.total', 'Total') }}: {{ totalCount }}</strong>
          </div>
          <ul class="pagination pagination-sm">
            <li :class="{ disabled: currentPage <= 1 }">
              <a href="#" @click.prevent="goToPage(currentPage - 1)">{{ t('ui.prev', 'Prev') }}</a>
            </li>
            <li class="active"><a>{{ currentPage }}</a></li>
            <li :class="{ disabled: currentPage >= totalPages }">
              <a href="#" @click.prevent="goToPage(currentPage + 1)">{{ t('ui.next', 'Next') }}</a>
            </li>
          </ul>
        </nav>
      </div>
    </div>
  </div>
</template>
