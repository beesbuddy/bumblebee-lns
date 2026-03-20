<template>
  <div class="form-group">
    <label class="col-sm-2 control-label">{{ label }}</label>
    <div class="col-sm-10">
      <slot
        name="field"
        :field="field"
        :kind="kind"
        :disabled="disabled"
        :primitive-values="primitiveValues"
        :json-values="jsonValues"
      >
        <template v-if="kind === 'boolean'">
          <input
            v-model="primitiveValues[field]"
            type="checkbox"
            :disabled="disabled"
          />
        </template>

        <template v-else-if="kind === 'number'">
          <input
            v-model.number="primitiveValues[field]"
            type="number"
            class="form-control"
            :disabled="disabled"
          />
        </template>

        <template v-else-if="kind === 'json'">
          <textarea
            v-model="jsonValues[field]"
            rows="4"
            class="form-control"
            :disabled="disabled"
          />
          <small class="text-muted">{{ t('ui.json_hint', 'JSON object or array') }}</small>
        </template>

        <template v-else>
          <input
            v-model="primitiveValues[field]"
            type="text"
            class="form-control"
            :disabled="disabled"
          />
        </template>
      </slot>
    </div>
  </div>
</template>

<script setup>
import { t } from '../../i18n';

defineProps({
  field: {
    type: String,
    required: true
  },
  label: {
    type: String,
    required: true
  },
  kind: {
    type: String,
    required: true
  },
  disabled: {
    type: Boolean,
    default: false
  },
  primitiveValues: {
    type: Object,
    required: true
  },
  jsonValues: {
    type: Object,
    required: true
  }
});
</script>
