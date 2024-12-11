<template>
    <div v-if="!initialized">Loading...</div>
    <div v-else id="fund_transfer_add">
        <h2>Transfer between funds</h2>
        <div>
            <form @submit="onSubmit($event)">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label for="fund_transfer_fund_id" class="required"
                                >Fund to transfer to:</label
                            >
                            <InfiniteScrollSelect
                                id="fund_transfer_fund_id"
                                v-model="fund_transfer.fund_id_to"
                                dataType="funds"
                                dataIdentifier="fund_id"
                                label="name"
                                apiClient="acquisition"
                                :required="!fund_transfer.fund_id_to"
                                :filters="{
                                    fund_id: { '!=': $route.query.fund_id },
                                    status: '1',
                                }"
                                @update:modelValue="handleSubFunds"
                            />
                            <span class="required">Required</span>
                        </li>
                        <li>
                            <label
                                for="fund_transfer_sub_fund"
                                :class="noSubFunds ? '' : 'required'"
                                >Sub fund:</label
                            >
                            <v-select
                                id="fund_transfer_sub_fund"
                                v-model="fund_transfer.sub_fund_id_to"
                                :reduce="av => av.sub_fund_id"
                                :options="subFunds"
                                label="name"
                                :disabled="noSubFunds"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !noSubFunds
                                                ? false
                                                : !fund_transfer.sub_fund_it_to
                                        "
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span v-if="!noSubFunds" class="required"
                                >Required</span
                            >
                        </li>
                        <li>
                            <label for="fund_transfer_amount" class="required"
                                >Allocation amount:</label
                            >
                            <input
                                id="fund_transfer_amount"
                                v-model="fund_transfer.transfer_amount"
                                type="number"
                                step=".01"
                            />
                            <span class="required">Required</span>
                        </li>
                        <li>
                            <label for="fund_transfer_reference"
                                >Reference:</label
                            >
                            <input
                                id="fund_transfer_reference"
                                v-model="fund_transfer.reference"
                                placeholder="Fund transfer reference"
                            />
                        </li>
                        <li>
                            <label for="fund_transfer_note">Note: </label>
                            <textarea
                                id="fund_transfer_note"
                                v-model="fund_transfer.note"
                                placeholder="Notes"
                                rows="10"
                                cols="50"
                            />
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="action">
                    <input
                        type="submit"
                        value="Submit"
                        :disabled="stopSubmit"
                    />
                    <router-link
                        :to="{
                            name: 'FundShow',
                            params: { fund_id: $route.query.fund_id },
                        }"
                        role="button"
                        class="cancel"
                        >Cancel</router-link
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
        const { sub_fund_id, fund_id } = this.$route.query
        const fund_transfer = {
            fund_id_from: null,
            sub_fund_id_from: null,
            fund_id_to: null,
            sub_fund_id_to: null,
            reference: "",
            note: "",
            transfer_amount: null,
        }
        if (sub_fund_id) fund_transfer.sub_fund_id_from = parseInt(sub_fund_id)
        if (fund_id && !sub_fund_id)
            fund_transfer.fund_id_from = parseInt(fund_id)

        return {
            initialized: true,
            fund_transfer,
            subFunds: [],
            noSubFunds: true,
            stopSubmit: false,
        }
    },
    methods: {
        async getFund(fund_id) {
            const client = APIClient.acquisition
            await client.funds
                .get(fund_id, { "x-koha-embed": "sub_funds" })
                .then(
                    fund => {
                        this.selectedFund = fund
                        if (fund.sub_funds && fund.sub_funds.length > 0) {
                            this.noSubFunds = false
                            this.subFunds = fund.sub_funds
                        }
                    },
                    error => {}
                )
        },
        async handleSubFunds() {
            this.stopSubmit = true
            await this.getFund(this.fund_transfer.fund_id_to)

            if (
                this.selectedFund.sub_funds &&
                this.selectedFund.sub_funds.length > 0
            ) {
                this.noSubFunds = false
            }
            this.stopSubmit = false
        },
        onSubmit(e) {
            e.preventDefault()

            if (!this.isUserPermitted("createFundAllocation")) {
                setWarning(
                    "You do not have the required permissions to transfer funds."
                )
                return
            }

            const fund_transfer = JSON.parse(JSON.stringify(this.fund_transfer))

            const acq_client = APIClient.acquisition
            acq_client.fundAllocations.transfer(fund_transfer).then(
                success => {
                    setMessage("Funds successfully transferred")
                    this.$router.push({
                        name: "FundShow",
                        params: { fund_id: this.$route.query.fund_id },
                    })
                },
                error => {}
            )
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
