<template>
    <div>
        <div id="sub-header">
            <Breadcrumbs />
            <Help />
        </div>
        <div class="main container-fluid">
            <div class="row">
                <div class="col-md-10 order-md-2 order-sm-1">
                    <main>
                        <Dialog />
                        <router-view />
                    </main>
                </div>

                <div class="col-md-2 order-sm-2 order-md-1"></div>
            </div>
        </div>
    </div>
</template>

<script>
import Breadcrumbs from "../../Breadcrumbs.vue";
import Help from "../../Help.vue";
import Dialog from "../../Dialog.vue";
import "vue-select/dist/vue-select.css";
import { inject } from "vue";

export default {
    setup() {
        const circRulesStore = inject("circRulesStore");
        letters.unshift({
            name: "No letter",
            code: "",
        });
        circRulesStore.letters = letters;

        return {
            letters,
        };
    },
    components: {
        Breadcrumbs,
        Dialog,
        Help,
    },
};
</script>

<style>
form .v-select {
    display: inline-block;
    background-color: white;
    width: 30%;
}

.v-select,
input:not([type="submit"]):not([type="search"]):not([type="button"]):not(
        [type="checkbox"]
    ):not([type="radio"]),
textarea {
    border-color: rgba(60, 60, 60, 0.26);
    border-width: 1px;
    border-radius: 4px;
    min-width: 30%;
}
</style>
