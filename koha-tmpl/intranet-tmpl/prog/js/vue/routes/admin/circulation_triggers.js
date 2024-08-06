import { markRaw } from "vue";
import { $__ } from "../../i18n";

import CirculationTriggersList from "../../components/Admin/CirculationTriggers/CirculationTriggersList.vue";

export default {
    title: $__("Administration"),
    path: "",
    href: "/cgi-bin/koha/admin/admin-home.pl",
    is_base: true,
    is_default: true,
    children: [
        {
            title: $__("Circulation triggers"),
            path: "/cgi-bin/koha/admin/circulation_triggers",
            is_end_node: true,
            children: [
                {
                    path: "",
                    name: "CirculationTriggersList",
                    component: markRaw(CirculationTriggersList),
                },
            ],
        },
    ],
};
