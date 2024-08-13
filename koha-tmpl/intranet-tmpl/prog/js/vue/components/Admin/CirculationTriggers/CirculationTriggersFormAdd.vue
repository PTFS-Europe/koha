<template>
    <router-link :to="{ name: 'CirculationTriggersList' }" class="close_modal">
        <i class="fa fa-fw fa-close"></i>
    </router-link>
    <div v-if="initialized" class="modal-content">
        <form @submit="addCircRule($event)">
            <div class="modal-header">
                <h1 v-if="!editMode">{{ $__("Add circulation trigger") }}</h1>
                <h1 v-else>{{ $__("Edit circulation trigger") }}</h1>
            </div>
            <div class="modal-body">
                <div class="page-section bg-info" v-if="circRules.length">
                    <h2>{{ $__("Trigger context") }}</h2>
                    <TriggerContext :ruleInfo="ruleInfo" />
                    <h2>{{ $__("Existing rules") }}</h2>
                    <p>{{ $__("Notice") }} {{ " " + newTriggerNumber - 1 }}</p>
                    <TriggersTable
                        :circRules="circRules"
                        :triggerNumber="newTriggerNumber - 1"
                        :modal="true"
                        :ruleBeingEdited="ruleBeingEdited"
                    />
                </div>
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label for="library_id" class="required"
                                >{{ $__("Library") }}:</label
                            >
                            <v-select
                                id="library_id"
                                v-model="circRuleTrigger.library_id"
                                label="name"
                                :reduce="lib => lib.library_id"
                                :options="libraries"
                                @update:modelValue="handleContextChange($event)"
                                :disabled="editMode ? true : false"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!circRuleTrigger.library_id"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="patron_category_id" class="required"
                                >{{ $__("Patron category") }}:</label
                            >
                            <v-select
                                id="patron_category_id"
                                v-model="circRuleTrigger.patron_category_id"
                                label="name"
                                :reduce="cat => cat.patron_category_id"
                                :options="categories"
                                @update:modelValue="handleContextChange($event)"
                                :disabled="editMode ? true : false"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !circRuleTrigger.patron_category_id
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
                            <label for="item_type_id" class="required"
                                >{{ $__("Item type") }}:</label
                            >
                            <v-select
                                id="item_type_id"
                                v-model="circRuleTrigger.item_type_id"
                                label="description"
                                :reduce="type => type.item_type_id"
                                :options="itemTypes"
                                @update:modelValue="handleContextChange($event)"
                                :disabled="editMode ? true : false"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !circRuleTrigger.item_type_id
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
                            <label for="overdue_delay"
                                >{{ $__("Delay") }}:
                            </label>
                            <input
                                id="overdue_delay"
                                v-model="circRuleTrigger.delay"
                                type="number"
                            />
                        </li>
                        <li>
                            <label for="letter_code"
                                >{{ $__("Letter") }}:</label
                            >
                            <v-select
                                id="letter_code"
                                v-model="circRuleTrigger.notice"
                                label="name"
                                :reduce="type => type.code"
                                :options="letters"
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
                            <label for="mtt"
                                >{{ $__("Transport type(s)") }}:</label
                            >
                            <v-select
                                id="mtt"
                                v-model="circRuleTrigger.mtt"
                                label="name"
                                :reduce="type => type.code"
                                :options="mtts"
                                multiple
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
                            <label for="restricts"
                                >{{ $__("Restricts checkouts") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="restricts"
                                :checked="false"
                                true-value="1"
                                false-value="0"
                                v-model="circRuleTrigger.restrict"
                            />
                        </li>
                    </ol>
                </fieldset>
            </div>
            <div class="modal-footer">
                <ButtonSubmit />
                <router-link
                    :to="{
                        name: 'CirculationTriggersList',
                    }"
                    >Cancel</router-link
                >
            </div>
        </form>
    </div>
    <div v-else>
        <p>{{ $__("Loading...") }}</p>
    </div>
</template>

<script>
import { APIClient } from "../../../fetch/api-client.js"
import TriggersTable from "./TriggersTable.vue"
import { inject } from "vue"
import { storeToRefs } from "pinia"
import ButtonSubmit from "../../ButtonSubmit.vue"
import TriggerContext from "./TriggerContext.vue"

export default {
    setup() {
        const circRulesStore = inject("circRulesStore")
        const { splitCircRulesByTriggerNumber } = circRulesStore
        const { letters } = storeToRefs(circRulesStore)

        return {
            splitCircRulesByTriggerNumber,
            letters,
        }
    },
    data() {
        return {
            initialized: false,
            libraries: null,
            categories: null,
            itemTypes: null,
            circRules: [],
            circRuleTrigger: {
                item_type_id: "*",
                library_id: "*",
                patron_category_id: "*",
                delay: null,
                notice: null,
                mtt: null,
                restrict: "0",
            },
            effectiveRule: {
                item_type_id: "*",
                library_id: "*",
                patron_category_id: "*",
                delay: null,
                notice: null,
                mtt: null,
                restrict: "0",
            },
            newTriggerNumber: 1,
            mtts: [
                { code: "email", name: "Email" },
                { code: "sms", name: "SMS" },
                { code: "print", name: "Print" },
            ],
            ruleInfo: {
                issuelength: null,
                decreaseloanholds: null,
                fine: null,
                chargeperiod: null,
                lengthunit: null,
            },
            editMode: false,
            ruleBeingEdited: null,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getLibraries().then(() =>
                vm.getCategories().then(() =>
                    vm.getItemTypes().then(() => {
                        const { query } = to
                        vm.checkForExistingRules(query).then(
                            () => (vm.initialized = true)
                        )
                    })
                )
            )
        })
    },
    methods: {
        async addCircRule(e) {
            e.preventDefault()

            const context = {
                library_id: this.circRuleTrigger.library_id || "*",
                item_type_id: this.circRuleTrigger.item_type_id || "*",
                patron_category_id:
                    this.circRuleTrigger.patron_category_id || "*",
            }

            const delay =
                this.circRuleTrigger.delay === this.effectiveRule.delay
                    ? null
                    : this.circRuleTrigger.delay
            const notice =
                this.circRuleTrigger.notice === this.effectiveRule.notice
                    ? null
                    : this.circRuleTrigger.notice
            const restrict =
                this.circRuleTrigger.restrict === this.effectiveRule.restrict
                    ? null
                    : this.circRuleTrigger.restrict
            const mtt =
                this.circRuleTrigger.mtt.join(",") ===
                this.effectiveRule.mtt.join(",")
                    ? null
                    : this.circRuleTrigger.mtt.join(",")

            const circRule = {
                context,
            }
            circRule[`overdue_${this.newTriggerNumber}_delay`] = delay
            circRule[`overdue_${this.newTriggerNumber}_notice`] = notice
            circRule[`overdue_${this.newTriggerNumber}_restrict`] = restrict
            circRule[`overdue_${this.newTriggerNumber}_mtt`] = mtt

            if (this.editMode) {
                Object.keys(circRule).forEach(key => {
                    if (key === "context") return
                    if (!circRule[key]) delete circRule[key]
                })
            }

            const client = APIClient.circRule
            await client.circRules.update(circRule).then(
                () => {
                    this.$router
                        .push({ name: "CirculationTriggersList" })
                        .then(() => this.$router.go(0))
                },
                error => {}
            )
        },
        async getLibraries() {
            const client = APIClient.library
            await client.libraries.getAll().then(
                libraries => {
                    libraries.unshift({
                        library_id: "*",
                        name: "All libraries",
                    })
                    this.libraries = libraries
                },
                error => {}
            )
        },
        async getCategories() {
            const client = APIClient.patron
            await client.patronCategories.getAll().then(
                categories => {
                    categories.unshift({
                        patron_category_id: "*",
                        name: "All categories",
                    })
                    this.categories = categories
                },
                error => {}
            )
        },
        async getItemTypes() {
            const client = APIClient.item
            await client.itemTypes.getAll().then(
                types => {
                    types.unshift({
                        item_type_id: "*",
                        description: "All item types",
                    })
                    this.itemTypes = types
                },
                error => {}
            )
        },
        async handleContextChange() {
            await this.checkForExistingRules()
        },
        async checkForExistingRules(routeParams) {
            // We always pass library_id so we need to check for the existence of either item type or patron category
            const editMode = routeParams && routeParams.triggerNumber
            if (editMode) {
                this.editMode = editMode
                this.ruleBeingEdited = routeParams.triggerNumber
            }
            const library_id =
                routeParams && routeParams.library_id
                    ? routeParams.library_id
                    : this.circRuleTrigger.library_id || "*"
            const item_type_id =
                routeParams && routeParams.item_type_id
                    ? routeParams.item_type_id
                    : this.circRuleTrigger.item_type_id || "*"
            const patron_category_id =
                routeParams && routeParams.patron_category_id
                    ? routeParams.patron_category_id
                    : this.circRuleTrigger.patron_category_id || "*"
            const params = {
                library_id,
                item_type_id,
                patron_category_id,
            }

            const client = APIClient.circRule
            await client.circRules.getAll({}, params).then(
                rules => {
                    if (rules.length === 0) {
                        this.newTriggerNumber = 1
                    } else {
                        const { rulesPerTrigger } =
                            this.splitCircRulesByTriggerNumber(rules)
                        this.circRules = rulesPerTrigger
                        this.ruleInfo = {
                            issuelength: rules[0].issuelength,
                            decreaseloanholds: rules[0].decreaseloanholds,
                            fine: rules[0].fine,
                            chargeperiod: rules[0].chargeperiod,
                            lengthunit: rules[0].lengthunit,
                        }
                    }
                },
                error => {}
            )

            params.effective = false
            await client.circRules.getAll({}, params).then(
                rules => {
                    if (rules.length === 0) {
                        this.newTriggerNumber = 1

                        this.assignTriggerValues(
                            "circRuleTrigger",
                            this.circRules,
                            this.newTriggerNumber,
                            params
                        )
                        this.assignTriggerValues(
                            "effectiveRule",
                            this.circRules,
                            this.newTriggerNumber,
                            params
                        )
                    } else {
                        const regex = /overdue_(\d+)_delay/g
                        const numberOfTriggers = Object.keys(rules[0]).filter(
                            key => regex.test(key) && rules[0][key] !== null
                        ).length
                        this.newTriggerNumber = editMode
                            ? routeParams.triggerNumber
                            : numberOfTriggers + 1
                        const { rulesPerTrigger } =
                            this.splitCircRulesByTriggerNumber(rules)
                        const triggerToDisplay = editMode
                            ? routeParams.triggerNumber
                            : numberOfTriggers
                        this.assignTriggerValues(
                            "circRuleTrigger",
                            rulesPerTrigger,
                            triggerToDisplay
                        )
                        this.assignTriggerValues(
                            "effectiveRule",
                            rulesPerTrigger,
                            triggerToDisplay
                        )
                    }
                },
                error => {}
            )
        },
        assignTriggerValues(prop, rules, triggerNumber, context = null) {
            this[prop] = {
                item_type_id: context
                    ? context.item_type_id
                    : rules[triggerNumber - 1].context.item_type_id || "*",
                library_id: context
                    ? context.library_id
                    : rules[triggerNumber - 1].context.library_id || "*",
                patron_category_id: context
                    ? context.patron_category_id
                    : rules[triggerNumber - 1].context.patron_category_id ||
                      "*",
                delay: rules[triggerNumber - 1][
                    `overdue_${triggerNumber}_delay`
                ],
                notice: rules[triggerNumber - 1][
                    `overdue_${triggerNumber}_notice`
                ],
                mtt: rules[triggerNumber - 1][`overdue_${triggerNumber}_mtt`]
                    ? rules[triggerNumber - 1][
                          `overdue_${triggerNumber}_mtt`
                      ].split(",")
                    : [],
                restrict:
                    rules[triggerNumber - 1][
                        `overdue_${triggerNumber}_restrict`
                    ],
            }
        },
    },
    watch: {
        $route: {
            immediate: true,
            handler: function (newVal, oldVal) {
                if (
                    oldVal &&
                    oldVal.query.triggerNumber &&
                    newVal.query.triggerNumber !== oldVal.query.triggerNumber
                ) {
                    this.$router.go(0)
                }
            },
        },
    },
    components: { TriggersTable, ButtonSubmit, TriggerContext },
}
</script>

<style scoped>
.close_modal {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    font-size: 2rem;
}

form li {
    display: flex;
    align-items: center;
}

.dialog.alert
    fieldset:not(.bg-danger):not(.bg-warning):not(.bg-info):not(.bg-success):not(.bg-primary):not(.action),
.dialog.error
    fieldset:not(.bg-danger):not(.bg-warning):not(.bg-info):not(.bg-success):not(.bg-primary):not(.action) {
    margin: 0;
    background-color: rgba(255, 255, 255, 1);
}

.router-link-active {
    margin-left: 10px;
}
</style>
