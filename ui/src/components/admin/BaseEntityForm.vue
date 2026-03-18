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
              :list-to="listTo"
            >
              <RouterLink class="btn btn-default" :to="listTo">
                <span class="glyphicon glyphicon-list" aria-hidden="true" />
                <span class="hidden-xs">{{ t('ui.list', 'List') }}</span>
              </RouterLink>
            </slot>
          </div>
          <h1>{{ title }}</h1>
        </div>
      </div>
    </div>

    <div class="tab-pane">
      <div class="row">
        <div class="col-lg-12">
          <div v-if="error" class="alert alert-danger">{{ error }}</div>
          <div v-if="success" class="alert alert-success">{{ success }}</div>
          <div v-if="loading" class="alert alert-info">{{ t('ui.loading', 'Loading...') }}</div>

          <form v-if="!loading" class="form-horizontal" @submit.prevent="submit">
            <slot
              name="before-fields"
              :entity="props.entity"
              :mode="props.mode"
              :record-id="props.recordId"
              :definition="mergedDefinition"
              :sections="sections"
              :active-section-id="activeSectionId"
              :set-active-section="activateSection"
            />

            <ul v-if="hasSections" class="nav nav-tabs entity-form-tabs">
              <li
                v-for="section in sections"
                :key="section.id"
                :class="{ active: section.id === activeSectionId }"
              >
                <a href="#" @click.prevent="activateSection(section.id)">
                  {{ sectionLabel(section) }}
                </a>
              </li>
            </ul>

            <div
              v-for="field in visibleFields"
              :key="field"
              class="form-group"
            >
              <label class="col-sm-2 control-label">{{ fieldLabel(field) }}</label>
              <div class="col-sm-10">
                <slot
                  name="field"
                  :field="field"
                  :kind="fieldKinds[field]"
                  :disabled="isFieldDisabled(field)"
                  :primitive-values="primitiveValues"
                  :json-values="jsonValues"
                >
                  <template v-if="fieldKinds[field] === 'boolean'">
                    <input
                      v-model="primitiveValues[field]"
                      type="checkbox"
                      :disabled="isFieldDisabled(field)"
                    />
                  </template>

                  <template v-else-if="fieldKinds[field] === 'number'">
                    <input
                      v-model.number="primitiveValues[field]"
                      type="number"
                      class="form-control"
                      :disabled="isFieldDisabled(field)"
                    />
                  </template>

                  <template v-else-if="fieldKinds[field] === 'json'">
                    <textarea
                      v-model="jsonValues[field]"
                      rows="4"
                      class="form-control"
                      :disabled="isFieldDisabled(field)"
                    />
                    <small class="text-muted">{{ t('ui.json_hint', 'JSON object or array') }}</small>
                  </template>

                  <template v-else>
                    <input
                      v-model="primitiveValues[field]"
                      type="text"
                      class="form-control"
                      :disabled="isFieldDisabled(field)"
                    />
                  </template>
                </slot>
              </div>
            </div>

            <slot
              name="after-fields"
              :entity="props.entity"
              :mode="props.mode"
              :record-id="props.recordId"
              :definition="mergedDefinition"
              :ordered-fields="orderedFields"
              :visible-fields="visibleFields"
              :sections="sections"
              :active-section-id="activeSectionId"
              :set-active-section="activateSection"
            />

            <div v-if="allowAddField" class="form-group add-field-row">
              <label class="col-sm-2 control-label">{{ t('ui.add_field', 'Add field') }}</label>
              <div class="col-sm-4">
                <input v-model.trim="newFieldName" type="text" class="form-control" placeholder="field_name" />
              </div>
              <div class="col-sm-4">
                <input v-model="newFieldValue" type="text" class="form-control" placeholder="value or JSON" />
              </div>
              <div class="col-sm-2">
                <button type="button" class="btn btn-default" @click="addField">{{ t('ui.add', 'Add') }}</button>
              </div>
            </div>

            <div class="form-group">
              <div class="col-sm-offset-2 col-sm-10">
                <button
                  v-if="canSubmit"
                  type="submit"
                  class="btn btn-primary"
                  :disabled="saving"
                >
                  <span class="glyphicon glyphicon-ok" />
                  <span class="hidden-xs">{{ t('ui.submit', 'Submit') }}</span>
                </button>
                <slot
                  name="extra-actions"
                  :submit="submit"
                  :saving="saving"
                  :payload-builder="buildPayload"
                />
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { RouterLink, useRouter } from 'vue-router';
import {
  getEntityLabel,
  getEntityLabelKey,
  humanizeFieldName,
  resolveEntityDefinition,
  resolveFieldLabelKey,
  resolveFormSections
} from '../../models/entity-definitions';
import { createRecord, readRecord, updateRecord } from '../../services/admin-api';
import { t } from '../../i18n';

