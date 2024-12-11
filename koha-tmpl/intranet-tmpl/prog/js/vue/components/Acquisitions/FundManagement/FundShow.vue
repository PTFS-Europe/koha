<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="funds_show">
        <Toolbar>
            <ToolbarLink
                :to="{ name: 'FundList' }"
                icon="xmark"
                :title="$__('Close')"
            />
            <ToolbarLink
                :to="{
                    name: isSubFund ? 'SubFundFormAddEdit' : 'FundFormEdit',
                    params: {
                        fund_id: fund.fund_id,
                        ...(isSubFund && { sub_fund_id: fund.sub_fund_id }),
                    },
                }"
                icon="pencil"
                :title="$__('Edit')"
                v-if="isUserPermitted('editFund')"
            />
            <ToolbarButton
                icon="trash"
                :title="$__('Delete')"
                @clicked="
                    deleteFund(
                        isSubFund ? fund.sub_fund_id : fund.fund_id,
                        fund.name
                    )
                "
                v-if="isUserPermitted('deleteFund')"
            />
            <ToolbarLink
                :to="{
                    name: 'SubFundFormAdd',
                    params: { [navParam]: fund[navParam] },
                }"
                icon="plus"
                :title="$__('New sub fund')"
                v-if="
                    isUserPermitted('createFund') &&
                    !hasExistingAllocations &&
                    !isSubFund
                "
            />
            <ToolbarLink
                :to="{
                    name: 'FundAllocationFormAdd',
                    params: {
                        fund_id: fund.fund_id,
                        ...(isSubFund && { sub_fund_id: fund.sub_fund_id }),
                    },
                }"
                icon="plus"
                :title="$__('New fund allocation')"
                v-if="
                    isUserPermitted('createFundAllocation') &&
                    !hasSubFunds &&
                    fund.status
                "
            />
            <ToolbarLink
                :to="{
                    name: 'TransferFunds',
                    query: {
                        fund_id: fund.fund_id,
                        ...(isSubFund && { sub_fund_id: fund.sub_fund_id }),
                    },
                }"
                icon="arrow-right-arrow-left"
                :title="$__('Transfer funds')"
                v-if="isUserPermitted('createFundAllocation')"
            />
        </Toolbar>
        <h2>{{ fund.name }}</h2>
        <div class="fund_display">
            <DisplayDataFields
                :data="fund"
                homeRoute="FundList"
                :dataType="isSubFund ? 'subFund' : 'fund'"
                :showClose="false"
            />
            <AccountingView :data="fund" :currency="fund.currency" />
        </div>
    </div>
    <div v-if="initialized && hasExistingAllocations" id="fund_allocations">
        <div class="page-section">
            <h3>{{ $__("Fund allocations") }}</h3>
            <KohaTable
                ref="allocationTable"
                v-bind="allocationTableOptions"
            ></KohaTable>
        </div>
    </div>
    <div v-if="initialized && hasSubFunds" id="fund_allocations">
        <div class="page-section">
            <h3>{{ $__("Sub funds") }}</h3>
            <KohaTable
                ref="subFundTable"
                v-bind="subFundTableOptions"
            ></KohaTable>
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarButton from "../../ToolbarButton.vue"
import ToolbarLink from "../../ToolbarLink.vue"
import { inject, ref } from "vue"
import { APIClient } from "../../../fetch/api-client.js"
import DisplayDataFields from "../../DisplayDataFields.vue"
import KohaTable from "../../KohaTable.vue"
import AccountingView from "./AccountingView.vue"

