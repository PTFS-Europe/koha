<template>
    <div id="menu" v-if="vendorId">
        <ul>
            <li
                v-if="
                    ordermanage ||
                    isUserPermitted('CAN_user_acquisition_order_manage')
                "
            >
                <a
                    :href="`/cgi-bin/koha/acqui/booksellers.pl?booksellerid=${vendorId}`"
                    >{{ $__("Baskets") }}</a
                >
            </li>
            <li
                v-if="
                    groupmanage ||
                    isUserPermitted('CAN_user_acquisition_group_manage')
                "
            >
                <a
                    :href="`/cgi-bin/koha/acqui/basketgroup.pl?booksellerid=${vendorId}`"
                    >{{ $__("Basket groups") }}</a
                >
            </li>
            <li
                v-if="
                    contractsmanage ||
                    isUserPermitted('CAN_user_acquisition_contracts_manage')
                "
            >
                <a
                    :href="`/cgi-bin/koha/admin/aqcontract.pl?booksellerid=${vendorId}`"
                    >{{ $__("Contracts") }}</a
                >
            </li>
            <li
                v-if="
                    issuemanage ||
                    isUserPermitted('CAN_user_acquisition_issue_manage')
                "
            >
                <a
                    :href="`/cgi-bin/koha/acqui/vendor_issues.pl?booksellerid=${vendorId}`"
                    >{{ $__("Vendor issues") }}</a
                >
            </li>
            <li>
                <a
                    :href="`/cgi-bin/koha/acqui/invoices.pl?supplierid=${vendorId}&amp;op=do_search`"
                    >{{ $__("Invoices") }}</a
                >
            </li>
            <li
                v-if="
                    ordermanage ||
                    isUserPermitted('CAN_user_acquisition_order_manage')
                "
            >
                <a
                    v-if="basketno"
                    :href="`/cgi-bin/koha/acqui/uncertainprice.pl?booksellerid=${vendorId}&amp;basketno=${basketno}&amp;owner=1`"
                    >{{ $__("Uncertain prices") }}</a
                >
                <a
                    v-else
                    :href="`/cgi-bin/koha/acqui/uncertainprice.pl?booksellerid=${vendorId}&amp;owner=1`"
                    >{{ $__("Uncertain prices") }}</a
                >
            </li>
            <li v-if="ermModule && (erm || isUserPermitted('CAN_user_erm'))">
                <a
                    :href="`/cgi-bin/koha/erm/agreements?vendor_id=${vendorId}`"
                    >{{ $__("ERM agreements") }}</a
                >
            </li>
            <li v-if="ermModule && (erm || isUserPermitted('CAN_user_erm'))">
                <a :href="`/cgi-bin/koha/erm/licenses?vendor_id=${vendorId}`">{{
                    $__("ERM licenses")
                }}</a>
            </li>
        </ul>
    </div>
</template>

<script>
import { inject } from "vue"
import { storeToRefs } from "pinia"

export default {
    props: {
        vendorid: {
            type: String,
        },
        basketno: {
            type: String,
        },
        ordermanage: {
            type: String,
        },
        groupmanage: {
            type: String,
        },
        contractsmanage: {
            type: String,
        },
        issuemanage: {
            type: String,
        },
        ermmodule: {
            type: String,
        },
        erm: {
            type: String,
        },
    },
    setup() {
        const permissionsStore = inject("permissionsStore")
        const { isUserPermitted } = permissionsStore
        const navigationStore = inject("navigationStore")
        const { params } = storeToRefs(navigationStore)
        const vendorStore = inject("vendorStore")
        const { config } = storeToRefs(vendorStore)

        return {
            isUserPermitted,
            params,
            config,
        }
    },
    data() {
        const vendorId = this.vendorid ? this.vendorid : this.params.id
        const ermModule = this.ermmodule
            ? this.ermmodule
            : this.config.settings.ermModule
        return {
            vendorId,
            ermModule,
        }
    },
}
</script>

<style></style>