const props = defineProps({
  entity: {
    type: String,
    required: true
  },
  mode: {
    type: String,
    required: true
  },
  recordId: {
    type: String,
    default: ''
  },
  definition: {
    type: Object,
    default: null
  },
  allowAddField: {
    type: Boolean,
    default: true
  },
  redirectAfterCreate: {
    type: Boolean,
    default: true
  }
});

const emit = defineEmits(['loaded', 'load-error', 'submit-success', 'submit-error']);
const router = useRouter();

const loading = ref(false);
const saving = ref(false);
const error = ref('');
const success = ref('');

const fieldKinds = ref({});
const primitiveValues = ref({});
const jsonValues = ref({});

const newFieldName = ref('');
const newFieldValue = ref('');
const activeSectionId = ref('');

const mergedDefinition = computed(() => ({
  ...resolveEntityDefinition(props.entity),
  ...(props.definition || {})
}));

const canSubmit = computed(() => {
  if (props.mode === 'create') {
    return mergedDefinition.value.canCreate;
  }
  return mergedDefinition.value.canEdit;
});

const entityLabel = computed(() =>
  t(getEntityLabelKey(props.entity), getEntityLabel(props.entity))
);
const title = computed(() => {
  if (props.mode === 'create') {
    return `${t('ui.create', 'Create')} ${entityLabel.value}`;
  }
  return `${t('ui.edit', 'Edit')} ${entityLabel.value}: ${props.recordId}`;
});
const listTo = computed(() => `/${props.entity}/list`);

const orderedFields = computed(() => {
  const all = Object.keys(fieldKinds.value);
  const id = mergedDefinition.value.idField;
  if (all.includes(id)) {
    return [id, ...all.filter((field) => field !== id)];
  }
  return all;
});

const sections = computed(() => {
  const base = resolveFormSections(props.entity, props.mode).filter((section) => section?.id);
  if (base.length === 0) {
    return [];
  }

  const assigned = new Set(base.flatMap((section) => section.fields || []));
  const unassigned = orderedFields.value.filter((field) => !assigned.has(field));
  if (unassigned.length === 0) {
    return base;
  }

  return [
    ...base,
    {
      id: 'other',
      labelKey: 'section.other',
      label: 'Other',
      fields: unassigned,
      auto: true
    }
  ];
});

const hasSections = computed(() => sections.value.length > 0);
const activeSection = computed(
  () => sections.value.find((section) => section.id === activeSectionId.value) || sections.value[0] || null
);
const visibleFields = computed(() => {
  if (!hasSections.value || !activeSection.value) {
    return orderedFields.value;
  }
  const allowed = new Set(activeSection.value.fields || []);
  return orderedFields.value.filter((field) => allowed.has(field));
});

const resetFormState = () => {
  fieldKinds.value = {};
  primitiveValues.value = {};
  jsonValues.value = {};
};

const classifyField = (field, value) => {
  if (Array.isArray(value) || (value && typeof value === 'object')) {
    fieldKinds.value[field] = 'json';
    jsonValues.value[field] = JSON.stringify(value, null, 2);
    return;
  }
  if (typeof value === 'boolean') {
    fieldKinds.value[field] = 'boolean';
    primitiveValues.value[field] = value;
    return;
  }
  if (typeof value === 'number') {
    fieldKinds.value[field] = 'number';
    primitiveValues.value[field] = value;
    return;
  }
  fieldKinds.value[field] = 'string';
  primitiveValues.value[field] = value == null ? '' : String(value);
};

