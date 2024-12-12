<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="ledgers_show">
        <Toolbar>
            <ToolbarButton
                action="edit"
                @go-to-edit-resource="goToResourceEdit"
            />
            <ToolbarButton
                action="delete"
                @delete-resource="doResourceDelete"
            />
        </Toolbar>
        <h2>{{ ledger.name }}</h2>
        <div class="ledger_display">
            <DisplayDataFields
                :data="ledger"
                homeRoute="LedgerList"
                dataType="ledger"
                :showClose="false"
            />
            <AccountingView :data="ledger" :currency="ledger.currency" />
        </div>
    </div>
    <div v-if="initialized" id="funds">
        <div class="page-section">
            <h3>{{ $__("Funds") }}</h3>
            <KohaTable ref="table" v-bind="tableOptions"></KohaTable>
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarButton from "../../ToolbarButton.vue"
import ToolbarLink from "../../ToolbarLink.vue"
import { inject } from "vue"
import { APIClient } from "../../../fetch/api-client.js"
import DisplayDataFields from "../../DisplayDataFields.vue"
import KohaTable from "../../KohaTable.vue"
import AccountingView from "./AccountingView.vue"
import LedgerResource from "./LedgerResource.vue"

export default {
    extends: LedgerResource,
    setup() {
        const { setConfirmationDialog, setMessage } = inject("mainStore")

        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore

        return {
            ...LedgerResource.setup(),
            setConfirmationDialog,
            setMessage,
            isUserPermitted,
            formatValueWithCurrency,
        }
    },
    data() {
        return {
            ledger: {},
            initialized: false,
            tableOptions: {
                columns: this.getTableColumns(),
                url: this.tableUrl(),
                options: { embed: "fund_allocations" },
                table_settings: null,
                add_filters: true,
                actions: {
                    0: ["show"],
                },
            },
            currency: null,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.ledger = vm.getLedger(to.params.ledger_id)
        })
    },
    methods: {
        async getLedger(ledger_id) {
            const client = APIClient.acquisition
            await client.ledgers
                .get(ledger_id, {
                    "x-koha-embed":
                        "fiscal_period,funds.fund_allocations,lib_group_limits,owner",
                })
                .then(
                    ledger => {
                        this.ledger = ledger
                        this.initialized = true
                    },
                    error => {}
                )
        },
        getTableColumns: function () {
            const formatValueWithCurrency = this.formatValueWithCurrency
            return [
                {
                    title: __("Name"),
                    data: "name",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a href="/acquisitions/fund_management/fund/' +
                            row.fund_id +
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
                    title: __("Fund value"),
                    data: "fund_total",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return formatValueWithCurrency(
                            row.currency,
                            row.fund_value
                        )
                    },
                },
            ]
        },
        tableUrl() {
            const id = this.$route.params.ledger_id
            let url = "/api/v1/acquisitions/funds?q="
            const query = {
                "me.ledger_id": id,
            }
            return url + JSON.stringify(query)
        },
    },
    components: {
        DisplayDataFields,
        Toolbar,
        ToolbarButton,
        ToolbarLink,
        KohaTable,
        AccountingView,
    },
}
</script>

<style scoped>
#funds {
    margin-top: 1em;
}
.ledger_display {
    display: flex;
    gap: 1em;
}
</style>
