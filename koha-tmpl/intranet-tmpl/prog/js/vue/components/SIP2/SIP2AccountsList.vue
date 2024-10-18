<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="sip2_accounts_list">
        <Toolbar>
            <ToolbarButton
                action="add"
                @go-to-add-resource="goToResourceAdd"
                :title="$__('New account')"
            />
        </Toolbar>
        <div v-if="accounts_count > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @show="goToResourceShow"
                @edit="goToResourceEdit"
                @delete="doResourceDelete"
            ></KohaTable>
        </div>
        <div v-else class="alert alert-info">
            {{ $__("There are no accounts defined") }}
        </div>
    </div>
</template>

<script>
import Toolbar from "../Toolbar.vue"
import ToolbarButton from "../ToolbarButton.vue"
import { APIClient } from "../../fetch/api-client.js"
import { ref } from "vue"
import KohaTable from "../KohaTable.vue"
import SIP2AccountResource from "./SIP2AccountResource.vue"

export default {
    extends: SIP2AccountResource,
    setup() {
        const table = ref()

        return {
            ...SIP2AccountResource.setup(),
            table,
            accounts_table_settings,
        }
    },
    data: function () {
        return {
            initialized: false,
            tableOptions: {
                columns: this.getTableColumns(),
                url: () => this.table_url(),
                options: { embed: "institution" },
                table_settings: this.accounts_table_settings,
                actions: {
                    0: ["show"],
                    "-1": this.embedded
                        ? [
                              {
                                  select: {
                                      text: this.$__("Select"),
                                      icon: "fa fa-check",
                                  },
                              },
                          ]
                        : ["edit", "delete"],
                },
            },
            before_route_entered: false,
            building_table: false,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getAccountsCount().then(() => (vm.initialized = true))
        })
    },
    methods: {
        async getAccountsCount() {
            const client = APIClient.sip2
            await client.accounts.count().then(
                count => {
                    this.accounts_count = count
                },
                error => {}
            )
        },
        getTableColumns: function () {
            return [
                {
                    title: __("Login"),
                    data: "login_id:sip_account_id",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a role="button" class="show">' +
                            escape_str(
                                `${row.login_id} (#${row.sip_account_id})`
                            ) +
                            "</a>"
                        )
                    },
                },
                {
                    title: __("Institution ID"),
                    data: "sip_institution_id",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return row.sip_institution_id != undefined
                            ? '<a href="/cgi-bin/koha/sip2/institutions/' +
                                  row.sip_institution_id +
                                  '">' +
                                  escape_str(row.institution.name) +
                                  "</a>"
                            : ""
                    },
                },
                {
                    title: __("Delimiter"),
                    data: "delimiter",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: __("Encoding"),
                    data: "encoding",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: __("Error detect"),
                    data: "error_detect",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return escape_str(
                            row.error_detect ? __("Yes") : __("No")
                        )
                    },
                },
                {
                    title: __("Terminator"),
                    data: "terminator",
                    searchable: true,
                    orderable: true,
                },
            ]
        },
        table_url: function () {
            return "/api/v1/sip2/accounts"
        },
    },
    components: { Toolbar, ToolbarButton, KohaTable },
    name: "SIP2AccountsList",
}
</script>
