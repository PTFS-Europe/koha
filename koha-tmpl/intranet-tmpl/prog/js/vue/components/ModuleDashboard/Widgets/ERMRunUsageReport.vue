<template>
    <WidgetWrapper v-bind="widgetWrapperProps">
        <template #default>
            <div v-if="!default_usage_reports.length">
                <div class="d-flex align-items-center alert alert-info">
                    {{ $__("No saved eUsage reports are available to run.") }}
                </div>
                <router-link :to="{ name: 'UsageStatisticsReportsHome' }">
                    {{ $__("Create a report") }}
                </router-link>
            </div>
            <div v-else class="d-flex align-items-center">
                <div class="flex-grow-1 me-2">
                    <label for="filter" class="visually-hidden">{{
                        $__("Pick a report to run")
                    }}</label>
                    <v-select
                        label="report_name"
                        :options="default_usage_reports"
                        style="min-width: 200px"
                        v-model="selected_report"
                    ></v-select>
                </div>
                <div>
                    <button
                        class="btn btn-primary"
                        type="button"
                        :disabled="!selected_report"
                        @click="runReport"
                    >
                        {{ $__("Run") }}
                    </button>
                </div>
            </div>
        </template>
    </WidgetWrapper>
</template>
<script>
import { ref } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import WidgetWrapper from "../WidgetWrapper.vue";
import BaseWidget from "../BaseWidget.vue";

export default {
    extends: BaseWidget,
    setup(props) {
        const default_usage_reports = ref([]);
        const selected_report = ref(null);

        return {
            ...BaseWidget.setup({
                id: "ERMRunUsageReport",
                default_usage_reports,
                selected_report,
                name: __("Run eUsage report"),
                description: __("Select a saved eUsage report to run."),
            }),
        };
    },
    methods: {
        async getReports() {
            try {
                const response =
                    await APIClient.erm.default_usage_reports.getAll();
                this.default_usage_reports = response;
            } catch (error) {
                console.error("Error getting default usage reports", error);
            }
        },
        onDashboardMounted() {
            this.getReports().then(() => (this.loading = false));
        },
        runReport(e) {
            this.$router.push({
                name: "UsageStatisticsReportsViewer",
                query: { data: this.selected_report.report_url_params },
            });
        },
    },
    components: { WidgetWrapper },
    name: "ERMRunUsageReport",
};
</script>
