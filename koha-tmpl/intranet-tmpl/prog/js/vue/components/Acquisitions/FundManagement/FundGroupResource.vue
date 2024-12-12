<script>
import BaseResource from "../../BaseResource.vue"
import { APIClient } from "../../../fetch/api-client.js"

export default {
    extends: BaseResource,
    setup(props) {
        return {
            ...BaseResource.setup({
                resource_name: "fund_group",
                name_attr: "name",
                id_attr: "fund_group_id",
                show_component: "FundGroupShow",
                list_component: "FundGroupList",
                add_component: "FundGroupFormAdd",
                edit_component: "FundGroupFormAddEdit",
                api_client: APIClient.acquisition.fund_groups,
                resource_table_url:
                    APIClient.acquisition._baseURL + "fund_groups",
                i18n: {
                    display_name: __("Fund group"),
                },
            }),
        }
    },
    methods: {},
    name: "FundGroupResource",
}
</script>
