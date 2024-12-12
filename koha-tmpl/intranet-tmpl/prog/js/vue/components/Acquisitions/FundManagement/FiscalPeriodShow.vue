<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fiscal_periods_show">
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
        <h2>
            {{ $__("Fiscal period %s").format(fiscal_period.fiscal_period_id) }}
        </h2>
        <div style="display: flex">
            <DisplayDataFields
                :data="fiscal_period"
                homeRoute="FiscalPeriodList"
                dataType="fiscalPeriod"
                :showClose="false"
            />
            <div class="page-section filler"></div>
        </div>
    </div>
    <div v-if="initialized" id="ledgers">
        <div class="page-section">
            <h3>{{ $__("Ledgers") }}</h3>
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @show="doShow"
                @edit="doEdit"
                @delete="doDelete"
            ></KohaTable>
        </div>
    </div>
</template>

<script>
import { inject, ref } from "vue"
import { APIClient } from "../../../fetch/api-client.js"
import DisplayDataFields from "../../DisplayDataFields.vue"
import Toolbar from "../../Toolbar.vue"
import ToolbarButton from "../../ToolbarButton.vue"
import ToolbarLink from "../../ToolbarLink.vue"
import KohaTable from "../../KohaTable.vue"
import FiscalPeriodResource from "./FiscalPeriodResource.vue"

export default {
    extends: FiscalPeriodResource,
    setup() {
        const { setConfirmationDialog, setMessage } = inject("mainStore")

        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore

        const table = ref()

        return {
            ...FiscalPeriodResource.setup(),
            setConfirmationDialog,
            setMessage,
            isUserPermitted,
            formatValueWithCurrency,
            table,
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
            fiscal_period: {},
            initialized: false,
            tableOptions: {
                columns: this.getTableColumns(),
                url: this.tableUrl(),
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
            vm.fiscal_period = vm.getFiscalPeriod(to.params.fiscal_period_id)
        })
    },
    methods: {
        async getFiscalPeriod(fiscal_period_id) {
            const client = APIClient.acquisition
            await client.fiscalPeriods
                .get(fiscal_period_id, {
                    "x-koha-embed": "owner,lib_group_limits",
                })
                .then(
                    fiscal_period => {
                        this.fiscal_period = fiscal_period
                        this.initialized = true
                    },
                    error => {}
                )
        },
        doShow: function ({ ledger_id }, dt, event) {
            event.preventDefault()
            this.$router.push({ name: "LedgerShow", params: { ledger_id } })
        },
        doEdit: function ({ ledger_id }, dt, event) {
            this.$router.push({
                name: "LedgerFormEdit",
                params: { ledger_id },
            })
        },
        doDelete: function (ledger, dt, event) {
            this.setConfirmationDialog(
                {
                    title: this.$__(
                        "Are you sure you want to remove this ledger?"
                    ),
                    message: ledger.name,
                    accept_label: this.$__("Yes, delete"),
                    cancel_label: this.$__("No, do not delete"),
                },
                () => {
                    const client = APIClient.acquisition
                    client.ledgers.delete(ledger.ledger_id).then(
                        success => {
                            this.setMessage(this.$__("Ledger deleted"), true)
                            dt.draw()
                        },
                        error => {}
                    )
                }
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
        tableUrl() {
            const id = this.$route.params.fiscal_period_id
            let url = "/api/v1/acquisitions/ledgers?q="
            const query = {
                "me.fiscal_period_id": id,
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
    },
}
</script>
<style scoped>
.action_links a {
    padding-left: 0.2em;
    font-size: 11px;
    cursor: pointer;
}
.filler {
    width: 50%;
    margin-left: 0em;
}
.page-section + .page-section {
    margin-top: 0em;
}
</style>
