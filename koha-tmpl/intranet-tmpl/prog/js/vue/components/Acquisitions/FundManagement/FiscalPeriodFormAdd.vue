<template>
    <div v-if="!initialized">Loading...</div>
    <div v-else id="fiscal_period_add">
        <h2 v-if="fiscal_period.fiscal_period_id">
            {{ `Edit fiscal period ${fiscal_period.fiscal_period_id}` }}
        </h2>
        <h2 v-else>New fiscal period</h2>
        <div>
            <form @submit="onSubmit($event)">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label class="required" for="fiscal_period_code"
                                >Code:</label
                            >
                            <input
                                id="fiscal_period_code"
                                v-model="fiscal_period.code"
                                placeholder="Fiscal period code"
                                required
                            />
                            <span class="required">Required</span>
                        </li>
                        <li>
                            <label
                                for="fiscal_period_description"
                                class="required"
                                >Description:
                            </label>
                            <textarea
                                id="fiscal_period_description"
                                v-model="fiscal_period.description"
                                placeholder="Description"
                                rows="10"
                                cols="50"
                                required
                            />
                            <span class="required">Required</span>
                        </li>
                        <li>
                            <label for="fiscal_period_status" class="required"
                                >Status:</label
                            >
                            <v-select
                                id="fiscal_period_status"
                                v-model="fiscal_period.status"
                                :reduce="av => av.value"
                                :options="statusOptions"
                                label="description"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !statusOptions
                                                .map(opt => opt.value)
                                                .includes(fiscal_period.status)
                                        "
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span class="required">Required</span>
                        </li>
                        <li>
                            <label for="start_date">Start date:</label>
                            <flat-pickr
                                id="start_date"
                                v-model="fiscal_period.start_date"
                                :config="fp_config"
                                data-date_to="end_date"
                            />
                        </li>
                        <li>
                            <label for="end_date">End date:</label>
                            <flat-pickr
                                id="end_date"
                                v-model="fiscal_period.end_date"
                                :config="fp_config"
                            />
                        </li>
                        <li>
                            <label for="fiscal_period_owner" class="required"
                                >Owner:</label
                            >
                            <v-select
                                id="fiscal_period_owner"
                                v-model="fiscal_period.owner_id"
                                :reduce="av => av.borrowernumber"
                                :options="getOwners"
                                @update:modelValue="
                                    filterGroupsBasedOnOwner(
                                        $event,
                                        fiscal_period
                                    )
                                "
                                label="displayName"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!fiscal_period.owner_id"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span class="required">Required</span>
                        </li>
                        <li>
                            <label
                                for="fiscal_period_lib_group_visibility"
                                class="required"
                                >Visible to:</label
                            >
                            <v-select
                                id="fiscal_period_lib_group_visibility"
                                v-model="fiscal_period.lib_group_visibility"
                                :reduce="av => av.id"
                                :options="getVisibleGroups"
                                label="title"
                                @update:modelValue="
                                    filterOwnersBasedOnGroup(
                                        $event,
                                        fiscal_period
                                    )
                                "
                                multiple
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !fiscal_period.lib_group_visibility
                                        "
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span class="required">Required</span>
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="action">
                    <ButtonSubmit />
                    <router-link
                        :to="{ name: 'FiscalPeriodList' }"
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
import flatPickr from "vue-flatpickr-component"
import { inject } from "vue"
import { storeToRefs } from "pinia"
import { APIClient } from "../../../fetch/api-client.js"
import { setMessage, setWarning } from "../../../messages"
import ButtonSubmit from "../../ButtonSubmit.vue"

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

        return {
            isUserPermitted,
            libraryGroups,
            filterGroupsBasedOnOwner,
            filterOwnersBasedOnGroup,
            formatLibraryGroupIds,
            resetOwnersAndVisibleGroups,
            getVisibleGroups,
            getOwners,
        }
    },
    data() {
        return {
            initialized: false,
            fp_config: flatpickr_defaults,
            statusOptions: [
                { description: "Active", value: 1 },
                { description: "Inactive", value: 0 },
            ],
            fiscal_period: {
                fiscal_period_id: null,
                description: "",
                code: "",
                status: null,
                owner_id: null,
                lib_group_visibility: [],
                start_date: undefined,
                end_date: undefined,
            },
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            if (to.params.fiscal_period_id) {
                vm.getFiscalPeriod(to.params.fiscal_period_id)
            } else {
                vm.initialized = true
            }
        })
    },
    methods: {
        async getFiscalPeriod(fiscal_period_id) {
            const client = APIClient.acquisition
            client.fiscalPeriods.get(fiscal_period_id).then(fiscal_period => {
                this.fiscal_period = fiscal_period
                this.fiscal_period.lib_group_visibility =
                    this.formatLibraryGroupIds(
                        fiscal_period.lib_group_visibility
                    )
                this.initialized = true
            })
        },
        onSubmit(e) {
            e.preventDefault()

            if (!this.isUserPermitted("createFiscalPeriods")) {
                setWarning(
                    "You do not have the required permissions to create fiscal periods."
                )
                return
            }

            const fiscal_period = JSON.parse(JSON.stringify(this.fiscal_period))
            const fiscal_period_id = fiscal_period.fiscal_period_id

            const visibility = fiscal_period.lib_group_visibility.join("|")
            fiscal_period.lib_group_visibility = visibility

            delete fiscal_period.fiscal_period_id

            if (fiscal_period_id) {
                const acq_client = APIClient.acquisition
                acq_client.fiscalPeriods
                    .update(fiscal_period, fiscal_period_id)
                    .then(
                        success => {
                            setMessage("Fiscal period updated")
                            this.$router.push({ name: "FiscalPeriodList" })
                        },
                        error => {}
                    )
            } else {
                const acq_client = APIClient.acquisition
                acq_client.fiscalPeriods.create(fiscal_period).then(
                    success => {
                        setMessage("Fiscal period created")
                        this.$router.push({ name: "FiscalPeriodList" })
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
        flatPickr,
        ButtonSubmit,
    },
}
</script>

<style scoped></style>
