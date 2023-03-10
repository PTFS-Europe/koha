<template>
    <div id="toolbar" class="btn-toolbar">
        <button
            class="btn btn-default"
            @click="this.$emit('add_harvester', 'add')"
        >
            <font-awesome-icon icon="plus" />
            {{ $__("New harvester") }}
        </button>
    </div>
</template>

<script>
export default {
    name: "UsageStatisticsHarvesterToolbar",
    emits: ["add_harvester"],
}
</script>

<style scoped>
#toolbar {
    background-color: white;
}
</style>
