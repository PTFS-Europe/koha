<script>
import BaseResource from "../BaseResource.vue"
import { APIClient } from "../../fetch/api-client.js"

export default {
    extends: BaseResource,
    setup(props) {
        return {
            ...BaseResource.setup({
                resource_name: "account",
                name_attr: "login_id",
                id_attr: "sip_account_id",
                show_component: "SIP2AccountsShow",
                list_component: "SIP2AccountsList",
                add_component: "SIP2AccountsFormAdd",
                edit_component: "SIP2AccountsFormAddEdit",
                api_client: APIClient.sip2.accounts,
                resource_table_url: APIClient.sip2._baseURL + "accounts",
                i18n: {
                    display_name: __("Account"),
                },
            }),
        }
    },
    data() {
        return {
            resource_attrs: [
                {
                    name: "login_id",
                    required: true,
                    type: "text",
                    label: __("Account login id"),
                    show_in_table: true,
                },
                {
                    name: "login_id",
                    required: true,
                    type: "text",
                    label: __("Account login password"),
                    show_in_table: true,
                },
                {
                    name: "sip_institution_id",
                    type: "component",
                    label: __("Institution"),
                    required: true,
                    showElement: {
                        type: "text",
                        value: "institution.name",
                        link: {
                            href: "/cgi-bin/koha/sip2/institutions/1",
                            // params: {
                            //     bookseller_id: "vendor_id",
                            // },
                        },
                    },
                    componentPath: "./FormSelectRelatedResource.vue",

                    props: {
                        related_api_client: {
                            type: "object",
                            value: APIClient.sip2.institutions,
                        },
                    },
                },
                {
                    name: "allow_additional_materials_checkout",
                    type: "boolean",
                    label: __("Allow additional materials checkout"),
                    show_in_table: true,
                },
                {
                    name: "account_allow_empty_passwords",
                    type: "boolean",
                    label: __("Allow empty passwords"),
                    show_in_table: true,
                },
                {
                    name: "blocked_items_types",
                    type: "text",
                    label: __("Blocked item types"), // e.g. 'VM|MU'
                    show_in_table: true,
                },
                {
                    name: "checked_in_ok",
                    type: "boolean",
                    label: __("Checked in OK"),
                    show_in_table: true,
                },
                {
                    name: "cr_item_field",
                    type: "text",
                    label: __("CR item field"), // e.g. 'VM|MU'
                    show_in_table: true,
                },
                {
                    name: "ct_always_send",
                    type: "boolean",
                    label: __("CT always send"),
                    show_in_table: true,
                },
                {
                    name: "cv_send_00_on_success",
                    type: "boolean",
                    label: __("CV always send 00 on success"),
                    show_in_table: true,
                },
                {
                    name: "cv_triggers_alert",
                    type: "boolean",
                    label: __("CV triggers alert"),
                    show_in_table: true,
                },
                {
                    name: "delimiter",
                    required: true,
                    type: "text",
                    label: __("Delimiter"), // e.g. '|'
                    show_in_table: true,
                },
                {
                    name: "encoding",
                    type: "text",
                    label: __("Encoding"), // e.g. 'utf-8'
                    show_in_table: true,
                },
                {
                    name: "ae_field_template",
                    type: "textarea",
                    label: __("AE field template"), // e.g. '[% patron.surname %][% IF patron.firstname %], [% patron.firstname %][% END %]'
                    show_in_table: true,
                },
                {
                    name: "av_field_template",
                    type: "textarea",
                    label: __("AV field template"), // e.g. '[% accountline.description %] [% accountline.amountoutstanding | format('%.2f') %]'
                    show_in_table: true,
                },
                {
                    name: "da_field_template",
                    type: "textarea",
                    label: __("DA field template"), // e.g. '[% patron.surname %][% IF patron.firstname %], [% patron.firstname %][% END %]'
                    show_in_table: true,
                },
            ],
        }
    },
    methods: {},
    name: "SIP2AccountResource",
}
</script>
