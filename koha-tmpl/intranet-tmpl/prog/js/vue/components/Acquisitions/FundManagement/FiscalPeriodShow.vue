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
    <LedgerList v-if="initialized" :embedded="true" />
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
import LedgerList from "./LedgerList.vue"

export default {
    extends: FiscalPeriodResource,
    setup() {
        const { setConfirmationDialog, setMessage } = inject("mainStore")

        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore

        return {
            ...FiscalPeriodResource.setup(),
            setConfirmationDialog,
            setMessage,
            isUserPermitted,
            formatValueWithCurrency,
        }
    },
    data() {
        return {
            fiscal_period: {},
            initialized: false,
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
    },
    components: {
        DisplayDataFields,
        Toolbar,
        ToolbarButton,
        ToolbarLink,
        KohaTable,
        LedgerList,
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
