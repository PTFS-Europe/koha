<script>
import BaseResource from "../BaseResource.vue"
import { APIClient } from "../../fetch/api-client.js"

export default {
    extends: BaseResource,
    setup(props) {
        return {
            ...BaseResource.setup({
                resource_name: "institution",
                name_attr: "name",
                id_attr: "sip_institution_id",
                show_component: "SIP2InstitutionsShow",
                list_component: "SIP2InstitutionsList",
                add_component: "SIP2InstitutionsFormAdd",
                edit_component: "SIP2InstitutionsFormAddEdit",
                api_client: APIClient.sip2.institutions,
                resource_table_url: APIClient.sip2._baseURL + "institutions",
                i18n: {
                    display_name: __("Institution"),
                },
            }),
        }
    },
    methods: {},
    name: "SIP2InstitutionResource",
}
</script>
