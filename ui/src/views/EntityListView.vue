<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import BaseEntityList from '../components/admin/BaseEntityList.vue';

const route = useRoute();
const entity = computed(() => String(route.params.entity || ''));
</script>

<template>
  <BaseEntityList :entity="entity" />
</template>
