<template>
    <WidgetWrapper v-bind="widgetWrapperProps">
        <template #default>
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                :key="JSON.stringify(tableOptions)"
                @view="viewJob"
            />
        </template>
    </WidgetWrapper>
</template>

<script>
import { ref } from "vue";
import WidgetWrapper from "../WidgetWrapper.vue";
import BaseWidget from "../BaseWidget.vue";
import KohaTable from "../../KohaTable.vue";

export default {
    extends: BaseWidget,
    setup(props) {
        const table = ref();
        const tableOptions = ref({
            columns: getTableColumns(),
            options: {
                dom: "t",
                pageLength: 5,
            },
            url: "/api/v1/jobs",
            default_filters: {
                only_current: 0,
            },
            actions: {
                0: ["show"],
                "-1": [
                    {
                        view: {
                            text: __("View"),
                            icon: "fa fa-eye",
                        },
                    },
                ],
            },
        });

        //FIXME: This is a copy-paste from background_jobs.tt
        const job_statuses = [
            { _id: "new", _str: __("New") },
            { _id: "cancelled", _str: __("Cancelled") },
            { _id: "finished", _str: __("Finished") },
            { _id: "started", _str: __("Started") },
            { _id: "running", _str: __("Running") },
            { _id: "failed", _str: __("Failed") },
        ];
        function get_job_status(status) {
            let status_lib = job_statuses.find(s => s._id == status);
            if (status_lib) {
                return status_lib._str;
            }
            return status;
        }

        function getTableColumns() {
            return [
                {
                    title: __("Status"),
                    data: "status",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return get_job_status(row.status).escapeHtml();
                    },
                },
                {
                    title: __("Data Provider"),
                    data: "data",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a href="/cgi-bin/koha/erm/eusage/usage_data_providers/' +
                            data.ud_provider_id +
                            '" class="show">' +
                            escape_str(data.ud_provider_name) +
                            "</a>"
                        );
                    },
                },
                {
                    title: __("Started"),
                    data: "started_date",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return $datetime(row.started_date);
                    },
                },
                {
                    title: __("Ended"),
                    data: "ended_date",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return $datetime(row.ended_date);
                    },
                },
            ];
        }

        const viewJob = (job, dt, event) => {
            event.preventDefault();
            window.open(
                "/cgi-bin/koha/admin/background_jobs.pl?op=view&id=" +
                    encodeURIComponent(job.job_id),
                "_blank"
            );
        };

        return {
            ...BaseWidget.setup({
                id: "ERMLatestSUSHIJobs",
                loading: false,
                table,
                tableOptions,
                getTableColumns,
                name: __("Latest SUSHI Counter jobs"),
                description: __("Show latest SUSHI Counter background jobs."),
                viewJob,
            }),
        };
    },
    components: { WidgetWrapper, KohaTable },
    name: "ERMLatestSUSHIJobs",
};
</script>
