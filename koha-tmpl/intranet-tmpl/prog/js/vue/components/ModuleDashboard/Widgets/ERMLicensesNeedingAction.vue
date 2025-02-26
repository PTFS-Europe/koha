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
            :settings="settings"
            :settings_definitions="settings_definitions"
            @removed="removeWidget"
            :name="name"
        >
            <template #default>
                <KohaTable
                    ref="table"
                    v-bind="tableOptions"
                    :key="JSON.stringify(tableOptions)"
                />
            </template>
        </WidgetDashboardWrapper>
    </template>
</template>

<script>
import { inject, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import WidgetDashboardWrapper from "../WidgetDashboardWrapper.vue";
import WidgetPickerWrapper from "../WidgetPickerWrapper.vue";
import BaseWidget from "../BaseWidget.vue";
import KohaTable from "../../KohaTable.vue";

export default {
    extends: BaseWidget,
    setup(props, { emit }) {
        const name = __("Licenses needing action");
        const description = __(
            "Show licenses that need action. It filters licenses by status and end date. This widget is configurable."
        );
        const AVStore = inject("AVStore");
        const { av_license_statuses } = storeToRefs(AVStore);
        const { get_lib_from_av, map_av_dt_filter } = AVStore;

        const settings = ref({
            status: ["in_negotiation", "not_yet_active", "rejected"],
        });
        const settings_definitions = ref([
            {
                name: "status",
                type: "select",
                label: __("Status"),
                showInTable: true,
                options: av_license_statuses.value.map(status => ({
                    value: status.value,
                    description: status.description,
                })),
                allowMultipleChoices: true,
                requiredKey: "value",
                selectLabel: "description",
            },
            {
                name: "ended_on",
                type: "select",
                label: __("Ends in the next"),
                showInTable: true,
                options: [
                    { value: "week", description: __("Week") },
                    { value: "two_weeks", description: __("Two weeks") },
                    { value: "month", description: __("Month") },
                    { value: "two_months", description: __("Two months") },
                ],
                requiredKey: "value",
                selectLabel: "description",
            },
        ]);

        const table = ref();
        const tableOptions = ref({
            columns: getTableColumns(),
            options: {
                dom: "t",
                embed: "vendor,extended_attributes,+strings",
            },
            url: "/api/v1/erm/licenses",
            default_filters: {
                "me.status": {
                    "-in": settings.value["status"],
                },
            },
        });

        watch(
            settings,
            newSettings => {
                tableOptions.value.default_filters =
                    getDefaultFilters(newSettings);
            },
            { deep: true }
        );

        function getDefaultFilters(settings) {
            const default_filters = {};

            if (settings["status"] && settings["status"].length) {
                default_filters["me.status"] = {
                    "-in": settings["status"],
                };
            }

            if (settings["ended_on"] && settings["ended_on"].length) {
                switch (settings["ended_on"]) {
                    case "week":
                        default_filters["me.ended_on"] = {
                            "<=": new Date(
                                new Date().setDate(new Date().getDate() + 7)
                            ),
                        };
                        break;
                    case "two_weeks":
                        default_filters["me.ended_on"] = {
                            "<=": new Date(
                                new Date().setDate(new Date().getDate() + 14)
                            ),
                        };
                        break;
                    case "month":
                        default_filters["me.ended_on"] = {
                            "<=": new Date(
                                new Date().setMonth(new Date().getMonth() + 1)
                            ),
                        };
                        break;
                    case "two_months":
                        default_filters["me.ended_on"] = {
                            "<=": new Date(
                                new Date().setMonth(new Date().getMonth() + 2)
                            ),
                        };
                        break;
                }
            }

            return default_filters;
        }

        function getTableColumns() {
            return [
                {
                    title: __("Name"),
                    data: "name",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a href="/cgi-bin/koha/erm/licenses/' +
                            row.license_id +
                            '" class="show">' +
                            escape_str(row.name) +
                            "</a>"
                        );
                    },
                },
                {
                    title: __("Type"),
                    data: "type",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return escape_str(
                            get_lib_from_av("av_license_types", row.type)
                        );
                    },
                },
                {
                    title: __("Status"),
                    data: "status",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return escape_str(
                            get_lib_from_av("av_license_statuses", row.status)
                        );
                    },
                },
                {
                    title: __("Ends on"),
                    data: "ended_on",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return $date(row.ended_on);
                    },
                },
            ];
        }

        return {
            ...BaseWidget.setup(
                {
                    get_lib_from_av,
                    map_av_dt_filter,
                    escape_str,
                    table,
                    tableOptions,
                    getTableColumns,
                    name,
                    description,
                    settings,
                    settings_definitions,
                    av_license_statuses,
                },
                { emit }
            ),
        };
    },
    components: { WidgetDashboardWrapper, WidgetPickerWrapper, KohaTable },
    name: "ERMLicensesNeedingAction",
};
</script>
