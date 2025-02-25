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
                <KohaTable ref="table" v-bind="tableOptions" />
            </template>
        </WidgetDashboardWrapper>
    </template>
</template>

<script>
import { inject, ref } from "vue";
import WidgetDashboardWrapper from "../WidgetDashboardWrapper.vue";
import WidgetPickerWrapper from "../WidgetPickerWrapper.vue";
import KohaTable from "../../KohaTable.vue";

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
        const name = "Licenses needing action";
        const description =
            "Shows the number of ERM agreements, licenses, and packages";
        const AVStore = inject("AVStore");
        const { get_lib_from_av, map_av_dt_filter } = AVStore;
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
                    "-not_in": ["active", "expired"],
                },
            },
        });

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
            ];
        }

        return {
            get_lib_from_av,
            map_av_dt_filter,
            escape_str,
            table,
            tableOptions,
            getTableColumns,
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
    components: { WidgetDashboardWrapper, WidgetPickerWrapper, KohaTable },
    name: "ERMLicensesNeedingAction",
};
</script>
