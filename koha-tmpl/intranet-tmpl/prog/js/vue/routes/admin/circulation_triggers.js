import { markRaw } from "vue";
import { $__ } from "../../i18n";

import CirculationTriggersList from "../../components/Admin/CirculationTriggers/CirculationTriggersList.vue";
import CirculationTriggersFormAdd from "../../components/Admin/CirculationTriggers/CirculationTriggersFormAdd.vue";

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
            children: [
                {
                    path: "",
                    name: "CirculationTriggersList",
                    component: markRaw(CirculationTriggersList),
                    title: $__("Home"),
                    children: [
                        {
                            path: "add",
                            name: "CirculationTriggersFormAdd",
                            component: markRaw(CirculationTriggersFormAdd),
                            title: $__("Add new trigger"),
                            meta: {
                                showModal: true,
                            },
                        },
                        {
                            path: "edit",
                            name: "CirculationTriggersFormEdit",
                            component: markRaw(CirculationTriggersFormAdd),
                            title: $__("Edit trigger"),
                            meta: {
                                showModal: true,
                            },
                        },
                    ],
                },
            ],
        },
    ],
};
