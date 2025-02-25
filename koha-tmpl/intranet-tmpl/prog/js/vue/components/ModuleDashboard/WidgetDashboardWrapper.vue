<template>
    <div class="widget">
        <div class="widget-header">
            <div class="row align-items-center">
                <div class="col-md-6">
                    <h2 class="widget-title m-0">{{ name }}</h2>
                </div>
                <div class="col-md-6 text-end">
                    <button
                        class="btn btn-xs btn-default me-1"
                        @mousedown="editWidget"
                        :title="$__('Configure')"
                    >
                        <font-awesome-icon icon="cog" />
                    </button>
                    <button
                        class="btn btn-xs btn-default"
                        @mousedown="removeWidget"
                        :title="$__('Remove')"
                    >
                        <font-awesome-icon icon="trash" />
                    </button>
                </div>
            </div>
        </div>
        <div class="widget-content">
            <slot></slot>
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
    },
    methods: {
        removeWidget() {
            this.$emit("removed", this);
        },
    },
    emits: ["removed"],
};
</script>

<style scoped>
.widget {
    background-color: #fff;
    border: 1px solid #ccc;
    border-radius: 8px;
    padding: 16px;
    margin-bottom: 12px;
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.widget-header {
    background-color: #f7f7f7;
    border-bottom: 1px solid #ccc;
    padding: 12px;
    border-top-left-radius: 8px;
    border-top-right-radius: 8px;
}

.widget-title {
    margin-top: 0;
    font-weight: bold;
    font-size: 1.25rem;
}

.widget-content {
    padding: 12px;
}
</style>
