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
    methods: {},
    name: "SIP2AccountResource",
}
</script>
