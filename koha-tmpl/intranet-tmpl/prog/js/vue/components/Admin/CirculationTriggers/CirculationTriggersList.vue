<template>
    <div class="page-section" v-if="initialized">
        <h1>Circulation triggers</h1>
        <label for="library_select">{{ $__("Select a library") }}:</label>
        <v-select
            id="library_select"
            v-model="selectedLibrary"
            label="name"
            :reduce="lib => lib.library_id"
            :options="libraries"
            @update:modelValue="handleLibrarySelection($event)"
        >
            <template #search="{ attributes, events }">
                <input
                    :required="!selectedLibrary"
                    class="vs__search"
                    v-bind="attributes"
                    v-on="events"
                />
            </template>
        </v-select>
    </div>
    <div v-if="initialized">
        <div id="circ_triggers_tabs" class="toptabs numbered">
            <ul class="nav nav-tabs" role="tablist">
                <li
                    v-for="(number, i) in numberOfTabs"
                    role="presentation"
                    v-bind:class="
                        tabSelected === `Notice ${number}` ? 'active' : ''
                    "
                    :key="`noticeTab${i}`"
                >
                    <a
                        href="#"
                        role="tab"
                        @click="changeTabContent"
                        :data-content="`Notice ${number}`"
                        >{{ $__("Notice") + " " + number }}</a
                    >
                </li>
            </ul>
        </div>
        <div class="tab_content">
            <template v-for="(number, i) in numberOfTabs">
                <div
                    v-if="tabSelected === `Notice ${number}`"
                    :key="`noticeTabContent${i}`"
                >
                    <TriggersTable
                        :circRules="filterCircRulesByTabNumber(number)"
                        :triggerNumber="number"
                    />
                </div>
            </template>
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarButton from "../../ToolbarButton.vue"
import { APIClient } from "../../../fetch/api-client.js"
import { inject } from "vue"
import TriggersTable from "./TriggersTable.vue"

export default {
    setup() {
        const { setWarning, setMessage, setError, setConfirmationDialog } =
            inject("mainStore")
        return {
            setWarning,
            setMessage,
            setError,
            setConfirmationDialog,
        }
    },
    data() {
        return {
            initialized: false,
            libraries: null,
            selectedLibrary: "*",
            circRules: null,
            numberOfTabs: [1],
            tabSelected: "Notice 1",
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getLibraries().then(() =>
                vm.getCircRules().then(() => (vm.initialized = true))
            )
        })
    },
    methods: {
        async getLibraries() {
            const libClient = APIClient.library
            await libClient.libraries.getAll().then(
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
        async getCircRules(params = {}) {
            params.effective = false
            const client = APIClient.circRule
            await client.circRules.getAll({}, params).then(
                rules => {
                    this.circRules = this.splitCircRulesByTriggerNumber(rules)
                },
                error => {}
            )
        },
        async handleLibrarySelection(e) {
            if (!e) e = ""
            await this.getCircRules({ library_id: e })
        },
        /**
         * Sets the number of tabs based on the given trigger count.
         *
         * @param {number} triggerCount - The count of triggers.
         * @return {void}
         */
        setNumberOfTabs(triggerCount) {
            if (triggerCount > this.numberOfTabs) {
                this.numberOfTabs = Array.from(
                    { length: triggerCount },
                    (_, i) => i + 1
                )
            }
        },
        /**
         * Splits the given array of circulation rules into an array of rules, where each rule contains only the
         * necessary fields for a specific trigger number. The trigger number is determined by the presence of the
         * "overdue_delay" key in the rule object. The resulting array contains a separate rule object for each
         * trigger number e.g. overdue_delay_1, overdue_delay_2, etc.
         *
         * It will also set the number of tabs required based on the number of trigger numbers.
         *
         * @param {Array} rules - The array of circulation rules to be split.
         * @return {Array} An array of circulation rules, where each rule contains only the necessary fields for a
         * specific trigger number.
         */
        splitCircRulesByTriggerNumber(rules) {
            const rulePrefixes = [
                "overdue_delay",
                "overdue_template",
                "overdue_transports",
                "overdue_restricts",
            ]
            const rulesPerTrigger = rules.reduce((acc, rule) => {
                const numberOfTriggers = Object.keys(rule).filter(key =>
                    key.includes("overdue_delay")
                ).length
                this.setNumberOfTabs(numberOfTriggers)
                const triggerNumbers = Array.from(
                    { length: numberOfTriggers },
                    (_, i) => i + 1
                )
                triggerNumbers.forEach(i => {
                    const ruleCopy = JSON.parse(JSON.stringify(rule))
                    const rulesToDelete = triggerNumbers.filter(
                        num => num !== i
                    )
                    rulePrefixes.forEach(prefix => {
                        rulesToDelete.forEach(number => {
                            delete ruleCopy[`${prefix}_${number}`]
                        })
                    })
                    ruleCopy.triggerNumber = i
                    acc.push(ruleCopy)
                })
                return acc
            }, [])
            return rulesPerTrigger
        },
        changeTabContent(e) {
            this.tabSelected = e.target.getAttribute("data-content")
        },
        filterCircRulesByTabNumber(number) {
            return this.circRules.filter(rule => rule.triggerNumber === number)
        },
    },
    components: { TriggersTable },
}
</script>

<style scoped>
.v-select {
    display: inline-block;
    background-color: white;
    width: 30%;
    margin-left: 10px;
}
.active {
    cursor: pointer;
}
.toptabs {
    margin-bottom: 0;
}
</style>
