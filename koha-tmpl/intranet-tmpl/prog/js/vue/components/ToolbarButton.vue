<template>
    <a
        v-if="type === 'add'"
        @click="$emit('addResource')"
        class="btn btn-default"
        ><font-awesome-icon icon="plus" /> {{ title }}</a
    >
    <a
        v-if="type === 'delete'"
        @click="$emit('deleteResource')"
        class="btn btn-default"
        ><font-awesome-icon icon="trash" /> {{ $__("Delete") }}</a
    >
    <a
        v-if="type === 'edit'"
        @click="$emit('editResource')"
        class="btn btn-default"
        ><font-awesome-icon icon="pencil" /> {{ $__("Edit") }}</a
    >
</template>

<script>
export default {
    props: {
        type: {
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
    emits: ["addResource", "deleteResource", "editResource"],
    name: "Toolbar",
};
</script>
