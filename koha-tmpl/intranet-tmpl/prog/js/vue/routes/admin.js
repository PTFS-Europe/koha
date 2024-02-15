import { markRaw } from "vue";
import Edit from "../components/Admin/RecordSources/Edit.vue";
import List from "../components/Admin/RecordSources/List.vue";
import { $__ } from "../i18n";

export const routes = [
    {
        title: $__("Administration"),
        path: "",
        href: "/cgi-bin/koha/admin/admin-home.pl",
        BeforeUnloadEvent() {
            window.location.href = "/cgi-bin/koha/admin/admin-home.pl";
        },
        is_base: true,
        is_default: true,
        children: [
            {
                title: $__("Record sources"),
                path: "/cgi-bin/koha/admin/record_sources",
                children: [
                    {
                        title: $__("List"),
                        path: "",
                        component: markRaw(List),
                    },
                    {
                        title: $__("Add record source"),
                        path: "add",
                        name: "Add",
                        component: markRaw(Edit),
                    },
                    {
                        title: $__("Edit record source"),
                        path: ":id",
                        name: "Edit",
                        component: markRaw(Edit),
                    },
                ],
            },
        ],
    },
];
