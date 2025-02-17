import { createPinia } from "pinia";
import { createApp } from "vue";
import { createRouter, createWebHistory } from "vue-router";

import { library } from "@fortawesome/fontawesome-svg-core";
import {
    faMinus,
    faPencil,
    faPlus,
    faSpinner,
    faTrash,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import vSelect from "vue-select";

library.add(faPlus, faMinus, faPencil, faTrash, faSpinner);


library.add(faPlus, faMinus, faPencil, faTrash, faSpinner);

import App from "../components/Shibboleth/Main.vue";

import { routes as routesDef } from "../routes/shibboleth";

import i18n from "../i18n";
import { useAVStore } from "../stores/authorised-values";
import { useMainStore } from "../stores/main";
import { useNavigationStore } from "../stores/navigation";
import { useVendorStore } from "../stores/vendors";

const pinia = createPinia();

const mainStore = useMainStore(pinia);
const AVStore = useAVStore(pinia);
const navigationStore = useNavigationStore(pinia);
const routes = navigationStore.setRoutes(routesDef);

const router = createRouter({
    history: createWebHistory(),
    linkActiveClass: "current",
    routes,
});

const app = createApp(App);

const rootComponent = app
    .use(i18n)
    .use(pinia)
    .use(router)
    .component("font-awesome-icon", FontAwesomeIcon)
    .component("v-select", vSelect);

app.config.unwrapInjectedRef = true;
app.provide("vendorStore", useVendorStore(pinia));
app.provide("mainStore", mainStore);
app.provide("AVStore", AVStore);
app.provide("navigationStore", navigationStore);

app.mount("#shibboleth");

const { removeMessages } = mainStore;
router.beforeEach((to, from) => {
    navigationStore.$patch({ current: to.matched, params: to.params || {} });
    removeMessages(); // This will actually flag the messages as displayed already
});