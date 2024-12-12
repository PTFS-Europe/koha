<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fund_list">
        <Toolbar v-if="!embedded">
            <ToolbarButton
                action="add"
                @go-to-add-resource="goToResourceAdd"
                :title="$__('New fund')"
            />
        </Toolbar>
        <div v-if="fund_count > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @edit="goToResourceEdit"
                @delete="doResourceDelete"
            ></KohaTable>
        </div>
        <div v-else class="dialog message">
            {{ $__("There are no funds defined") }}
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarLink from "../../ToolbarLink.vue"
import { inject, ref } from "vue"
import { APIClient } from "../../../fetch/api-client.js"
import KohaTable from "../../KohaTable.vue"
import FundResource from "./FundResource.vue"
import ToolbarButton from "../../ToolbarButton.vue"

export default {
    extends: FundResource,
    props: {
        embedded: {
            type: Boolean,
            default: false,
        },
    },
    setup() {
        const { setConfirmationDialog, setMessage } = inject("mainStore")
        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore

        const table = ref()

        return {
            ...FundResource.setup(),
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
                url: this.tableUrl(),
                options: { embed: "fund_allocations" },
                table_settings: null,
                add_filters: true,
                ...(!this.embedded && {
                    actions: {
                        0: ["show"],
                        "-1": actionButtons,
                    },
                }),
            },
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getFundCount().then(() => (vm.initialized = true))
        })
    },
    mounted() {
        if (this.embedded) {
            this.getFundCount().then(() => (this.initialized = true))
        }
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
                            '<a href="/cgi-bin/koha/fund_management/fund/' +
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
            if (this.embedded) {
                const id = this.$route.params.ledger_id
                const query = {
                    "me.ledger_id": id,
                }
                return "/api/v1/acquisitions/funds?q=" + JSON.stringify(query)
            }
            return "/api/v1/acquisitions/funds"
        },
    },
    components: { Toolbar, ToolbarLink, KohaTable, ToolbarButton },
}
</script>