const fieldLabel = (field) => {
  const key = resolveFieldLabelKey(props.entity, field, 'form');
  return key ? t(key, humanizeFieldName(field)) : humanizeFieldName(field);
};

const sectionLabel = (section) => {
  const fallback =
    section.label ||
    String(section.id || '')
      .replaceAll('_', ' ')
      .replace(/\s+/g, ' ')
      .trim()
      .replace(/\b\w/g, (letter) => letter.toUpperCase());
  return section.labelKey ? t(section.labelKey, fallback) : fallback;
};

const activateSection = (sectionId) => {
  activeSectionId.value = sectionId;
};

const hydrateFromObject = (payload) => {
  resetFormState();
  Object.entries(payload || {}).forEach(([field, value]) => classifyField(field, value));
};

const loadRecord = async () => {
  loading.value = true;
  error.value = '';
  success.value = '';

  try {
    if (props.mode === 'create') {
      hydrateFromObject({ [mergedDefinition.value.idField]: '' });
      emit('loaded', null);
      return;
    }
    const { data } = await readRecord(props.entity, props.recordId);
    hydrateFromObject(data || {});
    emit('loaded', data);
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
    emit('load-error', error.value);
  } finally {
    loading.value = false;
  }
};

const isFieldDisabled = (field) => props.mode === 'edit' && field === mergedDefinition.value.idField;

const parseLooseValue = (raw) => {
  const value = String(raw || '').trim();
  if (value === '') {
    return '';
  }
  if (value === 'true') {
    return true;
  }
  if (value === 'false') {
    return false;
  }
  if (/^-?\d+(\.\d+)?$/.test(value)) {
    return Number(value);
  }
  if ((value.startsWith('{') && value.endsWith('}')) || (value.startsWith('[') && value.endsWith(']'))) {
    return JSON.parse(value);
  }
  return value;
};

const addField = () => {
  error.value = '';
  const field = newFieldName.value.trim();
  if (!field) {
    return;
  }
  if (Object.prototype.hasOwnProperty.call(fieldKinds.value, field)) {
    error.value = `Field "${field}" already exists.`;
    return;
  }

  try {
    classifyField(field, parseLooseValue(newFieldValue.value));
    newFieldName.value = '';
    newFieldValue.value = '';
  } catch {
    error.value = 'Invalid JSON in new field value.';
  }
};

const buildPayload = () => {
  const payload = {};
  for (const field of Object.keys(fieldKinds.value)) {
    const kind = fieldKinds.value[field];
    if (kind === 'json') {
      const raw = String(jsonValues.value[field] || '').trim();
      if (raw === '') {
        payload[field] = null;
      } else {
        payload[field] = JSON.parse(raw);
      }
      continue;
    }
    payload[field] = primitiveValues.value[field];
  }
  return payload;
};

const submit = async () => {
  saving.value = true;
  error.value = '';
  success.value = '';

  try {
    const payload = buildPayload();
    if (props.mode === 'create') {
      const result = await createRecord(props.entity, payload);
      success.value = 'Record created.';
      emit('submit-success', { mode: props.mode, payload, result });
      const id = payload[mergedDefinition.value.idField];
      if (props.redirectAfterCreate && id) {
        await router.push(`/${props.entity}/edit/${encodeURIComponent(String(id))}`);
      }
    } else {
      const result = await updateRecord(props.entity, props.recordId, payload);
      success.value = 'Record updated.';
      emit('submit-success', { mode: props.mode, payload, result });
    }
  } catch (err) {
    error.value = err instanceof Error ? err.message : String(err);
    emit('submit-error', error.value);
  } finally {
    saving.value = false;
  }
};

watch(
  () => [props.entity, props.recordId, props.mode],
  () => {
    loadRecord();
  }
);

watch(
  sections,
  (nextSections) => {
    if (nextSections.length === 0) {
      activeSectionId.value = '';
      return;
    }
    if (!nextSections.some((section) => section.id === activeSectionId.value)) {
      activeSectionId.value = nextSections[0].id;
    }
  },
  { immediate: true }
);

onMounted(loadRecord);
</script>
