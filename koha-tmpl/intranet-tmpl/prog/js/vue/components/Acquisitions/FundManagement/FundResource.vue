<script>
import BaseResource from "../../BaseResource.vue"
import { APIClient } from "../../../fetch/api-client.js"

export default {
    extends: BaseResource,
    setup(props) {
        return {
            ...BaseResource.setup({
                resource_name: "fund",
                name_attr: "name",
                id_attr: "fund_id",
                show_component: "FundShow",
                list_component: "FundList",
                add_component: "FundFormAdd",
                edit_component: "FundFormAddEdit",
                api_client: APIClient.acquisition.funds,
                resource_table_url: APIClient.acquisition._baseURL + "funds",
                i18n: {
                    display_name: __("Fund"),
                },
            }),
        }
    },
    methods: {},
    name: "FundResource",
}
</script>
