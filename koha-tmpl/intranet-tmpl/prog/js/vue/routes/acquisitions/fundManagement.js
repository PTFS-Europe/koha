import { markRaw } from "vue";

import Homepage from "../../components/Acquisitions/FundManagement/Homepage.vue";
import FundManagementHome from "../../components/Acquisitions/FundManagement/FundManagementHome.vue";
import FiscalPeriodList from "../../components/Acquisitions/FundManagement/FiscalPeriodList.vue";
import FiscalPeriodShow from "../../components/Acquisitions/FundManagement/FiscalPeriodShow.vue";
import FiscalPeriodFormAdd from "../../components/Acquisitions/FundManagement/FiscalPeriodFormAdd.vue";
import LedgerList from "../../components/Acquisitions/FundManagement/LedgerList.vue";
import LedgerShow from "../../components/Acquisitions/FundManagement/LedgerShow.vue";
import LedgerFormAdd from "../../components/Acquisitions/FundManagement/LedgerFormAdd.vue";
import FundList from "../../components/Acquisitions/FundManagement/FundList.vue";
import FundShow from "../../components/Acquisitions/FundManagement/FundShow.vue";
import FundFormAdd from "../../components/Acquisitions/FundManagement/FundFormAdd.vue";
import SubFundFormAdd from "../../components/Acquisitions/FundManagement/SubFundFormAdd.vue";
import FundGroupList from "../../components/Acquisitions/FundManagement/FundGroupList.vue";
import FundGroupShow from "../../components/Acquisitions/FundManagement/FundGroupShow.vue";
import FundGroupFormAdd from "../../components/Acquisitions/FundManagement/FundGroupFormAdd.vue";
import FundAllocationShow from "../../components/Acquisitions/FundManagement/FundAllocationShow.vue";
import FundAllocationFormAdd from "../../components/Acquisitions/FundManagement/FundAllocationFormAdd.vue";
import TransferFunds from "../../components/Acquisitions/FundManagement/TransferFunds.vue";

