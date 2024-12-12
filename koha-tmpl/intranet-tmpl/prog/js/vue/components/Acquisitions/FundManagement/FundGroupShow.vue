<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fund_groups_show">
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
    <FundList v-if="initialized" :embedded="true" />
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
import FundGroupResource from "./FundGroupResource.vue"
import FundList from "./FundList.vue"

export default {
    extends: FundGroupResource,
    setup() {
        const { setConfirmationDialog, setMessage, setWarning } =
            inject("mainStore")

        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted, formatValueWithCurrency } = acquisitionsStore

        const table = ref()

        return {
            ...FundGroupResource.setup(),
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
