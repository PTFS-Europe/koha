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
                        :class="{ 'settings-open': showSettings }"
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
            <form>
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
            </form>
        </div>
        <div class="widget-content">
            <div v-if="loading" class="text-center">
                {{ $__("Loading...") }}
            </div>
            <slot v-else></slot>
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
        loading: {
            type: Boolean,
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

.widget-header,
.widget-settings {
    background-color: #f7f7f7;
    border-bottom: 1px solid #ccc;
    border-top-left-radius: 8px;
    border-top-right-radius: 8px;
}

.widget-settings fieldset {
    background-color: #f7f7f7;
}

.widget-settings fieldset.rows ol {
    padding: 0;
}

.widget-settings form:after {
    content: "";
    display: table;
    clear: both;
}

:deep(.widget-settings form .v-select) {
    display: inline-block;
    background-color: white;
    width: 60%;
}

:deep(.v-select),
:deep(
    input:not([type="submit"]):not([type="search"]):not([type="button"]):not(
            [type="checkbox"]
        ):not([type="radio"])
),
:deep(textarea) {
    border-color: rgba(60, 60, 60, 0.26);
    border-width: 1px;
    border-radius: 4px;
    min-width: 60%;
}

.widget-header .btn.settings-open {
    color: var(--bs-btn-hover-color);
    text-decoration: none;
    background-color: var(--bs-btn-hover-bg);
    border-color: var(--bs-btn-hover-border-color);
}

.widget-title {
    margin-top: 0;
    font-weight: bold;
    font-size: 1.25rem;
}

.widget-content,
.widget-settings,
.widget-header {
    padding: 12px;
}
</style>
