<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const entity = computed(() => route.params.entity);
const title = computed(() => `${String(entity.value)} List`);
const createHref = computed(() => `#/${String(entity.value)}/create`);
</script>

<template>
  <div>
    <div class="row list-header">
      <div class="col-lg-12">
        <div class="page-header">
          <div class="pull-right">
            <a class="btn btn-default" :href="createHref">
              <span class="glyphicon glyphicon-plus" aria-hidden="true" />
              <span class="hidden-xs">Create</span>
            </a>
          </div>
          <h1>{{ title }}</h1>
        </div>
      </div>
    </div>

    <div class="row list-view">
      <div class="col-lg-12">
        <table class="grid table table-condensed table-hover table-striped">
          <thead>
            <tr>
              <th>Column 1</th>
              <th>Column 2</th>
              <th>Column 3</th>
              <th>Column 4</th>
            </tr>
          </thead>
          <tbody />
        </table>
      </div>
    </div>

    <div class="row">
      <div class="col-lg-12">
        <nav class="pagination-bar">
          <div class="total no-record">
            <strong>No record found</strong>
          </div>
        </nav>
      </div>
    </div>
  </div>
</template>
