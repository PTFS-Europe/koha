<!-- WidgetWrapper.vue -->
<template>
    <template v-if="display === 'picker'">
        <WidgetPickerWrapper
            :id="id"
            :alreadyAdded="alreadyAdded"
            @added="handleAddWidget"
            @removed="handleRemoveWidget"
            :name="name"
            :description="description"
        >
        </WidgetPickerWrapper>
    </template>
    <template v-else-if="display === 'dashboard'">
        <WidgetDashboardWrapper
            @removed="handleRemoveWidget"
            @moveWidget="handleMoveWidget"
            :id="id"
            :settings="settings"
            :settings_definitions="settings_definitions"
            :loading="loading"
            :dashboardColumn="dashboardColumn"
            :name="name"
        >
            <slot />
        </WidgetDashboardWrapper>
    </template>
</template>

<script>
import WidgetDashboardWrapper from "./WidgetDashboardWrapper.vue";
import WidgetPickerWrapper from "./WidgetPickerWrapper.vue";
export default {
    inject: ["removeWidget", "addWidget", "moveWidget"],
    props: {
        display: {
            type: String,
            required: true,
        },
        alreadyAdded: {
            type: Boolean,
            required: false,
            default: false,
        },
        dashboardColumn: {
            type: String,
            required: false,
        },
        id: {
            type: String,
            required: true,
        },
        name: {
            type: String,
            required: true,
        },
        description: {
            type: String,
            required: true,
        },
        loading: {
            type: Boolean,
            required: false,
        },
        settings: {
            type: Object,
            required: false,
        },
        settings_definitions: {
            type: Array,
            required: false,
        },
    },
    methods: {
        handleAddWidget() {
            this.addWidget();
        },
        handleRemoveWidget() {
            this.removeWidget();
        },
        handleMoveWidget: function () {
            this.moveWidget();
        },
    },
    components: { WidgetDashboardWrapper, WidgetPickerWrapper },
    name: "WidgetWrapper",
};
</script>
