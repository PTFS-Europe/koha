import { markRaw } from "vue";

import Home from "../components/Shibboleth/Home.vue";

import { $__ } from "../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/shibboleth/shibboleth.pl",
        is_default: true,
        is_base: true,
        title: $__("Shibboleth"),
        children: [
            {
                path: "",
                name: "Home",
                component: markRaw(Home),
                is_navigation_item: false,
            },
        ],
    },
];