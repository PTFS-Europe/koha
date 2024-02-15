import { createApp } from "vue";
import { createWebHistory, createRouter } from "vue-router";
import { createPinia } from "pinia";

import { library } from "@fortawesome/fontawesome-svg-core";
import {
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faClose,
    faPaperPlane,
    faInbox,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import vSelect from "vue-select";

library.add(
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faClose,
    faPaperPlane,
    faInbox
);

import App from "../components/Main.vue";

// Import new routes here
import { routes as erm } from "../routes/erm";
import { routes as preservation } from "../routes/preservation";
import { routes as admin } from "../routes/admin";
// Add them to the definition
const routesDef = {
    erm,
    preservation,
    admin,
};

import { useMainStore } from "../stores/main";
import { useVendorStore } from "../stores/vendors";
import { useAVStore } from "../stores/authorised-values";
import { useERMStore } from "../stores/erm";
import { useNavigationStore } from "../stores/navigation";
import { useReportsStore } from "../stores/usage-reports";
import { usePreservationStore } from "../stores/preservation";
import i18n from "../i18n";

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
const ERMStore = useERMStore(pinia);
app.provide("ERMStore", ERMStore);
const reportsStore = useReportsStore(pinia);
app.provide("reportsStore", reportsStore);
const PreservationStore = usePreservationStore(pinia);
app.provide("PreservationStore", PreservationStore);

const setModuleAndMount = async () => {
    await router.isReady();
    navigationStore.$patch({ current: router.currentRoute.value.matched });
    app.mount("#vue-spa");
};
setModuleAndMount();

const { removeMessages } = mainStore;
router.beforeEach((to, from) => {
    navigationStore.$patch({ current: to.matched, params: to.params || {} });
    removeMessages(); // This will actually flag the messages as displayed already
});
router.afterEach((to, from) => {
    let tab_id = "agreement"; // Agreements

    if (to.path.match(/\/erm\/licenses/)) {
        tab_id = "license";
    } else if (to.path.match(/\/erm\/eholdings\/local\/packages/)) {
        tab_id = "package";
    } else if (to.path.match(/\/erm\/eholdings\/local\/titles/)) {
        tab_id = "title";
    }
    let node = document.getElementById(`${tab_id}_search_tab`);

    if (node) {
        node.click();
    }
});
