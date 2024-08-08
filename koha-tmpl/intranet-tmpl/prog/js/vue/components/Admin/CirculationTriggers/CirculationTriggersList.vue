<template>
    <Toolbar>
        <ToolbarButton
            :to="{ name: 'CirculationTriggersFormAdd' }"
            icon="plus"
            :title="$__('Add new trigger')"
        />
    </Toolbar>
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
    <div v-if="showModal" class="modal_centered">
        <div class="dialog alert confirmation">
            <router-view></router-view>
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarButton from "../../ToolbarButton.vue"
import { APIClient } from "../../../fetch/api-client.js"
import TriggersTable from "./TriggersTable.vue"

export default {
    data() {
        return {
            initialized: false,
            libraries: null,
            selectedLibrary: "*",
            circRules: null,
            numberOfTabs: [1],
            tabSelected: "Notice 1",
            showModal: false,
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
         * trigger number e.g. overdue_1_delay, overdue_2_delay, etc.
         *
         * It will also set the number of tabs required based on the number of trigger numbers.
         *
         * @param {Array} rules - The array of circulation rules to be split.
         * @return {Array} An array of circulation rules, where each rule contains only the necessary fields for a
         * specific trigger number.
         */
        splitCircRulesByTriggerNumber(rules) {
            const ruleSuffixes = ["delay", "notice", "mtt", "restrict"]
            const rulesPerTrigger = rules.reduce((acc, rule) => {
                const regex = /overdue_(\d+)_delay/g
                const numberOfTriggers = Object.keys(rule).filter(key =>
                    regex.test(key)
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
                    ruleSuffixes.forEach(suffix => {
                        rulesToDelete.forEach(number => {
                            delete ruleCopy[`overdue_${number}_${suffix}`]
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
    watch: {
        $route: {
            immediate: true,
            handler: function (newVal, oldVal) {
                this.showModal = newVal.meta && newVal.meta.showModal
            },
        },
    },
    components: { TriggersTable, Toolbar, ToolbarButton },
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

.modal_centered {
    position: fixed;
    z-index: 9998;
    display: table;
    transition: opacity 0.3s ease;
    left: 0px;
    top: 0px;
    width: 100%;
    height: 100%;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.33);
}
.confirmation {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 80%;
    max-width: 100%;
    min-height: 80%;
    margin: auto;
    align-items: center;
    justify-content: center;
    transform: translate(-50%, -50%);
}
</style>
