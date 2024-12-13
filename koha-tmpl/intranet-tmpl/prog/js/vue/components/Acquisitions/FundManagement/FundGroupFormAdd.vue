<template>
    <div v-if="!initialized">{{ $__("Loading") }}...</div>
    <div v-else id="fund_group_add">
        <h2 v-if="fundGroup.fund_group_id">
            {{ $__("Edit fund group %s").format(fundGroup.fund_group_id) }}
        </h2>
        <h2 v-else>{{ $__("New fund group") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label class="required" for="fund_group_name"
                                >{{ $__("Name") }}:</label
                            >
                            <input
                                id="fund_group_name"
                                v-model="fundGroup.name"
                                placeholder="Fund group name"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="fundGroup_currency" class="required"
                                >{{ $__("Currency") }}:</label
                            >
                            <v-select
                                id="fundGroup_currency"
                                v-model="fundGroup.currency"
                                :reduce="av => av.currency"
                                :options="currencies"
                                label="currency"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!fundGroup.currency"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label
                                for="fund_group_lib_group_visibility"
                                class="required"
                                >{{ $__("Visible to") }}:</label
                            >
                            <v-select
                                id="fund_group_lib_group_visibility"
                                v-model="fundGroup.lib_group_visibility"
                                :reduce="av => av.id"
                                :options="getVisibleGroups"
                                label="title"
                                multiple
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !fundGroup.lib_group_visibility
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
                        :to="{ name: 'FundGroupList' }"
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
        const { getVisibleGroups } = storeToRefs(acquisitionsStore)

        const {
            isUserPermitted,
            resetOwnersAndVisibleGroups,
            formatLibraryGroupIds,
        } = acquisitionsStore

        return {
            isUserPermitted,
            formatLibraryGroupIds,
            resetOwnersAndVisibleGroups,
            getVisibleGroups,
        }
    },
    data() {
        return {
            initialized: false,
            fundGroup: {
                name: "",
                currency: "",
                lib_group_visibility: [],
            },
            currencies: [],
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getDataRequiredForPageLoad(to.params.fund_group_id)
        })
    },
    methods: {
        async getDataRequiredForPageLoad(fund_group_id) {
            this.getCurrencies().then(() => {
                if (fund_group_id) {
                    this.getFundGroup(fund_group_id)
                } else {
                    this.initialized = true
                }
            })
        },
        async getFundGroup(fund_group_id) {
            const client = APIClient.acquisition
            await client.fundGroups.get(fund_group_id).then(fundGroup => {
                this.fundGroup = fundGroup
                this.fundGroup.lib_group_visibility =
                    this.formatLibraryGroupIds(fundGroup.lib_group_visibility)
                this.initialized = true
            })
        },
        async getCurrencies() {
            const client = APIClient.acquisition
            await client.currencies.getAll().then(
                currencies => {
                    this.currencies = currencies
                },
                error => {}
            )
        },
        onSubmit(e) {
            e.preventDefault()

            if (!this.isUserPermitted("createFundGroup")) {
                setWarning(
                    this.$__(
                        "You do not have the required permissions to create fund groups."
                    )
                )
                return
            }

            const fundGroup = JSON.parse(JSON.stringify(this.fundGroup))
            const fund_group_id = fundGroup.fund_group_id

            delete fundGroup.fund_group_id

            if (fund_group_id) {
                const acq_client = APIClient.acquisition
                acq_client.fundGroups.update(fundGroup, fund_group_id).then(
                    success => {
                        setMessage(this.$__("Fund group updated"))
                        this.$router.push({ name: "FundGroupList" })
                    },
                    error => {}
                )
            } else {
                const acq_client = APIClient.acquisition
                acq_client.fundGroups.create(fundGroup).then(
                    success => {
                        setMessage(this.$__("Fund group created"))
                        this.$router.push({ name: "FundGroupList" })
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
