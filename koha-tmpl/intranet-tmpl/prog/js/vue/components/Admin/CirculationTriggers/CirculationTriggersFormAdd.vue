<template>
    <router-link :to="{ name: 'CirculationTriggersList' }" class="close_modal">
        <i class="fa fa-fw fa-close"></i>
    </router-link>
    <h1>{{ $__("Add circulation trigger") }}</h1>
    <div v-if="initialized">
        <form @submit="addCircRule($event)">
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
                        >
                            <template #search="{ attributes, events }">
                                <input
                                    :required="!circRuleTrigger.item_type_id"
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
        </form>
    </div>
</template>

<script>
import { APIClient } from "../../../fetch/api-client.js"

export default {
    data() {
        return {
            initialized: false,
            libraries: null,
            categories: null,
            itemTypes: null,
            circRules: null,
            circRuleTrigger: {},
        }
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
                                    .getCircRules()
                                    .then(() => (vm.initialized = true))
                            )
                    )
            )
        })
    },
    methods: {
        async addCircRule(e) {
            e.preventDefault()
            console.log("Adding rule")
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
        async getCircRules(params = {}) {
            params.effective = false
            const client = APIClient.circRule
            await client.circRules.getAll({}, params).then(
                rules => {
                    console.log(rules)
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
    },
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
}
</style>
