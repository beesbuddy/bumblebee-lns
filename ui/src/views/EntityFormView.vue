<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import BaseEntityForm from '../components/admin/BaseEntityForm.vue';

const props = defineProps({
  mode: {
    type: String,
    required: true
  }
});

const route = useRoute();
const entity = computed(() => String(route.params.entity || ''));
const recordId = computed(() => String(route.params.id || ''));
</script>

<template>
  <BaseEntityForm :entity="entity" :mode="mode" :record-id="recordId" />
</template>
