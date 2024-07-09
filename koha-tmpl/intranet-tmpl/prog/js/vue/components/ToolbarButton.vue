<template>
    <a v-if="type === 'add'" @click="click_add" class="btn btn-default"
        ><font-awesome-icon icon="plus" /> {{ title }}</a
    >
    <a v-if="type === 'delete'" @click="click_delete" class="btn btn-default"
        ><font-awesome-icon icon="trash" /> {{ $__("Delete") }}</a
    >
    <a v-if="type === 'edit'" @click="click_edit" class="btn btn-default"
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
    methods: {
        click_add() {
            this.$emit("add-clicked");
        },
        click_delete() {
            this.$emit("delete-clicked");
        },
        click_edit() {
            this.$emit("edit-clicked");
        },
    },
    emits: ["add-clicked", "delete-clicked", "edit-clicked"],
    name: "Toolbar",
};
</script>
