<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fiscal_period_list">
        <Toolbar>
            <ToolbarButton
                action="add"
                @go-to-add-resource="goToResourceAdd"
                :title="$__('New fiscal period')"
            />
        </Toolbar>
        <div v-if="fiscal_period_count > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @edit="goToResourceEdit"
                @delete="doResourceDelete"
            ></KohaTable>
        </div>
        <div v-else class="dialog message">
            {{ $__("There are no fiscal periods defined") }}
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarLink from "../../ToolbarLink.vue"
import { inject, ref } from "vue"
import { APIClient } from "../../../fetch/api-client.js"
import KohaTable from "../../KohaTable.vue"
import FiscalPeriodResource from "./FiscalPeriodResource.vue"

export default {
    extends: FiscalPeriodResource,
    setup() {
        const { setConfirmationDialog, setMessage } = inject("mainStore")
        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted } = acquisitionsStore

        const table = ref()

        return {
            ...FiscalPeriodResource.setup(),
            table,
            setConfirmationDialog,
            setMessage,
            isUserPermitted,
        }
    },
    data() {
        const actionButtons = []
        if (this.isUserPermitted("editFiscalPeriod")) {
            actionButtons.push("edit")
        }
        if (this.isUserPermitted("deleteFiscalPeriod")) {
            actionButtons.push("delete")
        }
        return {
            fiscal_period_count: 0,
            initialized: false,
            tableOptions: {
                columns: this.getTableColumns(),
                url: "/api/v1/acquisitions/fiscal_periods",
                table_settings: null,
                add_filters: true,
                actions: {
                    0: ["show"],
                    "-1": actionButtons,
                },
            },
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getFiscalPeriodCount().then(() => (vm.initialized = true))
        })
    },
    methods: {
        async getFiscalPeriodCount() {
            const client = APIClient.acquisition
            await client.fiscalPeriods.count().then(
                count => {
                    this.fiscal_period_count = count
                },
                error => {}
            )
        },
        getTableColumns: function () {
            return [
                {
                    title: __("Code"),
                    data: "code:fiscal_period_id",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a href="/acquisitions/fund_management/fiscal_period/' +
                            row.fiscal_period_id +
                            '" class="show">' +
                            escape_str(`${row.code}`) +
                            "</a>"
                        )
                    },
                },
                {
                    title: __("Description"),
                    data: "description",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: __("Status"),
                    data: "status",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return row.status ? __("Active") : __("Inactive")
                    },
                },
                {
                    title: __("Start date"),
                    data: "start_date",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return $date(row.start_date)
                    },
                },
                {
                    title: __("End date"),
                    data: "end_date",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return $date(row.end_date)
                    },
                },
            ]
        },
    },
    components: { Toolbar, ToolbarLink, KohaTable },
}
</script>
