<template>
    <div id="toolbar" class="btn-toolbar">
        <router-link to="#" class="btn btn-default"
            ><font-awesome-icon icon="plus" />
            {{ $__("Edit homepage") }}</router-link
        >
    </div>
    <div class="widget-grid">
        <p>Hello</p>
        <p>Hello</p>
        <p>Hello</p>
        <p>Hello</p>
    </div>
</template>

<script>
export default {
    data() {
        return {}
    },
    methods: {},
    components: {},
}
</script>

<style scoped>
.widget-grid {
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    height: 100%;
}
</style>
