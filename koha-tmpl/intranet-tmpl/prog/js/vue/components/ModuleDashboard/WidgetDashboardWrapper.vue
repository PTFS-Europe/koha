<template>
    <div class="widget">
        <div class="widget-header">
            <div class="row align-items-center">
                <div class="col-md-6">
                    <h2 class="widget-title m-0">{{ name }}</h2>
                </div>
                <div class="col-md-6 text-end">
                    <button
                        v-if="Object.keys(settings_definitions).length"
                        class="btn btn-xs btn-default me-1"
                        @mousedown="toggleSettings"
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
        <div v-if="showSettings" class="widget-settings">
            <form @submit.prevent="saveSettings">
                <fieldset class="rows">
                    <ol>
                        <li
                            v-for="(setting, index) in settings_definitions"
                            v-bind:key="index"
                        >
                            <FormElement
                                :resource="settings"
                                :attr="setting"
                                :index="index"
                            />
                        </li>
                    </ol>
                </fieldset>
                <button class="btn btn-primary" type="submit">Save</button>
            </form>
        </div>
        <div class="widget-content">
            <slot></slot>
        </div>
    </div>
</template>

<script>
import { ref } from "vue";
import FormElement from "../FormElement.vue";
export default {
    props: {
        name: {
            type: String,
            required: true,
        },
        settings: {
            type: Object,
            default: () => ({}),
        },
        settings_definitions: {
            type: Object,
            default: () => ({}),
        },
    },
    setup(props, { emit }) {
        const showSettings = ref(false);

        const removeWidget = () => {
            emit("removed", props);
        };

        function toggleSettings() {
            showSettings.value = !showSettings.value;
        }

        function saveSettings() {
            // Implement saving logic here
            console.log("Settings saved:", settings.value);
        }

        return {
            showSettings,
            toggleSettings,
            removeWidget,
            saveSettings,
        };
    },
    emits: ["removed"],
    components: {
        FormElement,
    },
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

.widget-content,
.widget-settings {
    padding: 12px;
}
</style>
