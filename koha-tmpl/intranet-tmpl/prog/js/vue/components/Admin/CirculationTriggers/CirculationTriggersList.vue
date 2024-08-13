<template>
    <Toolbar>
        <ToolbarButton
            :to="{
                name: 'CirculationTriggersFormAdd',
                query: { library_id: selectedLibrary },
            }"
            icon="plus"
            :title="$__('Add new trigger')"
        />
    </Toolbar>
    <div v-if="initialized">
        <h1>Circulation triggers</h1>
        <div class="page-section bg-info">
            <p>
                Rules are applied from most specific to less specific, using the
                first found in this order:
            </p>
            <ul>
                <li>same library, same patron category, same item type</li>
                <li>same library, same patron category, all item types</li>
                <li>same library, all patron categories, same item type</li>
                <li>same library, all patron categories, all item types</li>
                <li>
                    default (all libraries), same patron category, same item
                    type
                </li>
                <li>
                    default (all libraries), same patron category, all item
                    types
                </li>
                <li>
                    default (all libraries), all patron categories, same item
                    type
                </li>
                <li>
                    default (all libraries), all patron categories, all item
                    types
                </li>
            </ul>
        </div>
        <div class="page-section" v-if="initialized">
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
                        >{{ $__("Trigger") + " " + number }}</a
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
                        :circRules="circRules"
                        :triggerNumber="number"
                        :categories="categories"
                        :itemTypes="itemTypes"
                    />
                </div>
            </template>
        </div>
    </div>
    <div v-if="showModal" class="modal_centered">
        <div
            class="modal-dialog modal-dialog-centered modal-lg"
            role="document"
        >
            <router-view></router-view>
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue";
import ToolbarButton from "../../ToolbarButton.vue";
import { APIClient } from "../../../fetch/api-client.js";
import TriggersTable from "./TriggersTable.vue";
import { inject } from "vue";

export default {
    setup() {
        const { splitCircRulesByTriggerNumber } = inject("circRulesStore");

        return {
            splitCircRulesByTriggerNumber,
        };
    },
    data() {
        return {
            initialized: false,
            libraries: null,
            selectedLibrary: "*",
            circRules: null,
            numberOfTabs: [1],
            tabSelected: "Notice 1",
            showModal: false,
        };
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getLibraries().then(() =>
                vm
                    .getCategories()
                    .then(() =>
                        vm
                            .getItemTypes()
                            .then(() =>
                                vm
                                    .getCircRules({}, true)
                                    .then(() => (vm.initialized = true))
                            )
                    )
            );
        });
    },
    methods: {
        async getLibraries() {
            const libClient = APIClient.library;
            await libClient.libraries.getAll().then(
                libraries => {
                    libraries.unshift({
                        library_id: "*",
                        name: "All libraries",
                    });
                    this.libraries = libraries;
                },
                error => {}
            );
        },
        async getCategories() {
            const client = APIClient.patron;
            await client.patronCategories.getAll().then(
                categories => {
                    categories.unshift({
                        patron_category_id: "*",
                        name: "All",
                    });
                    this.categories = categories;
                },
                error => {}
            );
        },
        async getItemTypes() {
            const client = APIClient.item;
            await client.itemTypes.getAll().then(
                types => {
                    types.unshift({
                        item_type_id: "*",
                        description: "All",
                    });
                    this.itemTypes = types;
                },
                error => {}
            );
        },
        async getCircRules(params = {}, pageLoad) {
            params.effective = false;
            if (pageLoad) {
                params.library_id = "*";
            }
            const client = APIClient.circRule;
            await client.circRules.getAll({}, params).then(
                rules => {
                    const { numberOfTabs, rulesPerTrigger: circRules } =
                        this.splitCircRulesByTriggerNumber(rules);
                    this.numberOfTabs = numberOfTabs;
                    this.circRules = circRules;
                },
                error => {}
            );
        },
        async handleLibrarySelection(e) {
            if (!e) e = "";
            await this.getCircRules({ library_id: e });
        },
        changeTabContent(e) {
            this.tabSelected = e.target.getAttribute("data-content");
        },
    },
    watch: {
        $route: {
            immediate: true,
            handler: function (newVal, oldVal) {
                this.showModal = newVal.meta && newVal.meta.showModal;
            },
        },
    },
    components: { TriggersTable, Toolbar, ToolbarButton },
};
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
.modal-dialog {
    overflow: auto;
    height: 90%;
}
</style>
