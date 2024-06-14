import { createApp } from "vue";
import { createWebHistory, createRouter } from "vue-router";
import { createPinia } from "pinia";

import App from "../components/Plugin-store/Main.vue";

import { routes as routesDef } from "../routes/plugin-store";

import { useMainStore } from "../stores/main";
import { useNavigationStore } from "../stores/navigation";
import i18n from "../i18n";

const pinia = createPinia();

const mainStore = useMainStore(pinia);
const navigationStore = useNavigationStore(pinia);
const routes = navigationStore.setRoutes(routesDef);

const router = createRouter({
    history: createWebHistory(),
    linkExactActiveClass: "current",
    routes,
});

const app = createApp(App);

const rootComponent = app.use(i18n).use(pinia).use(router);

app.provide("mainStore", mainStore);
app.provide("navigationStore", navigationStore);

app.mount("#plugin-store");
