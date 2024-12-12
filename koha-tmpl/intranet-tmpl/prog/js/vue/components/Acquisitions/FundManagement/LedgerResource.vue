<script>
import BaseResource from "../../BaseResource.vue"
import { APIClient } from "../../../fetch/api-client.js"

export default {
    extends: BaseResource,
    setup(props) {
        return {
            ...BaseResource.setup({
                resource_name: "ledger",
                name_attr: "name",
                id_attr: "ledger_id",
                show_component: "LedgerShow",
                list_component: "LedgerList",
                add_component: "LedgerFormAdd",
                edit_component: "LedgerFormAddEdit",
                api_client: APIClient.acquisition.ledgers,
                resource_table_url: APIClient.acquisition._baseURL + "ledgers",
                i18n: {
                    display_name: __("Ledger"),
                },
            }),
        }
    },
    methods: {},
    name: "LedgerResource",
}
</script>
