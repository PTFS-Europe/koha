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
        <WidgetDashboardWrapper @removed="removeWidget" :name="name">
            <template #default>
                <div v-if="loading" class="text-center">
                    {{ $__("Loading...") }}
                </div>
                <div v-else>
                    <div v-if="!default_usage_reports.length">
                        <div class="d-flex align-items-center alert alert-info">
                            {{
                                $__(
                                    "No saved eUsage reports are available to run."
                                )
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
                                @click="runReport"
                            >
                                {{ $__("Run") }}
                            </button>
                        </div>
                    </div>
                </div>
            </template>
        </WidgetDashboardWrapper>
    </template>
</template>
<script>
import { onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { APIClient } from "../../../fetch/api-client.js";
import WidgetDashboardWrapper from "../WidgetDashboardWrapper.vue";
import WidgetPickerWrapper from "../WidgetPickerWrapper.vue";

export default {
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
    },
    setup(props) {
        const name = "Run eUsage report";
        const description = "Select a saved eUsage report to run.";
        const default_usage_reports = ref([]);
        const selected_report = ref(null);
        const reportsLoaded = ref(false);
        const loading = ref(true);
        const getReports = async () => {
            try {
                const response =
                    await APIClient.erm.default_usage_reports.getAll();
                default_usage_reports.value = response;
                loading.value = false;
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
            default_usage_reports,
            selected_report,
            getReports,
            createReport,
            runReport,
            loading,
            name,
            description,
        };
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
    components: { WidgetDashboardWrapper, WidgetPickerWrapper },
    name: "ERMRunUsageReport",
};
</script>
