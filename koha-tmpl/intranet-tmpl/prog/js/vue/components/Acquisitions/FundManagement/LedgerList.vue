<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="ledger_list">
        <Toolbar>
            <ToolbarButton
                action="add"
                @go-to-add-resource="goToResourceAdd"
                :title="$__('New ledger')"
            />
        </Toolbar>
        <div v-if="ledger_count > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @edit="goToResourceEdit"
                @delete="doResourceDelete"
            ></KohaTable>
        </div>
        <div v-else class="dialog message">
            {{ $__("There are no ledgers defined") }}
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarLink from "../../ToolbarLink.vue"
import { inject, ref } from "vue"
import { APIClient } from "../../../fetch/api-client.js"
import KohaTable from "../../KohaTable.vue"
import LedgerResource from "./LedgerResource.vue"

export default {
    extends: LedgerResource,
    setup() {
        const { setConfirmationDialog, setMessage } = inject("mainStore")
        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore

        const table = ref()

        return {
            ...LedgerResource.setup(),
            table,
            setConfirmationDialog,
            setMessage,
            isUserPermitted,
            formatValueWithCurrency,
        }
    },
    data() {
        const actionButtons = []
        if (this.isUserPermitted("editLedger")) {
            actionButtons.push("edit")
        }
        if (this.isUserPermitted("deleteLedger")) {
            actionButtons.push("delete")
        }
        return {
            ledger_count: 0,
            initialized: false,
            tableOptions: {
                columns: this.getTableColumns(),
                url: "/api/v1/acquisitions/ledgers",
                options: { embed: "funds" },
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
            vm.getLedgerCount().then(() => (vm.initialized = true))
        })
    },
    methods: {
        async getLedgerCount() {
            const client = APIClient.acquisition
            await client.ledgers.count().then(
                count => {
                    this.ledger_count = count
                },
                error => {}
            )
        },
        getTableColumns: function () {
            const formatValueWithCurrency = this.formatValueWithCurrency
            return [
                {
                    title: __("Name"),
                    data: "name:ledger_id",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a href="/acquisitions/fund_management/ledger/' +
                            row.ledger_id +
                            '" class="show">' +
                            escape_str(`${row.name}`) +
                            "</a>"
                        )
                    },
                },
                {
                    title: __("Code"),
                    data: "code",
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
                    title: __("Fund count"),
                    data: "status",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return row.funds.length
                    },
                },
                {
                    title: __("Ledger value"),
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        const sum = row.funds.reduce(
                            (acc, curr) => acc + curr.fund_value,
                            0
                        )
                        return formatValueWithCurrency(row.currency, sum)
                    },
                },
            ]
        },
    },
    components: { Toolbar, ToolbarLink, KohaTable },
}
</script>
