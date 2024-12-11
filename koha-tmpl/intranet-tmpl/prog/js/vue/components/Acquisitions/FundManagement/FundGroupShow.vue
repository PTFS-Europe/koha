<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fund_groups_show">
        <Toolbar>
            <ToolbarLink
                :to="{ name: 'FundGroupList' }"
                icon="xmark"
                title="Close"
            />
            <ToolbarLink
                :to="{
                    name: 'FundGroupFormEdit',
                    params: { fund_group_id: fundGroup.fund_group_id },
                }"
                icon="pencil"
                title="Edit"
                v-if="isUserPermitted('editFundGroup')"
            />
            <ToolbarButton
                icon="trash"
                title="Delete"
                @clicked="deleteFund(fundGroup.fund_group_id, fundGroup.name)"
                v-if="isUserPermitted('deleteFundGroup')"
            />
        </Toolbar>
        <h2>{{ fundGroup.name }}</h2>
        <div class="fund_group_display">
            <DisplayDataFields
                :data="fundGroup"
                homeRoute="FundGroupList"
                dataType="fundGroup"
                :showClose="false"
            />
            <AccountingView :data="fundGroup" :currency="fundGroup.currency" />
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

        const table = ref()

        return {
            setConfirmationDialog,
            setMessage,
            setWarning,
            isUserPermitted,
            formatValueWithCurrency,
            table,
        }
    },
    data() {
        return {
            fundGroup: {},
            initialized: false,
            tableOptions: {
                columns: this.getTableColumns(),
                url: this.tableUrl(),
                table_settings: null,
                add_filters: true,
                actions: {
                    0: ["show"],
                },
            },
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.fund = vm.getFundGroup(to.params.fund_group_id)
        })
    },
    methods: {
        async getFundGroup(fund_group_id) {
            const client = APIClient.acquisition
            await client.fundGroups
                .get(fund_group_id, {
                    "x-koha-embed": "funds.fund_allocations,lib_group_limits",
                })
                .then(
                    fundGroup => {
                        this.fundGroup = fundGroup
                        this.initialized = true
                    },
                    error => {}
                )
        },
        deleteFund: function (fund_group_id, fund_code) {
            this.setConfirmationDialog(
                {
                    title: this.$__(
                        "Are you sure you want to remove this fund group?"
                    ),
                    message: fund_code,
                    accept_label: this.$__("Yes, delete"),
                    cancel_label: this.$__("No, do not delete"),
                },
                () => {
                    const client = APIClient.acquisition
                    client.funds.delete(fund_group_id).then(
                        success => {
                            this.setMessage(this.$__("Fund group deleted"))
                            this.$router.push({ name: "FundGroupList" })
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
                        return row.status ? __("Active") : __("Inactive")
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
        tableUrl() {
            const id = this.$route.params.fund_group_id
            let url = "/api/v1/acquisitions/funds?q="
            const query = {
                fund_group_id: id,
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
#funds {
    margin-top: 2em;
}
.fund_group_display {
    display: flex;
    gap: 1em;
}
</style>
