<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fund_allocation_add">
        <h2 v-if="fund_allocation.fund_allocation_id">
            {{
                $__("Edit fund allocation %s").format(
                    fund_allocation.fund_allocation_id
                )
            }}
        </h2>
        <h2 v-else>{{ $__("New fund allocation") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <h3>{{ $__("Allocate to fund") }}: {{ selectedFund.name }}</h3>
                <fieldset class="rows">
                    <ol>
                        <!-- <li>
                            <label for="fund_allocation_fund_id" class="required"
                                >Fund:</label
                            >
                            <InfiniteScrollSelect
                                id="fund_allocation_fund_id"
                                v-model="fund_allocation[isSubFund ? 'sub_fund_id' : 'fund_id']"
                                :selectedData="selectedFund"
                                :dataType="isSubFund ? 'sub_funds' : 'funds'"
                                :dataIdentifier="isSubFund ? 'sub_fund_id' : 'fund_id'"
                                label="name"
                                apiClient="acquisition"
                                :required="true"
                            />
                            <span class="required">Required</span>
                        </li> -->
                        <li>
                            <label for="fund_allocation_amount" class="required"
                                >{{ $__("Allocation amount") }}:</label
                            >
                            <input
                                id="fund_allocation_amount"
                                v-model="fund_allocation.allocation_amount"
                                type="number"
                                step=".01"
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_allocation_reference"
                                >{{ $__("Reference") }}:</label
                            >
                            <input
                                id="fund_allocation_reference"
                                v-model="fund_allocation.reference"
                                placeholder="Fund allocation reference"
                            />
                        </li>
                        <li>
                            <label for="fund_allocation_note"
                                >{{ $__("Note") }}:
                            </label>
                            <textarea
                                id="fund_allocation_note"
                                v-model="fund_allocation.note"
                                placeholder="Notes"
                                rows="10"
                                cols="50"
                            />
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="action">
                    <input type="submit" value="Submit" />
                    <router-link
                        :to="{
                            name: 'FundShow',
                            params: { fund_id: selectedFund.fund_id },
                        }"
                        role="button"
                        class="cancel"
                        >{{ $__("Cancel") }}</router-link
                    >
                </fieldset>
            </form>
        </div>
    </div>
</template>

<script>
import { inject } from "vue"
import { APIClient } from "../../../fetch/api-client.js"
import { setMessage, setWarning } from "../../../messages"
import InfiniteScrollSelect from "../../InfiniteScrollSelect.vue"

export default {
    setup() {
        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted } = acquisitionsStore

        return {
            isUserPermitted,
        }
    },
    data() {
        return {
            initialized: false,
            fund_allocation: {
                fund_id: null,
                sub_fund_id: null,
                fiscal_period_id: null,
                ledger_id: null,
                reference: "",
                note: "",
                currency: "",
                allocation_amount: null,
                lib_group_visibility: "",
            },
            funds: [],
            selectedFund: null,
            isSubFund: false,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getDataRequiredForPageLoad(to)
        })
    },
    methods: {
        async getDataRequiredForPageLoad(route) {
            const { params } = route
            this.getFund(params).then(() => {
                if (params.fund_allocation_id) {
                    this.getFundAllocation(params.fund_allocation_id)
                }
                this.initialized = true
            })
        },
        async getFundAllocation(fund_allocation_id) {
            const client = APIClient.acquisition
            await client.fundAllocations
                .get(fund_allocation_id)
                .then(fund_allocation => {
                    this.fund_allocation = fund_allocation
                })
        },
        async getFund(params) {
            const { fund_id, sub_fund_id } = params
            const whichClient = sub_fund_id ? "subFunds" : "funds"
            const whichParam = sub_fund_id ? "sub_fund_id" : "fund_id"
            if (sub_fund_id) this.isSubFund = true

            const client = APIClient.acquisition
            await client[whichClient].get(params[whichParam]).then(
                result => {
                    this.selectedFund = result
                    this.fund_allocation[whichParam] = result[whichParam]
                    this.fund_allocation.ledger_id = result.ledger_id
                    this.fund_allocation.fiscal_period_id =
                        result.fiscal_period_id
                    this.fund_allocation.currency = result.currency
                    this.fund_allocation.owner_id = result.owner_id
                    this.fund_allocation.lib_group_visibility =
                        result.lib_group_visibility
                },
                error => {}
            )
        },
        onSubmit(e) {
            e.preventDefault()

            if (!this.isUserPermitted("createFundAllocation")) {
                setWarning(
                    this.$__(
                        "You do not have the required permissions to create fund allocations."
                    )
                )
                return
            }

            const fund_allocation = JSON.parse(
                JSON.stringify(this.fund_allocation)
            )
            const fund_allocation_id = fund_allocation.fund_allocation_id

            delete fund_allocation.fund_allocation_id

            if (fund_allocation_id) {
                const acq_client = APIClient.acquisition
                acq_client.fundAllocations
                    .update(fund_allocation, fund_allocation_id)
                    .then(
                        success => {
                            setMessage(this.$__("Fund allocation updated"))
                            this.$router.push({
                                name: "FundShow",
                                params: { fund_id: this.selectedFund.fund_id },
                            })
                        },
                        error => {}
                    )
            } else {
                const acq_client = APIClient.acquisition
                acq_client.fundAllocations.create(fund_allocation).then(
                    success => {
                        setMessage(this.$__("Fund allocation created"))
                        this.$router.push({
                            name: "FundShow",
                            params: { fund_id: this.selectedFund.fund_id },
                        })
                    },
                    error => {}
                )
            }
        },
    },
    components: {
        InfiniteScrollSelect,
    },
}
</script>

<style scoped>
fieldset.rows label {
    width: 15em;
}
</style>
