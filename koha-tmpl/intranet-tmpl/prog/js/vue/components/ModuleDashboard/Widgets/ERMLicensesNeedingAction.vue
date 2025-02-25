<template>
    <WidgetWrapper v-bind="widgetWrapperProps">
        <template #default>
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                :key="JSON.stringify(tableOptions)"
            />
        </template>
    </WidgetWrapper>
</template>

<script>
import { inject, ref, computed } from "vue";
import { storeToRefs } from "pinia";
import WidgetWrapper from "../WidgetWrapper.vue";
import BaseWidget from "../BaseWidget.vue";
import KohaTable from "../../KohaTable.vue";

export default {
    extends: BaseWidget,
    setup(props) {
        const AVStore = inject("AVStore");
        const { av_license_statuses } = storeToRefs(AVStore);
        const { get_lib_from_av } = AVStore;

        const table = ref();

        function getTableColumns() {
            return [
                {
                    title: __("Name"),
                    data: "name",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        const name = escape_str(row.name);
                        return (
                            '<a href="/cgi-bin/koha/erm/licenses/' +
                            row.license_id +
                            '" class="show">' +
                            (name.length > 25
                                ? name.substring(0, 22) + "..."
                                : name) +
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

        const default_settings = {
            status: ["in_negotiation", "not_yet_active", "rejected"],
            per_page: 5,
        };

        const settings = ref(default_settings);
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
            {
                name: "per_page",
                type: "select",
                label: __("Show"),
                showInTable: true,
                options: [
                    { value: 5, description: "5" },
                    { value: 10, description: "10" },
                    { value: 20, description: "20" },
                ],
                requiredKey: "value",
                selectLabel: "description",
            },
        ]);

        function settingsToQueryParams(settings) {
            const params = {};

            if (settings.status && settings.status.length > 0) {
                params["me.status"] = {
                    "-in": settings.status,
                };
            }

            if (settings.ended_on) {
                switch (settings.ended_on) {
                    case "week":
                        params["me.ended_on"] = {
                            "<=": new Date(
                                new Date().setDate(new Date().getDate() + 7)
                            ),
                        };
                        break;
                    case "two_weeks":
                        params["me.ended_on"] = {
                            "<=": new Date(
                                new Date().setDate(new Date().getDate() + 14)
                            ),
                        };
                        break;
                    case "month":
                        params["me.ended_on"] = {
                            "<=": new Date(
                                new Date().setMonth(new Date().getMonth() + 1)
                            ),
                        };
                        break;
                    case "two_months":
                        params["me.ended_on"] = {
                            "<=": new Date(
                                new Date().setMonth(new Date().getMonth() + 2)
                            ),
                        };
                        break;
                }
            }
            return params;
        }

        const tableOptions = computed(() => ({
            columns: getTableColumns(),
            options: {
                dom: "t",
                embed: "vendor,extended_attributes,+strings",
                ...(settings.value.per_page
                    ? { pageLength: settings.value.per_page }
                    : {}),
            },
            url: "/api/v1/erm/licenses",
            default_filters: settingsToQueryParams(settings.value),
        }));

        return {
            ...BaseWidget.setup({
                id: "ERMLicensesNeedingAction",
                loading: false,
                get_lib_from_av,
                escape_str,
                table,
                getTableColumns,
                settings,
                settings_definitions,
                tableOptions,
                name: __("Licenses needing action"),
                description: __(
                    "Show licenses that need action. It filters licenses by status and end date. This widget is configurable."
                ),
                av_license_statuses,
            }),
        };
    },
    components: { WidgetWrapper, KohaTable },
    name: "ERMLicensesNeedingAction",
};
</script>
