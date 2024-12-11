import { createApp } from "vue";
import { createWebHistory, createRouter } from "vue-router";
import { createPinia } from "pinia";
import vSelect from "vue-select";

import { library } from "@fortawesome/fontawesome-svg-core";
import {
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faPenToSquare,
    faXmark,
    faArrowRightArrowLeft,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";

library.add(
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faPenToSquare,
    faXmark,
    faArrowRightArrowLeft
);

import App from "../../components/Acquisitions/FundManagement/Main.vue";
import { routes as routesDef } from "../../routes/acquisitions/fundManagement.js";
import { useMainStore } from "../../stores/main";
import { useNavigationStore } from "../../stores/navigation";
import { usePermissionsStore } from "../../stores/permissions";
import { useAcquisitionsStore } from "../../stores/acquisitions";
import { useAVStore } from "../../stores/authorised-values";
import i18n from "../../i18n";

const pinia = createPinia();
const mainStore = useMainStore(pinia);
const acquisitionsStore = useAcquisitionsStore(pinia);
const navigationStore = useNavigationStore(pinia);
const permissionsStore = usePermissionsStore(pinia);
const AVStore = useAVStore(pinia);
const routes = navigationStore.setRoutes(routesDef);

const router = createRouter({
    history: createWebHistory(),
    linkActiveClass: "current",
    routes,
});

const app = createApp(App);
app.use(router);
app.use(pinia);
app.use(i18n);
app.provide("navigationStore", navigationStore);
app.provide("acquisitionsStore", acquisitionsStore);
app.provide("permissionsStore", permissionsStore);
app.provide("mainStore", mainStore);
app.provide("AVStore", AVStore);
app.component("v-select", vSelect);
app.component("font-awesome-icon", FontAwesomeIcon);

const { removeMessages, setWarning } = mainStore;
const { setOwnersBasedOnPermission, isUserPermitted } = acquisitionsStore;
router.beforeEach((to, from) => {
    if (to.matched.length === 0) {
        // The Apache redirect does not render breadcrumbs so we need to push to the correct route
        router.push({ name: "Home" });
    } else {
        const endRoute = [...to.matched].pop().meta.self;
        if (endRoute.permission) {
            acquisitionsStore.$patch({
                currentPermission: endRoute.permission,
            });
            setOwnersBasedOnPermission(endRoute.permission);
            const userPermitted = isUserPermitted(
                endRoute.permission,
                userflags
            );
            if (!userPermitted) {
                // Redirect to the homepage
                acquisitionsStore.$patch({
                    navigationBlocked: true,
                    currentPermission: null,
                });
                return { name: "Homepage" };
            } else {
                navigationStore.$patch({
                    current: to.matched,
                    params: to.params || {},
                });
                removeMessages(); // This will actually flag the messages as displayed already
            }
        } else {
            navigationStore.$patch({
                current: to.matched,
                params: to.params || {},
            });
            removeMessages();
        }
    }
});

const loadRouterAndMount = async () => {
    try {
        await router.isReady();
        app.mount("#__fundManagement");
    } catch (err) {
        console.log(err);
    }
};

loadRouterAndMount();
