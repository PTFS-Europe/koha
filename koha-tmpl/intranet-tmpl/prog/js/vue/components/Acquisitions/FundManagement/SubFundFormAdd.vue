<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="sub_fund_add">
        <h2 v-if="sub_fund.sub_fund_id">
            {{ $__("Edit sub fund %s").format(sub_fund.sub_fund_id) }}
        </h2>
        <h2 v-else>{{ $__("New sub fund") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label class="required" for="fund_name"
                                >{{ $__("Name") }}:</label
                            >
                            <input
                                id="fund_name"
                                v-model="sub_fund.name"
                                placeholder="Fund name"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_description"
                                >{{ $__("Description") }}:
                            </label>
                            <textarea
                                id="fund_description"
                                v-model="sub_fund.description"
                                placeholder="Description"
                                rows="10"
                                cols="50"
                            />
                        </li>
                        <li>
                            <label class="required" for="fund_code"
                                >{{ $__("Code") }}:</label
                            >
                            <input
                                id="fund_code"
                                v-model="sub_fund.code"
                                placeholder="Fund code"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_external_id"
                                >{{ $__("External ID") }}:</label
                            >
                            <input
                                id="fund_external_id"
                                v-model="sub_fund.external_id"
                                placeholder="External id for use with third party accounting software"
                            />
                        </li>
                        <li>
                            <label for="fund_status" class="required"
                                >{{ $__("Status") }}:</label
                            >
                            <v-select
                                id="fund_status"
                                v-model="sub_fund.status"
                                :reduce="av => av.value"
                                :options="statusOptions"
                                label="description"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !statusOptions
                                                .map(opt => opt.value)
                                                .includes(sub_fund.status)
                                        "
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="action">
                    <input type="submit" value="Submit" />
                    <router-link
                        :to="{ name: 'FundList' }"
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
import { storeToRefs } from "pinia"
import { APIClient } from "../../../fetch/api-client.js"
import { setMessage, setWarning } from "../../../messages"
import InfiniteScrollSelect from "../../InfiniteScrollSelect.vue"

export default {
    setup() {
        const acquisitionsStore = inject("acquisitionsStore")
        const { libraryGroups, getVisibleGroups, getOwners } =
            storeToRefs(acquisitionsStore)

        const {
            isUserPermitted,
            filterGroupsBasedOnOwner,
            filterOwnersBasedOnGroup,
            resetOwnersAndVisibleGroups,
            formatLibraryGroupIds,
        } = acquisitionsStore

        const AVStore = inject("AVStore")
        const { acquire_fund_types } = storeToRefs(AVStore)

        return {
            isUserPermitted,
            libraryGroups,
            filterGroupsBasedOnOwner,
            filterOwnersBasedOnGroup,
            formatLibraryGroupIds,
            resetOwnersAndVisibleGroups,
            getVisibleGroups,
            getOwners,
            acquire_fund_types,
        }
    },
    data() {
        return {
            initialized: false,
            statusOptions: [
                { description: this.$__("Active"), value: 1 },
                { description: this.$__("Inactive"), value: 0 },
            ],
            sub_fund: {
                fiscal_period_id: null,
                ledger_id: null,
                fund_id: null,
                name: "",
                description: "",
                code: "",
                external_id: "",
                status: null,
                sub_fund_type: "",
                lib_group_visibility: [],
            },
            fund: null,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getDataRequiredForPageLoad(to.params)
        })
    },
    methods: {
        async getDataRequiredForPageLoad(params) {
            this.getFund(params.fund_id).then(() => {
                if (params.sub_fund_id) {
                    this.getSubFund(params.sub_fund_id)
                } else {
                    this.initialized = true
                }
            })
        },
        async getFund(fund_id) {
            const client = APIClient.acquisition
            await client.funds.get(fund_id).then(fund => {
                this.fund = fund
                this.sub_fund.fund_id = fund.fund_id
                this.sub_fund.ledger_id = fund.ledger_id
                this.sub_fund.fiscal_period_id = fund.fiscal_period_id
                this.sub_fund.sub_fund_type = fund.fund_type
                this.sub_fund.currency = fund.currency
                this.sub_fund.owner_id = fund.owner_id
                this.sub_fund.lib_group_visibility = fund.lib_group_visibility
            })
        },
        async getSubFund(sub_fund_id) {
            const client = APIClient.acquisition
            await client.subFunds.get(sub_fund_id).then(sub_fund => {
                this.sub_fund = sub_fund
                this.sub_fund.status = sub_fund.status
                this.initialized = true
            })
        },
        onSubmit(e) {
            e.preventDefault()

            if (!this.isUserPermitted("createFund")) {
                setWarning(
                    this.$__(
                        "You do not have the required permissions to create sub funds."
                    )
                )
                return
            }

            const sub_fund = JSON.parse(JSON.stringify(this.sub_fund))
            const sub_fund_id = sub_fund.sub_fund_id

            delete sub_fund.sub_fund_id

            if (sub_fund_id) {
                const acq_client = APIClient.acquisition
                acq_client.subFunds.update(sub_fund, sub_fund_id).then(
                    success => {
                        setMessage(this.$__("Sub fund updated"))
                        this.$router.push({
                            name: "FundShow",
                            params: { fund_id: sub_fund.fund_id },
                        })
                    },
                    error => {}
                )
            } else {
                const acq_client = APIClient.acquisition
                acq_client.subFunds.create(sub_fund).then(
                    success => {
                        setMessage(this.$__("Sub fund created"))
                        this.$router.push({
                            name: "FundShow",
                            params: { fund_id: sub_fund.fund_id },
                        })
                    },
                    error => {}
                )
            }
        },
    },
    unmounted() {
        this.resetOwnersAndVisibleGroups()
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
