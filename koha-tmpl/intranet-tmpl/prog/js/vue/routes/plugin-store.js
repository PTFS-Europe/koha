import { markRaw } from "vue";

import Home from "../components/Plugin-store/Home.vue";
import StorePluginsList from "../components/Plugin-store/StorePluginsList.vue";

import { $__ } from "../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/plugin-store/plugin-store.pl",
        is_default: true,
        is_base: true,
        title: $__("Plugins store"),
        children: [
            {
                path: "",
                name: "Home",
                component: markRaw(Home),
                is_navigation_item: false,
            },
            {
                path: "/cgi-bin/koha/plugin-store/store-plugins",
                title: $__("Store plugins"),
                icon: "fa fa-check-circle",
                is_end_node: true,
                children: [
                    {
                        path: "",
                        name: "StorePluginsList",
                        component: markRaw(StorePluginsList),
                    },
                ],
            },
        ],
    },
];
