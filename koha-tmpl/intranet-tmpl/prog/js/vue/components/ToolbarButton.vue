<template>
    <a v-if="action === 'add'" @click="$emit('addResource')" :class="class"
        ><font-awesome-icon icon="plus" /> {{ title }}</a
    >
    <a
        v-else-if="action === 'delete'"
        @click="$emit('deleteResource')"
        :class="class"
        ><font-awesome-icon icon="trash" /> {{ $__("Delete") }}</a
    >
    <a
        v-else-if="action === 'edit'"
        @click="$emit('editResource')"
        :class="class"
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
        class: {
            type: String,
            default: "btn btn-default",
        },
        icon: {
            type: String,
            required: false,
        },
        title: {
            type: String,
        },
    },
    emits: ["addResource", "deleteResource", "editResource"],
    name: "Toolbar",
}
</script>
