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
    methods: {
        goToSubFundEdit: function (subFund) {
            this.$router.push({
                name: "SubFundFormAddEdit",
                params: {
                    fund_id: subFund.fund_id,
                    sub_fund_id: subFund.sub_fund_id,
                },
            })
        },
        doSubFundDelete: function (subFund) {
            let resource_id = subFund.sub_fund_id
            let resource_name = subFund.name

            this.setConfirmationDialog(
                {
                    title: this.$__(
                        "Are you sure you want to remove this sub fund?"
                    ),
                    message: resource_name,
                    accept_label: this.$__("Yes, delete"),
                    cancel_label: this.$__("No, do not delete"),
                },
                () => {
                    APIClient.acquisition.subFunds.delete(resource_id).then(
                        success => {
                            this.setMessage(
                                this.$__("Sub fund %s deleted").format(
                                    resource_name
                                ),
                                true
                            )
                            if (typeof callback === "function") {
                                callback()
                            } else {
                                if (
                                    this.$options.name === this.list_component
                                ) {
                                    this.$refs.table.redraw(
                                        this.getResourceTableUrl()
                                    )
                                } else if (
                                    this.$options.name === this.show_component
                                ) {
                                    this.goToResourceList()
                                }
                            }
                        },
                        error => {}
                    )
                }
            )
        },
    },
    name: "FundResource",
}
</script>
