<template>
    <a
        v-if="action === 'add'"
        @click="$emit('go-to-add-resource')"
        class="btn btn-default"
        ><font-awesome-icon icon="plus" /> {{ title }}</a
    >
    <a
        v-else-if="action === 'delete'"
        @click="$emit('delete-resource')"
        class="btn btn-default"
        ><font-awesome-icon icon="trash" /> {{ $__("Delete") }}</a
    >
    <a
        v-else-if="action === 'edit'"
        @click="$emit('go-to-edit-resource')"
        class="btn btn-default"
        ><font-awesome-icon icon="pencil" /> {{ $__("Edit") }}</a
    >
    <span v-else>{{ $__("Unknown action %s").format(action) }}</span>
</template>

<script>
export default {
    props: {
        action: {
            type: String,
            required: true,
        },
        to: {
            type: [String, Object],
        },
        icon: {
            type: String,
            required: false,
        },
        title: {
            type: String,
        },
    },
    emits: ["go-to-add-resource", "go-to-edit-resource", "delete-resource"],
    name: "Toolbar",
};
</script>
