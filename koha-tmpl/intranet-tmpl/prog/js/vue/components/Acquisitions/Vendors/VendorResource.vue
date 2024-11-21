<script>
import BaseResource from "../../BaseResource.vue"
import { APIClient } from "../../../fetch/api-client.js"

export default {
    extends: BaseResource,
    setup(props) {
        return {
            ...BaseResource.setup({
                resource_name: "vendor",
                name_attr: "name",
                id_attr: "id",
                show_component: "VendorShow",
                list_component: "VendorList",
                add_component: "VendorFormAdd",
                edit_component: "VendorFormAddEdit",
                api_client: APIClient.acquisition.vendors,
                resource_table_url: APIClient.acquisition._baseURL + "vendors",
                i18n: {
                    display_name: __("Vendor"),
                },
            }),
            //AgreementResource specific setup here
        }
    },
    methods: {},
    name: "VendorResource",
}
</script>
