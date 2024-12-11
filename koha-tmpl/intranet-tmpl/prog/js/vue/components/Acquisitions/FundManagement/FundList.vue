<template>
    <div v-if="!initialized">Loading...</div>
    <div v-else id="fund_list">
        <Toolbar>
            <ToolbarLink
                :to="{ name: 'FundFormAdd' }"
                icon="plus"
                title="New fund"
                v-if="isUserPermitted('createFund')"
            />
        </Toolbar>
        <div v-if="fund_count > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @show="doShow"
                @edit="doEdit"
                @delete="doDelete"
            ></KohaTable>
        </div>
        <div v-else class="dialog message">There are no funds defined</div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarLink from "../../ToolbarLink.vue"
import { inject, ref } from "vue"
import { APIClient } from "../../../fetch/api-client.js"
import KohaTable from "../../KohaTable.vue"

export default {
    setup() {
        const { setConfirmationDialog, setMessage } = inject("mainStore")
        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore

        const table = ref()

        return {
            table,
            setConfirmationDialog,
            setMessage,
            formatValueWithCurrency,
            isUserPermitted,
        }
    },
    data() {
        const actionButtons = []
        if (this.isUserPermitted("editFund")) {
            actionButtons.push("edit")
        }
        if (this.isUserPermitted("deleteFund")) {
            actionButtons.push("delete")
        }
        return {
            fund_count: 0,
            initialized: false,
            tableOptions: {
                columns: this.getTableColumns(),
                url: "/api/v1/acquisitions/funds",
                options: { embed: "fund_allocations" },
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
            vm.getFundCount().then(() => (vm.initialized = true))
        })
    },
    methods: {
        async getFundCount() {
            const client = APIClient.acquisition
            await client.funds.count().then(
                count => {
                    this.fund_count = count
                },
                error => {}
            )
        },
        doShow: function ({ fund_id }, dt, event) {
            event.preventDefault()
            this.$router.push({ name: "FundShow", params: { fund_id } })
        },
        doEdit: function ({ fund_id }, dt, event) {
            this.$router.push({
                name: "FundFormEdit",
                params: { fund_id },
            })
        },
        doDelete: function (fund, dt, event) {
            this.setConfirmationDialog(
                {
                    title: "Are you sure you want to remove this fund?",
                    message: fund.name,
                    accept_label: "Yes, delete",
                    cancel_label: "No, do not delete",
                },
                () => {
                    const client = APIClient.acquisition
                    client.funds.delete(fund.fund_id).then(
                        success => {
                            this.setMessage(`Fund deleted`, true)
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
                    data: "name:fund_id",
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
                        return row.status ? "Active" : "Inactive"
                    },
                },
                {
                    title: __("Fund value"),
                    data: "fund_value",
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
    },
    components: { Toolbar, ToolbarLink, KohaTable },
}
</script>
