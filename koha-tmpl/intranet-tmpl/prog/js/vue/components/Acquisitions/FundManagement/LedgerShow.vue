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
    <FundList v-if="initialized" :embedded="true" />
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
import FundList from "./FundList.vue"

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
    },
    components: {
        DisplayDataFields,
        Toolbar,
        ToolbarButton,
        ToolbarLink,
        KohaTable,
        AccountingView,
        FundList,
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
