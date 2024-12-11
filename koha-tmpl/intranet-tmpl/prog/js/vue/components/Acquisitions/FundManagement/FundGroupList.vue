<template>
    <div v-if="!initialized">Loading...</div>
    <div v-else id="fund_group_list">
        <Toolbar>
            <ToolbarLink
                :to="{ name: 'FundGroupFormAdd' }"
                icon="plus"
                title="New fund group"
                v-if="isUserPermitted('createFundGroup')"
            />
        </Toolbar>
        <div v-if="fundGroupCount > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @show="doShow"
                @edit="doEdit"
                @delete="doDelete"
            ></KohaTable>
        </div>
        <div v-else class="dialog message">
            There are no fund groups defined
        </div>
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
        if (this.isUserPermitted("editFundGroup")) {
            actionButtons.push("edit")
        }
        if (this.isUserPermitted("deleteFundGroup")) {
            actionButtons.push("delete")
        }
        return {
            fundGroupCount: 0,
            initialized: false,
            tableOptions: {
                columns: this.getTableColumns(),
                url: "/api/v1/acquisitions/fund_groups",
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
            vm.getFundGroupCount().then(() => (vm.initialized = true))
        })
    },
    methods: {
        async getFundGroupCount() {
            const client = APIClient.acquisition
            await client.fundGroups.count().then(
                count => {
                    this.fundGroupCount = count
                },
                error => {}
            )
        },
        doShow: function ({ fund_group_id }, dt, event) {
            event.preventDefault()
            this.$router.push({
                name: "FundGroupShow",
                params: { fund_group_id },
            })
        },
        doEdit: function ({ fund_group_id }, dt, event) {
            this.$router.push({
                name: "FundGroupFormEdit",
                params: { fund_group_id },
            })
        },
        doDelete: function (fundGroup, dt, event) {
            this.setConfirmationDialog(
                {
                    title: "Are you sure you want to remove this fund group?",
                    message: fundGroup.name,
                    accept_label: "Yes, delete",
                    cancel_label: "No, do not delete",
                },
                () => {
                    const client = APIClient.acquisition
                    client.fundGroups.delete(fundGroup.fund_group_id).then(
                        success => {
                            this.setMessage(`Fund group deleted`, true)
                            dt.draw()
                        },
                        error => {}
                    )
                }
            )
        },
        getTableColumns: function () {
            return [
                {
                    title: __("Name"),
                    data: "name:fund_group_id",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a href="/acquisitions/fund_management/fund_group/' +
                            row.fund_group_id +
                            '" class="show">' +
                            escape_str(`${row.name}`) +
                            "</a>"
                        )
                    },
                },
                {
                    title: __("Currency"),
                    data: "currency",
                    searchable: true,
                    orderable: true,
                },
            ]
        },
    },
    components: { Toolbar, ToolbarLink, KohaTable },
}
</script>
