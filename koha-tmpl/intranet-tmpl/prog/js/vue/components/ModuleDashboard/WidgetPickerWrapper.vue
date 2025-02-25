<template>
    <div class="widget-details">
        <h3 class="widget-name">
            {{ name }}
        </h3>
        <p class="widget-description">
            {{ description }}
        </p>
        <div class="widget-actions">
            <button class="btn btn-xs btn-default me-1">
                <font-awesome-icon icon="cog" />
                {{ $__("Configure") }}
            </button>
            <button
                v-if="!alreadyAdded"
                class="btn btn-xs btn-primary me-1"
                @click="addWidget"
            >
                {{ $__("Add Widget") }}
            </button>
            <button
                v-if="alreadyAdded"
                class="btn btn-xs btn-default"
                @click="removeWidget"
            >
                <font-awesome-icon icon="trash" />
                {{ $__("Remove") }}
            </button>
        </div>
    </div>
</template>

<script>
export default {
    props: {
        name: {
            type: String,
            required: true,
        },
        description: {
            type: String,
            required: true,
        },
        alreadyAdded: {
            type: Boolean,
            required: false,
            default: false,
        },
    },
    methods: {
        removeWidget() {
            this.$emit("removed", this);
        },
        addWidget() {
            this.$emit("added", this);
        },
    },
    emits: ["removed", "added"],
};
</script>
