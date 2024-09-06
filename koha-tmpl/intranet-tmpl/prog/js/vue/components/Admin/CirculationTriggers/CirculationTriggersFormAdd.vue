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
                    <h2 v-if="ruleInfo.numberOfTriggers > 0">{{ $__("Existing rules") }}</h2>
                    <p v-if="ruleInfo.numberOfTriggers > 0">{{ $__("Notice") }} {{ " " + newTriggerNumber - 1 }}</p>
                    <TriggersTable
                        v-if="ruleInfo.numberOfTriggers > 0"
                        :circRules="circRules"
                        :triggerNumber="newTriggerNumber - 1"
                        :modal="true"
                        :ruleBeingEdited="ruleBeingEdited"
                        :triggerBeingEdited="triggerBeingEdited"
                        :letters="letters"
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
                                v-model="newRule.library_id"
                                label="name"
                                :reduce="lib => lib.library_id"
                                :options="libraries"
                                @update:modelValue="handleContextChange($event)"
                                :disabled="editMode ? true : false"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!newRule.library_id"
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
                                v-model="newRule.patron_category_id"
                                label="name"
                                :reduce="cat => cat.patron_category_id"
                                :options="categories"
                                @update:modelValue="handleContextChange($event)"
                                :disabled="editMode ? true : false"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !newRule.patron_category_id
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
                                v-model="newRule.item_type_id"
                                label="description"
                                :reduce="type => type.item_type_id"
                                :options="itemTypes"
                                @update:modelValue="handleContextChange($event)"
                                :disabled="editMode ? true : false"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="
                                            !newRule.item_type_id
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
                                v-model="newRule.delay"
                                type="number"
                                :placeholder="fallbackRule.delay"
                                :min="minDelay"
                            />
                        </li>
                        <li>
                            <label for="letter_code"
                                >{{ $__("Letter") }}:</label
                            >
                            <v-select
                                id="letter_code"
                                v-model="newRule.notice"
                                label="name"
                                :reduce="type => type.code"
                                :options="letters"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                        :placeholder="letters.find(letter => letter.code === fallbackRule.notice)?.name || fallbackRule.notice"
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
                                v-model="newRule.mtt"
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
                                v-model="newRule.restrict"
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
            newRule: {
                item_type_id: "*",
                library_id: "*",
                patron_category_id: "*",
                delay: null,
                notice: null,
                mtt: null,
                restrict: "0",
            },
            fallbackRule: {
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
                numberOfTriggers: null,
            },
            editMode: false,
            ruleBeingEdited: null,
            triggerBeingEdited: null,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getLibraries().then(() =>
                vm.getCategories().then(() =>
                    vm.getItemTypes().then(() =>
                        vm.getCircRules().then(() => {
                            const { query } = to
                            vm.checkForExistingRules(query).then(
                                () => (vm.initialized = true)
                            )
                        })
                    )
                )
            )
        })
    },
    computed: {
        minDelay() {
            const lastRule = this.circRules[this.newTriggerNumber - 2];
            return lastRule ? parseInt(lastRule[`overdue_${this.newTriggerNumber - 1}_delay`]) + 1 : 0;
        }
    },
    methods: {
        async addCircRule(e) {
            e.preventDefault()

            const context = {
                library_id: this.newRule.library_id || "*",
                item_type_id: this.newRule.item_type_id || "*",
                patron_category_id:
                    this.newRule.patron_category_id || "*",
            }

            const circRule = {
                context,
            }
            circRule[`overdue_${this.newTriggerNumber}_delay`] = this.newRule.delay
            circRule[`overdue_${this.newTriggerNumber}_notice`] = this.newRule.notice
            circRule[`overdue_${this.newTriggerNumber}_restrict`] = this.newRule.restrict
            circRule[`overdue_${this.newTriggerNumber}_mtt`] = this.newRule.mtt ? this.newRule.mtt.join(",") : null

            const client = APIClient.circRule
            await client.circRules.update(circRule).then(
                () => {
                    this.$router
                        .push({
                            name: "CirculationTriggersList",
                            query: { trigger: this.newTriggerNumber },
                        })
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
        async getCircRules() {
            const client = APIClient.circRule
            await client.circRules.getAll({}, { effective: false }).then(
                rules => {
                    const { rulesPerTrigger } = this.splitCircRulesByTriggerNumber(rules)
                    this.circRules = rulesPerTrigger.length ? rulesPerTrigger : rules
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
                this.triggerBeingEdited = routeParams.triggerNumber
            }
            const library_id =
                routeParams && routeParams.library_id
                    ? routeParams.library_id
                    : this.newRule.library_id || "*"
            const item_type_id =
                routeParams && routeParams.item_type_id
                    ? routeParams.item_type_id
                    : this.newRule.item_type_id || "*"
            const patron_category_id =
                routeParams && routeParams.patron_category_id
                    ? routeParams.patron_category_id
                    : this.newRule.patron_category_id || "*"
            const params = {
                library_id,
                item_type_id,
                patron_category_id,
            }

            // Fetch effective ruleset for context
            const client = APIClient.circRule
            await client.circRules.getAll({}, params).then(
                rules => {
                    this.ruleBeingEdited = rules[0]
                    this.ruleBeingEdited.context = params
                    const regex = /overdue_(\d+)_delay/g
                    const numberOfTriggers = Object.keys(rules[0]).filter(
                        key => regex.test(key) && rules[0][key] !== null
                    ).length
                    const splitRules = this.filterCircRulesByContext(this.ruleBeingEdited)
                    this.newTriggerNumber = editMode
                        ? routeParams.triggerNumber
                        : numberOfTriggers + 1
                    this.assignTriggerValues(
                        splitRules,
                        this.newTriggerNumber,
                        params
                    )

                    this.ruleInfo = {
                        issuelength: rules[0].issuelength,
                        decreaseloanholds: rules[0].decreaseloanholds,
                        fine: rules[0].fine,
                        chargeperiod: rules[0].chargeperiod,
                        lengthunit: rules[0].lengthunit,
                        numberOfTriggers: numberOfTriggers,
                    }
                },
                error => { }
            )
        },
        filterCircRulesByContext(effectiveRule) {
            const context = effectiveRule.context;
        
            // Filter rules that match the context
            let contextRules = this.circRules.filter(rule => {
                return Object.keys(context).every(key => {
                    return context[key] === rule.context[key];
                });
            });
        
            // Calculate the number of 'overdue_X_' triggers in the effectiveRule
            const regex = /overdue_(\d+)_delay/g;
            const numberOfTriggers = Object.keys(effectiveRule).filter(
                key => regex.test(key) && effectiveRule[key] !== null
            ).length;
        
            // Ensure there is one contextRule per 'X' from 1 to numberOfTriggers
            for (let i = 1; i <= numberOfTriggers; i++) {
                // Check if there's already a rule for overdue_X_ in contextRules
                const matchingRule = contextRules.find(rule => rule[`overdue_${i}_delay`] !== undefined);
        
                if (!matchingRule) {
                    // Create a new rule with the same context and null overdue_X_* keys
                    const placeholderRule = {
                        context: { ...context }, // Clone the context
                        [`overdue_${i}_delay`]: null,
                        [`overdue_${i}_notice`]: null,
                        [`overdue_${i}_mtt`]: null
                    };
        
                    // Add the new rule to contextRules
                    contextRules.push(placeholderRule);
                }
            }

            // Sort contextRules by the 'X' value in 'overdue_X_delay'
            contextRules.sort((a, b) => {
                const getX = rule => {
                    const match = Object.keys(rule).find(key => regex.test(key));
                    return match ? parseInt(match.match(/\d+/)[0], 10) : 0;
                };
        
                return getX(a) - getX(b);
            });

            return contextRules;
        },
        findFallbackRule(currentContext, key) {

            // Filter rules to only those with non-null values for the specified key and not the current context
            const relevantRules = this.circRules.filter(
                rule => {
                    return Object.keys(currentContext).some(key => currentContext[key] !== rule.context[key]) 
                        && rule[key] !== null
                        && rule[key] !== undefined;
                }
            );

            // Function to calculate specificity score
            const getSpecificityScore = ruleContext => {
                let score = 0
                if (
                    ruleContext.library_id !== "*" &&
                    ruleContext.library_id === currentContext.library_id
                )
                    score += 4
                if (
                    ruleContext.patron_category_id !== "*" &&
                    ruleContext.patron_category_id ===
                    currentContext.patron_category_id
                )
                    score += 2
                if (
                    ruleContext.item_type_id !== "*" &&
                    ruleContext.item_type_id === currentContext.item_type_id
                )
                    score += 1
                return score
            }

            // Sort the rules based on specificity score, descending
            const sortedRules = relevantRules.sort((a, b) => {
                return (
                    getSpecificityScore(b.context) -
                    getSpecificityScore(a.context)
                )
            })

            // If no rule found, return null
            if (sortedRules.length === 0) {
                return null 
            }

            // Get the value from the most specific rule
            const bestRule = sortedRules[0]
            return bestRule[key]
        },
        assignTriggerValues(rules, triggerNumber, context = null) {
            this.newRule = {
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
                delay: rules[triggerNumber - 1] ? rules[triggerNumber - 1][
                    `overdue_${triggerNumber}_delay`
                ] : null,
                notice: rules[triggerNumber - 1] ? rules[triggerNumber - 1][
                    `overdue_${triggerNumber}_notice`
                ] : null,
                mtt: rules[triggerNumber - 1] ? rules[triggerNumber - 1][`overdue_${triggerNumber}_mtt`]
                    ? rules[triggerNumber - 1][
                          `overdue_${triggerNumber}_mtt`
                      ].split(",")
                    : [] : null,
                restrict: rules[triggerNumber - 1] ?
                    rules[triggerNumber - 1][
                        `overdue_${triggerNumber}_restrict`
                    ] : null,
            }
            this.fallbackRule = {
                delay: this.findFallbackRule(context, `overdue_${triggerNumber}_delay`),
                notice: this.findFallbackRule(context, `overdue_${triggerNumber}_notice`),
                mtt: this.findFallbackRule(context, `overdue_${triggerNumber}_mtt`),
                restrict: this.findFallbackRule(context, `overdue_${triggerNumber}_restrict`)
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
