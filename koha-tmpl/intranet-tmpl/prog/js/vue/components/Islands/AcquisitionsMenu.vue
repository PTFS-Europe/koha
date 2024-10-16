<template>
    <div id="navmenu">
        <div id="navmenulist">
            <h5>{{ $__("Acquisitions") }}</h5>
            <ul>
                <li>
                    <a href="/cgi-bin/koha/acqui/acqui-home.pl">{{
                        $__("Acquisitions home")
                    }}</a>
                </li>
                <li>
                    <a href="/cgi-bin/koha/acqui/histsearch.pl">{{
                        $__("Advanced search")
                    }}</a>
                </li>
                <li
                    v-if="
                        orderreceive ||
                        isUserPermitted('CAN_user_acquisition_order_receive')
                    "
                >
                    <a href="/cgi-bin/koha/acqui/lateorders.pl">{{
                        $__("Late orders")
                    }}</a>
                </li>
                <li
                    v-if="
                        suggestionscreate ||
                        suggestionsmanage ||
                        suggestionsdelete ||
                        isUserPermitted(
                            'CAN_user_suggestions_suggestions_create'
                        ) ||
                        isUserPermitted(
                            'CAN_user_suggestions_suggestions_manage'
                        ) ||
                        isUserPermitted(
                            'CAN_user_suggestions_suggestions_delete'
                        )
                    "
                >
                    <a href="/cgi-bin/koha/suggestion/suggestion.pl">{{
                        $__("Suggestions")
                    }}</a>
                </li>
                <li>
                    <a href="/cgi-bin/koha/acqui/invoices.pl">{{
                        $__("Invoices")
                    }}</a>
                </li>
                <li
                    v-if="
                        edifactEnabled &&
                        (edimanage ||
                            isUserPermitted('CAN_user_acquisition_edi_manage'))
                    "
                >
                    <a href="/cgi-bin/koha/acqui/edifactmsgs.pl">{{
                        $__("EDIFACT messages")
                    }}</a>
                </li>
            </ul>
            <template
                v-if="
                    reports ||
                    circulateremainingpositions ||
                    isUserPermitted('CAN_user_reports') ||
                    isUserPermitted(
                        'CAN_user_circulate_circulate_remaining_permissions'
                    )
                "
            >
                <h5>{{ $__("Reports") }}</h5>
                <ul>
                    <template
                        v-if="reports || isUserPermitted('CAN_user_reports')"
                    >
                        <li>
                            <a
                                href="/cgi-bin/koha/reports/acquisitions_stats.pl"
                                >{{ $__("Acquisitions statistics wizard") }}</a
                            >
                        </li>
                        <li>
                            <a href="/cgi-bin/koha/reports/orders_by_fund.pl">{{
                                $__("Orders by fund")
                            }}</a>
                        </li>
                    </template>
                    <li
                        v-if="
                            circulateremainingpositions ||
                            isUserPermitted(
                                'CAN_user_circulate_circulate_remaining_permissions'
                            )
                        "
                    >
                        <a href="/cgi-bin/koha/circ/reserveratios.pl">{{
                            $__("Hold ratios")
                        }}</a>
                    </li>
                </ul>
            </template>
            <template
                v-if="
                    periodmanage ||
                    isUserPermitted('CAN_user_acquisition_period_manage') ||
                    budgetmanage ||
                    isUserPermitted('CAN_user_acquisition_budget_manage') ||
                    currenciesmanage ||
                    isUserPermitted('CAN_user_acquisition_currencies_manage') ||
                    (edifactEnabled &&
                        (edimanage ||
                            isUserPermitted(
                                'CAN_user_acquisition_edi_manage'
                            ))) ||
                    manageadditionalfields ||
                    isUserPermitted('CAN_user_acquisition_edi_manage')
                "
            >
                <h5>{{ $__("Administration") }}</h5>
                <ul>
                    <li
                        v-if="
                            periodmanage ||
                            isUserPermitted(
                                'CAN_user_acquisition_period_manage'
                            )
                        "
                    >
                        <a href="/cgi-bin/koha/admin/aqbudgetperiods.pl">{{
                            $__("Budgets")
                        }}</a>
                    </li>
                    <li
                        v-if="
                            budgetmanage ||
                            isUserPermitted(
                                'CAN_user_acquisition_budget_manage'
                            )
                        "
                    >
                        <a href="/cgi-bin/koha/admin/aqbudgets.pl">{{
                            $__("Funds")
                        }}</a>
                    </li>
                    <li
                        v-if="
                            currenciesmanage ||
                            isUserPermitted(
                                'CAN_user_acquisition_currencies_manage'
                            )
                        "
                    >
                        <a href="/cgi-bin/koha/admin/currency.pl">{{
                            $__("Currencies")
                        }}</a>
                    </li>
                    <template
                        v-if="
                            (edifactEnabled && edimanage) ||
                            (edifactEnabled &&
                                isUserPermitted(
                                    'CAN_user_acquisition_edi_manage'
                                ))
                        "
                    >
                        <li>
                            <a href="/cgi-bin/koha/admin/edi_accounts.pl">{{
                                $__("EDI accounts")
                            }}</a>
                        </li>
                        <li>
                            <a href="/cgi-bin/koha/admin/edi_ean_accounts.pl">{{
                                $__("Library EANs")
                            }}</a>
                        </li>
                    </template>
                    <li
                        v-if="
                            manageadditionalfields ||
                            isUserPermitted(
                                'CAN_user_parameters_manage_additional_fields'
                            ) ||
                            invoiceedit ||
                            isUserPermitted(
                                'CAN_user_acquisition_edit_invoices'
                            )
                        "
                    >
                        <a
                            href="/cgi-bin/koha/admin/additional-fields.pl?tablename=aqinvoices"
                            >{{ $__("Manage invoice fields") }}</a
                        >
                    </li>
                    <template
                        v-if="
                            (manageadditionalfields ||
                                isUserPermitted(
                                    'CAN_user_parameters_manage_additional_fields'
                                )) &&
                            (ordermanage ||
                                isUserPermitted(
                                    'CAN_user_acquisition_order_manage'
                                ))
                        "
                    >
                        <li>
                            <a
                                href="/cgi-bin/koha/admin/additional-fields.pl?tablename=aqbasket"
                                >{{ $__("Manage order basket fields") }}</a
                            >
                        </li>
                        <li>
                            <a
                                href="/cgi-bin/koha/admin/additional-fields.pl?tablename=aqorders"
                                >{{ $__("Manage order line fields") }}</a
                            >
                        </li>
                    </template>
                </ul>
            </template>
        </div>
    </div>
</template>

<script>
import { inject } from "vue"
import { storeToRefs } from "pinia"

export default {
    props: {
        ordermanage: {
            type: String,
        },
        orderreceive: {
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
        edifact: {
            type: String,
        },
        edimanage: {
            type: String,
        },
        reports: {
            type: String,
        },
        circulateremainingpositions: {
            type: String,
        },
        periodmanage: {
            type: String,
        },
        budgetmanage: {
            type: String,
        },
        currenciesmanage: {
            type: String,
        },
        manageadditionalfields: {
            type: String,
        },
        invoiceedit: {
            type: String,
        },
        suggestionscreate: {
            type: String,
        },
        suggestionsmanage: {
            type: String,
        },
        suggestionsdelete: {
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
        const edifactEnabled = this.config.settings.edifact
            ? this.config.settings.edifact
            : this.edifact

        return {
            edifactEnabled,
        }
    },
}
</script>

<style></style>
