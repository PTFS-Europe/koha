<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fund_add">
        <h2 v-if="fund.fund_id">
            {{ $__("Edit fund %s").format(fund.fund_id) }}
        </h2>
        <h2 v-else>{{ $__("New fund") }}</h2>
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
                                v-model="fund.name"
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
                                v-model="fund.description"
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
                                v-model="fund.code"
                                placeholder="Fund code"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_fiscal_period_id" class="required"
                                >{{ $__("Fiscal period") }}:</label
                            >
                            <InfiniteScrollSelect
                                id="fund_fiscal_period_id"
                                v-model="fund.fiscal_period_id"
                                :selectedData="fund"
                                dataType="fiscalPeriods"
                                dataIdentifier="fiscal_period_id"
                                label="code"
                                apiClient="acquisition"
                                :required="true"
                                @update:modelValue="
                                    filterLedgersBySelectedFiscalPeriod($event)
                                "
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_ledger_id" class="required"
                                >{{ $__("Ledger") }}:</label
                            >
                            <v-select
                                id="fund_ledger_id"
                                v-model="fund.ledger_id"
                                :reduce="av => av.ledger_id"
                                :options="ledgers"
                                label="name"
                                @update:modelValue="
                                    filterLibGroupsAndFundGroupsBySelectedLedger(
                                        $event
                                    )
                                "
                                :disabled="ledgers.length === 0"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!fund.ledger_id"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_fund_group_id"
                                >{{ $__("Fund group") }}:</label
                            >
                            <v-select
                                id="fund_fund_group"
                                v-model="fund.fund_group_id"
                                :reduce="av => av.fund_group_id"
                                :options="fundGroupOptions"
                                label="name"
                                :disabled="fundGroupOptions.length === 0"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                        </li>
                        <li>
                            <label for="fund_fund_type"
                                >{{ $__("Fund type") }}:</label
                            >
                            <v-select
                                id="fund_fund_type"
                                v-model="fund.fund_type"
                                :reduce="av => av.value"
                                :options="acquire_fund_types"
                                label="description"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                        </li>
                        <li>
                            <label for="fund_status" class="required"
                                >{{ $__("Status") }}:</label
                            >
                            <v-select
                                id="fund_status"
                                v-model="fund.status"
                                :reduce="av => av.value"
                                :options="statusOptions"
                                label="description"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !statusOptions
                                                .map(opt => opt.value)
                                                .includes(fund.status)
                                        "
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fund_external_id"
                                >{{ $__("External ID") }}:</label
                            >
                            <input
                                id="fund_external_id"
                                v-model="fund.external_id"
                                placeholder="External id for use with third party accounting software"
                            />
                        </li>
                        <li>
                            <label
                                for="fund_lib_group_visibility"
                                class="required"
                                >{{ $__("Visible to") }}:</label
                            >
                            <v-select
                                id="fund_lib_group_visibility"
                                v-model="fund.lib_group_visibility"
                                :reduce="av => av.id"
                                :options="getVisibleGroups"
                                label="title"
                                @update:modelValue="
                                    filterOwnersBasedOnGroup(
                                        $event,
                                        fund,
                                        ledgerGroups
                                    )
                                "
                                multiple
                                :disabled="ledgerGroups.length === 0"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!fund.lib_group_visibility"
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
                { description: this.$__("Active"), value: true },
                { description: this.$__("Inactive"), value: false },
            ],
            allowedOptions: [
                { description: this.$__("Allowed"), value: true },
                { description: this.$__("Not allowed"), value: false },
            ],
            fund: {
                fiscal_period_id: null,
                ledger_id: null,
                name: "",
                description: "",
                code: "",
                external_id: "",
                status: null,
                fund_type: "",
                fund_group_id: null,
                lib_group_visibility: [],
            },
            fiscalPeriod: null,
            ledgers: [],
            ledgerGroups: [],
            fundGroupOptions: [],
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getDataRequiredForPageLoad(to.params.fund_id)
        })
    },
    methods: {
        async getDataRequiredForPageLoad(fund_id) {
            this.getFundGroups().then(() => {
                if (fund_id) {
                    this.getFund(fund_id).then(() => {
                        this.getFiscalPeriod(this.fund.fiscal_period_id)
                    })
                } else {
                    this.initialized = true
                }
            })
        },
        async getFund(fund_id) {
            const client = APIClient.acquisition
            await client.funds.get(fund_id).then(fund => {
                this.fund = fund
                this.fund.lib_group_visibility = this.formatLibraryGroupIds(
                    fund.lib_group_visibility
                )
                this.filterLedgersBySelectedFiscalPeriod(fund.fiscal_period_id)
            })
        },
        async getFundGroups() {
            const client = APIClient.acquisition
            await client.fundGroups.getAll().then(fundGroups => {
                this.fundGroups = fundGroups
            })
        },
        async getFiscalPeriod(fiscal_period_id) {
            const client = APIClient.acquisition
            await client.fiscalPeriods
                .get(fiscal_period_id, { "x-koha-embed": "ledgers" })
                .then(
                    fiscalPeriod => {
                        this.fiscalPeriod = fiscalPeriod
                        this.filterLibGroupsAndFundGroupsBySelectedLedger(
                            this.fund.ledger_id
                        )
                        this.initialized = true
                    },
                    error => {}
                )
        },
        filterLedgersBySelectedFiscalPeriod(e) {
            if (!e) {
                this.ledgers = []
                this.fund.ledger_id = null
                this.fund.lib_group_visibility = []
                return
            }

            this.getFiscalPeriod(e).then(() => {
                const { ledgers: ledgers } = this.fiscalPeriod
                if (!ledgers || ledgers.length === 0) {
                    setWarning(
                        this.$__(
                            "There are no ledgers attached to this fiscal period. Please create one or select a different fiscal period."
                        )
                    )
                    this.ledger.fiscal_period_id = null
                    return
                }
                this.ledgers = ledgers
            })
            if (e !== this.fund.fiscal_period_id) {
                this.fund.ledger_id = null
                this.fund.lib_group_visibility = []
            }
        },
        filterLibGroupsAndFundGroupsBySelectedLedger(e) {
            const selectedLedger = this.fiscalPeriod.ledgers.find(
                ledger => ledger.ledger_id === e
            )
            if (selectedLedger) {
                const applicableGroups = this.formatLibraryGroupIds(
                    selectedLedger.lib_group_visibility
                )
                this.ledgerGroups = applicableGroups
                this.resetOwnersAndVisibleGroups(applicableGroups)

                const fundGroupsWithMatchingCurrencyAndVisibility =
                    this.fundGroups
                        .filter(
                            group => group.currency === selectedLedger.currency
                        )
                        .map(group => {
                            const groupVisibility = this.formatLibraryGroupIds(
                                group.lib_group_visibility
                            )
                            const matchFound = groupVisibility.some(item =>
                                applicableGroups.includes(item)
                            )
                            if (matchFound) {
                                return group
                            } else {
                                return null
                            }
                        })
                        .filter(group => group !== null)
                this.fundGroupOptions =
                    fundGroupsWithMatchingCurrencyAndVisibility
            }
        },
        onSubmit(e) {
            e.preventDefault()

            if (!this.isUserPermitted("createFund")) {
                setWarning(
                    this.$__(
                        "You do not have the required permissions to create funds."
                    )
                )
                return
            }

            const fund = JSON.parse(JSON.stringify(this.fund))
            const fund_id = fund.fund_id

            const visibility = fund.lib_group_visibility.join("|")
            fund.lib_group_visibility = visibility || null

            delete fund.fund_id

            if (fund_id) {
                const acq_client = APIClient.acquisition
                acq_client.funds.update(fund, fund_id).then(
                    success => {
                        setMessage(this.$__("Fund updated"))
                        this.$router.push({ name: "FundList" })
                    },
                    error => {}
                )
            } else {
                const acq_client = APIClient.acquisition
                acq_client.funds.create(fund).then(
                    success => {
                        setMessage(this.$__("Fund created"))
                        this.$router.push({ name: "FundList" })
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
