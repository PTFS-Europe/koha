<script>
import BaseResource from "../../BaseResource.vue"
import { APIClient } from "../../../fetch/api-client.js"

export default {
    extends: BaseResource,
    setup(props) {
        return {
            ...BaseResource.setup({
                resource_name: "fiscal_period",
                name_attr: "code",
                id_attr: "fiscal_period_id",
                show_component: "FiscalPeriodShow",
                list_component: "FiscalPeriodList",
                add_component: "FiscalPeriodFormAdd",
                edit_component: "FiscalPeriodFormAddEdit",
                api_client: APIClient.acquisition.fiscalPeriods,
                resource_table_url:
                    APIClient.acquisition._baseURL + "fiscal_periods",
                i18n: {
                    display_name: __("Fiscal period"),
                },
            }),
        }
    },
    methods: {},
    name: "FiscalPeriodResource",
}
</script>
