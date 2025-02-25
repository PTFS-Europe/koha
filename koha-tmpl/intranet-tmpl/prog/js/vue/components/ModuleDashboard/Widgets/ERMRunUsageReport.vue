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
                <div class="d-flex align-items-center">
                    <div class="flex-grow-1 me-2">
                        <label for="filter" class="visually-hidden"
                            >Pick a report to run</label
                        >
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
                            Run
                        </button>
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
    setup(props, { emit }) {
        const name = "Run eUsage report";
        const description = "Run a eUsage report.";
        const default_usage_reports = ref([]);
        const selected_report = ref(null);
        const reportsLoaded = ref(false);

        const getReports = async () => {
            try {
                const response =
                    await APIClient.erm.default_usage_reports.getAll();
                default_usage_reports.value = response;
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
            runReport,
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
