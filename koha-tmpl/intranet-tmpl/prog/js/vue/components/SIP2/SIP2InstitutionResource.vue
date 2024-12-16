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
    data() {
        return {
            resource_attrs: [
                {
                    name: "name",
                    required: true,
                    type: "text",
                    label: __("Name"),
                    show_in_table: true,
                },
                {
                    name: "implementation",
                    required: true,
                    type: "text",
                    label: __("Implementation"),
                    show_in_table: true,
                },
                {
                    name: "checkin",
                    type: "boolean",
                    label: __("Checkin"),
                    show_in_table: true,
                },
                {
                    name: "checkout",
                    type: "boolean",
                    label: __("Checkout"),
                    show_in_table: true,
                },
                {
                    name: "renewal",
                    type: "boolean",
                    label: __("Renewal"),
                    show_in_table: true,
                },
                {
                    name: "retries",
                    required: true,
                    type: "text",
                    label: __("Retries"),
                    show_in_table: true,
                },
                {
                    name: "status_update",
                    required: true,
                    type: "boolean",
                    label: __("Status update"),
                    show_in_table: true,
                },
                {
                    name: "timeout",
                    required: true,
                    type: "text",
                    label: __("Timeout"),
                    show_in_table: true,
                },
            ],
        }
    },
    methods: {},
    name: "SIP2InstitutionResource",
}
</script>