export default {
    setup() {
        const { setConfirmationDialog, setMessage, setWarning } =
            inject("mainStore")

        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore

        const allocationTable = ref()
        const subFundTable = ref()

        return {
            setConfirmationDialog,
            setMessage,
            setWarning,
            isUserPermitted,
            formatValueWithCurrency,
            allocationTable,
            subFundTable,
        }
    },
    data() {
        return {
            fund: {},
            initialized: false,
            hasSubFunds: false,
            allocationTableOptions: {
                columns: this.getAllocationTableColumns(),
                url: this.tableUrl("allocations"),
                table_settings: null,
                add_filters: true,
                actions: {
                    0: ["show"],
                },
            },
            subFundTableOptions: {
                columns: this.getSubFundTableColumns(),
                url: this.tableUrl("subFunds"),
                table_settings: null,
                add_filters: true,
                actions: {
                    0: ["show"],
                },
            },
            hasExistingAllocations: false,
            isSubFund: false,
            navParam: "fund_id",
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.fund = vm.getFund(to.params)
        })
    },
    methods: {
        async getFund(params) {
            const client = APIClient.acquisition
            const { fund_id, sub_fund_id } = params

            const whichParam = sub_fund_id ? "sub_fund_id" : "fund_id"
            const whichClient = sub_fund_id ? "subFunds" : "funds"

            let embed = "fiscal_period,ledger,fund_allocations,lib_group_limits"
            if (sub_fund_id) {
                embed += ",fund"
            }
            if (fund_id) {
                embed += ",fund_group,sub_funds.fund_allocations"
            }
            await client[whichClient]
                .get(params[whichParam], { "x-koha-embed": embed })
                .then(
                    fund => {
                        this.fund = fund
                        if (fund.sub_fund_id) {
                            this.isSubFund = true
                            this.navParam = "sub_fund_id"
                        }
                        if (fund.fund_allocations.length > 0) {
                            this.hasExistingAllocations = true
                        }
                        if (fund.sub_funds && fund.sub_funds.length > 0) {
                            this.hasSubFunds = true
                        }
                        this.initialized = true
                    },
                    error => {}
                )
        },
        deleteFund: function (fund_id, fund_code) {
            this.setConfirmationDialog(
                {
                    title: this.$__(
                        "Are you sure you want to remove this fund?"
                    ),
                    message: fund_code,
                    accept_label: this.$__("Yes, delete"),
                    cancel_label: this.$__("No, do not delete"),
                },
                () => {
                    const client = APIClient.acquisition
                    client.funds.delete(fund_id).then(
                        success => {
                            this.setMessage(this.$__("Fund deleted"))
                            this.$router.push({ name: "FundList" })
                        },
                        error => {}
                    )
                }
            )
        },
        getAllocationTableColumns: function () {
            const formatValueWithCurrency = this.formatValueWithCurrency
            return [
                {
                    title: __("Date"),
                    data: "last_updated",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return row.last_updated.substring(0, 10)
                    },
                },
                {
                    title: __("Amount"),
                    data: "allocation_amount",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        const symbol = row.allocation_amount >= 0 ? "+" : ""
                        const colour =
                            row.allocation_amount >= 0 ? "green" : "red"
                        return (
                            '<span style="color:' +
                            colour +
                            ';">' +
                            symbol +
                            row.allocation_amount +
                            "</span>"
                        )
                    },
                },
                {
                    title: __("New fund total"),
                    data: "new_fund_value",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return formatValueWithCurrency(
                            row.currency,
                            row.new_fund_value
                        )
                    },
                },
                {
                    title: __("Reference"),
                    data: "reference",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: __("Note"),
                    data: "note",
                    searchable: true,
                    orderable: true,
                },
            ]
        },
        getSubFundTableColumns: function () {
            const formatValueWithCurrency = this.formatValueWithCurrency
            return [
                {
                    title: __("Name"),
                    data: "name:sub_fund_id",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a href="/acquisitions/fund_management/fund/sub_fund/' +
                            row.sub_fund_id +
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
                    data: "sub_fund_value",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return formatValueWithCurrency(
                            row.currency,
                            row.sub_fund_value
                        )
                    },
                },
            ]
        },
        showTransferWarning() {
            this.setWarning(
                this.$__(
                    "This allocation was a transfer between funds and can't be edited or deleted."
                )
            )
        },
        tableUrl(dataType) {
            const id = this.$route.params.sub_fund_id
                ? this.$route.params.sub_fund_id
                : this.$route.params.fund_id
            let url =
                dataType === "allocations"
                    ? "/api/v1/acquisitions/fund_allocations?q="
                    : "/api/v1/acquisitions/sub_funds?q="
            const query = {
                [this.$route.params.sub_fund_id ? "sub_fund_id" : "fund_id"]:
                    id,
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
.action_links a {
    padding-left: 0.2em;
    font-size: 11px;
    cursor: pointer;
}
#fund_allocations {
    margin-top: 2em;
}
.fund_display {
    display: flex;
    gap: 1em;
}
</style>
