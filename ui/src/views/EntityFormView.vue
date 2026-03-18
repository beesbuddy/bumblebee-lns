<template>
  <div>
    <div class="row list-header">
      <div class="col-lg-12">
        <div class="page-header">
          <div class="pull-right">
            <a class="btn btn-default" :href="listHref">
              <span class="glyphicon glyphicon-list" aria-hidden="true" />
              <span class="hidden-xs">List</span>
            </a>
          </div>
          <h1>{{ title }}</h1>
        </div>
      </div>
    </div>

    <ul class="nav nav-tabs">
      <li class="active"><a>General</a></li>
      <li><a>Status</a></li>
      <li><a>Advanced</a></li>
    </ul>

    <div class="tab-pane">
      <div class="row">
        <div class="col-lg-12">
          <form class="form-horizontal">
            <div class="form-group">
              <label class="col-sm-2 control-label">Field A</label>
              <div class="col-sm-10">
                <input type="text" class="form-control" />
              </div>
            </div>
            <div class="form-group">
              <label class="col-sm-2 control-label">Field B</label>
              <div class="col-sm-10">
                <input type="text" class="form-control" />
              </div>
            </div>
            <div class="form-group">
              <div class="col-sm-offset-2 col-sm-10">
                <button type="submit" class="btn btn-primary">
                  <span class="glyphicon glyphicon-ok"></span>
                  <span class="hidden-xs ng-scope" translate="SUBMIT">
                    Submit
                  </span>
                </button>
              </div>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';

const props = defineProps({
  mode: {
    type: String,
    required: true
  }
});

const route = useRoute();
const entity = computed(() => String(route.params.entity));
const id = computed(() => String(route.params.id || ''));
const title = computed(() => {
  if (props.mode === 'create') return `Create ${entity.value}`;
  return `Edit ${entity.value}: ${id.value}`;
});
const listHref = computed(() => `#/${entity.value}/list`);
</script>