import { $__ } from "../../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/acqui/acqui-home.pl",
        is_default: true,
        is_base: true,
        title: $__("Acquisitions"),
        children: [
            {
                path: "",
                name: "Home",
                component: markRaw(Homepage),
                is_navigation_item: false,
            },
            {
                path: "/cgi-bin/koha/fund_management",
                moduleName: "funds",
                title: "Funds and ledgers",
                icon: "fa fa-money-check-dollar",
                children: [
                    {
                        path: "",
                        component: markRaw(FundManagementHome),
                        name: "FundManagementHome",
                        is_navigation_item: false,
                    },
                    {
                        path: "fiscal_period",
                        title: "Fiscal periods",
                        is_navigation_item: false,
                        children: [
                            {
                                path: "",
                                component: markRaw(FiscalPeriodList),
                                name: "FiscalPeriodList",
                                title: "List fiscal periods",
                                permission: "manageFiscalPeriods",
                            },
                            {
                                path: ":fiscal_period_id",
                                component: markRaw(FiscalPeriodShow),
                                name: "FiscalPeriodShow",
                                title: "Show fiscal period",
                                permission: "manageFiscalPeriods",
                            },
                            {
                                path: "add",
                                component: markRaw(FiscalPeriodFormAdd),
                                name: "FiscalPeriodFormAdd",
                                title: "Add fiscal period",
                                permission: "createFiscalPeriods",
                            },
                            {
                                path: "edit/:fiscal_period_id",
                                component: markRaw(FiscalPeriodFormAdd),
                                name: "FiscalPeriodFormAddEdit",
                                title: "Edit fiscal period",
                                permission: "editFiscalPeriod",
                            },
                        ],
                    },
                    {
                        path: "ledger",
                        title: "Ledgers",
                        is_navigation_item: false,
                        children: [
                            {
                                path: "",
                                component: markRaw(LedgerList),
                                name: "LedgerList",
                                title: "List ledgers",
                                permission: "manageLedgers",
                            },
                            {
                                path: ":ledger_id",
                                component: markRaw(LedgerShow),
                                name: "LedgerShow",
                                title: "Show ledger",
                                permission: "manageLedgers",
                            },
                            {
                                path: "add",
                                component: markRaw(LedgerFormAdd),
                                name: "LedgerFormAdd",
                                title: "Add ledger",
                                permission: "createLedger",
                            },
                            {
                                path: "edit/:ledger_id",
                                component: markRaw(LedgerFormAdd),
                                name: "LedgerFormAddEdit",
                                title: "Edit ledger",
                                permission: "editLedger",
                            },
                        ],
                    },
                    {
                        path: "fund",
                        title: "Funds",
                        is_navigation_item: false,
                        children: [
                            {
                                path: "",
                                component: markRaw(FundList),
                                name: "FundList",
                                title: "List funds",
                                permission: "manageFunds",
                            },
                            {
                                path: ":fund_id",
                                component: markRaw(FundShow),
                                name: "FundShow",
                                title: "Show fund",
                                permission: "manageFunds",
                            },
                            {
                                path: "add",
                                component: markRaw(FundFormAdd),
                                name: "FundFormAdd",
                                title: "Add fund",
                                permission: "createFund",
                            },
                            {
                                path: "edit/:fund_id",
                                component: markRaw(FundFormAdd),
                                name: "FundFormAddEdit",
                                title: "Edit fund",
                                permission: "editFund",
                            },
                            {
                                path: ":fund_id/allocation",
                                component: markRaw(FundAllocationShow),
                                name: "FundAllocationShow",
                                title: "Show fund allocation",
                                permission: "manageFundAllocations",
                            },
                            {
                                path: ":fund_id/allocation/edit/:fund_allocation_id",
                                component: markRaw(FundAllocationFormAdd),
                                name: "FundAllocationFormAddEdit",
                                title: "Edit fund allocation",
                                permission: "editFundAllocation",
                            },
                            {
                                path: ":fund_id/:sub_fund_id?/allocate",
                                component: markRaw(FundAllocationFormAdd),
                                name: "FundAllocationFormAdd",
                                title: "Allocate funds",
                                permission: "createFundAllocation",
                            },
                            {
                                path: "transfer",
                                component: markRaw(TransferFunds),
                                name: "TransferFunds",
                                title: "Transfer funds",
                                permission: "createFundAllocation",
                            },
                            {
                                path: ":fund_id/sub_fund/add",
                                component: markRaw(SubFundFormAdd),
                                name: "SubFundFormAdd",
                                title: "Add sub fund",
                                permission: "createFund",
                            },
                            {
                                path: ":fund_id/sub_fund/edit/:sub_fund_id",
                                component: markRaw(SubFundFormAdd),
                                name: "SubFundFormAddEdit",
                                title: "Edit sub fund",
                                permission: "editFund",
                            },
                            {
                                path: "sub_fund/:sub_fund_id",
                                component: markRaw(FundShow),
                                name: "SubFundShow",
                                title: "Show sub fund",
                                permission: "manageFunds",
                            },
                        ],
                    },
                    {
                        path: "fund_group",
                        title: "Fund groups",
                        is_navigation_item: false,
                        children: [
                            {
                                path: "",
                                component: markRaw(FundGroupList),
                                name: "FundGroupList",
                                title: "List fund groups",
                                permission: "manageFundGroups",
                            },
                            {
                                path: ":fund_group_id",
                                component: markRaw(FundGroupShow),
                                name: "FundGroupShow",
                                title: "Show fund group",
                                permission: "manageFundGroups",
                            },
                            {
                                path: "add",
                                component: markRaw(FundGroupFormAdd),
                                name: "FundGroupFormAdd",
                                title: "Add fund group",
                                permission: "createFundGroup",
                            },
                            {
                                path: "edit/:fund_group_id",
                                component: markRaw(FundGroupFormAdd),
                                name: "FundGroupFormAddEdit",
                                title: "Edit fund group",
                                permission: "editFundGroup",
                            },
                        ],
                    },
                ],
            },
        ],
    },
];
