<template>
    <template v-if="display === 'picker'">
        <WidgetPickerWrapper
            :alreadyAdded="alreadyAdded"
            @added="addWidget"
            @removed="removeWidget"
            :name="name"
            :description="description"
        >
        </WidgetPickerWrapper>
    </template>
    <template v-else-if="display === 'dashboard'">
        <WidgetDashboardWrapper
            :loading="loading"
            @removed="removeWidget"
            :name="name"
        >
            <template #default>
                <div v-if="!default_usage_reports.length">
                    <div class="d-flex align-items-center alert alert-info">
                        {{
                            $__("No saved eUsage reports are available to run.")
                        }}
                    </div>
                    <button
                        class="btn btn-primary"
                        type="button"
                        @click="createReport"
                    >
                        {{ $__("Create a report") }}
                    </button>
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
        </WidgetDashboardWrapper>
    </template>
</template>
<script>
import { getCurrentInstance, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { APIClient } from "../../../fetch/api-client.js";
import WidgetDashboardWrapper from "../WidgetDashboardWrapper.vue";
import WidgetPickerWrapper from "../WidgetPickerWrapper.vue";
import BaseWidget from "../BaseWidget.vue";

export default {
    extends: BaseWidget,
    setup(props, { emit }) {
        const instance = getCurrentInstance();
        const name = "Run eUsage report";
        const description = "Select a saved eUsage report to run.";
        const default_usage_reports = ref([]);
        const selected_report = ref(null);
        const reportsLoaded = ref(false);
        const getReports = async () => {
            try {
                const response =
                    await APIClient.erm.default_usage_reports.getAll();
                default_usage_reports.value = response;
                instance.proxy.loading = false;
            } catch (error) {
                console.error("Error getting default usage reports", error);
            }
        };

        const router = useRouter();
        const runReport = e => {
            e.preventDefault();
            router.push({
                name: "UsageStatisticsReportsViewer",
                query: { data: selected_report.value.report_url_params },
            });
        };

        const createReport = e => {
            e.preventDefault();
            router.push({
                name: "UsageStatisticsReportsHome",
            });
        };

        onMounted(() => {
            if (!reportsLoaded.value) {
                getReports();
                reportsLoaded.value = true;
            }
        });

        return {
            ...BaseWidget.setup(
                {
                    default_usage_reports,
                    selected_report,
                    getReports,
                    createReport,
                    runReport,
                    name,
                    description,
                },
                { emit }
            ),
        };
    },
    components: { WidgetDashboardWrapper, WidgetPickerWrapper },
    name: "ERMRunUsageReport",
};
</script>
