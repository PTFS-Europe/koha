<template>
    <Toolbar>
        <ToolbarLink
            :to="{ name: 'FiscalPeriodList' }"
            icon="pen-to-square"
            :title="$__('Manage fiscal periods')"
            v-if="isUserPermitted('manageFiscalPeriods')"
        />
        <ToolbarLink
            :to="{ name: 'LedgerList' }"
            icon="pen-to-square"
            :title="$__('Manage ledgers')"
            v-if="isUserPermitted('manageLedgers')"
        />
        <ToolbarLink
            :to="{ name: 'FundGroupList' }"
            icon="pen-to-square"
            :title="$__('Manage fund groups')"
            v-if="isUserPermitted('manageFundGroups')"
        />
        <ToolbarLink
            :to="{ name: 'FundList' }"
            icon="pen-to-square"
            :title="$__('Manage funds')"
            v-if="isUserPermitted('manageFunds')"
        />
    </Toolbar>
    <div v-if="initialized">
        <h1>{{ $__("Funds and ledgers") }}</h1>
        <fieldset class="filters">
            <h2>{{ $__("Filters") }}</h2>
            <div class="filters-grid">
                <div class="filter-grid-cell">
                    <label for="status" class="filter-label"
                        >{{ $__("Status") }}:</label
                    >
                    <v-select
                        id="status"
                        v-model="filters.status"
                        :reduce="av => av.value"
                        :options="statusOptions"
                        label="description"
                    >
                        <template #search="{ attributes, events }">
                            <input
                                class="vs__search"
                                v-bind="attributes"
                                v-on="events"
                            />
                        </template>
                    </v-select>
                </div>
                <div class="filter-grid-cell">
                    <label for="fund_fund_type" class="filter-label"
                        >{{ $__("Fund type") }}:</label
                    >
                    <v-select
                        id="fund_fund_type"
                        v-model="filters.fund_type"
                        :reduce="av => av.value"
                        :options="acquire_fund_types"
                        label="description"
                    >
                        <template #search="{ attributes, events }">
                            <input
                                class="vs__search"
                                v-bind="attributes"
                                v-on="events"
                            />
                        </template>
                    </v-select>
                </div>
                <div class="filter-grid-cell">
                    <label for="fund_fund_group" class="filter-label"
                        >{{ $__("Fund group") }}:</label
                    >
                    <v-select
                        id="fund_fund_group"
                        v-model="filters.fund_group"
                        :reduce="av => av.fund_group_id"
                        :options="fundGroups"
                        label="name"
                    >
                        <template #search="{ attributes, events }">
                            <input
                                class="vs__search"
                                v-bind="attributes"
                                v-on="events"
                            />
                        </template>
                    </v-select>
                </div>
                <div class="filter-grid-cell">
                    <label for="owner" class="filter-label"
                        >{{ $__("Owner") }}:</label
                    >
                    <v-select
                        id="owner"
                        v-model="filters.owner_id"
                        :reduce="av => av.borrowernumber"
                        :options="getOwners"
                        label="displayName"
                    >
                        <template #search="{ attributes, events }">
                            <input
                                class="vs__search"
                                v-bind="attributes"
                                v-on="events"
                            />
                        </template>
                    </v-select>
                </div>
                <div class="filter-grid-cell">
                    <label for="fiscal_period" class="filter-label"
                        >{{ $__("Fiscal period") }}:</label
                    >
                    <InfiniteScrollSelect
                        id="fiscal_period"
                        v-model="filters.fiscal_period_id"
                        :selectedData="null"
                        dataType="fiscalPeriods"
                        dataIdentifier="fiscal_period_id"
                        label="code"
                        apiClient="acquisition"
                        :filters="filterLimitations"
                        :disabled="filters.ledger_id"
                    />
                </div>
                <div class="filter-grid-cell">
                    <label for="ledger" class="filter-label"
                        >{{ $__("Ledger") }}:</label
                    >
                    <InfiniteScrollSelect
                        id="ledger"
                        v-model="filters.ledger_id"
                        :selectedData="null"
                        dataType="ledgers"
                        dataIdentifier="ledger_id"
                        label="name"
                        apiClient="acquisition"
                        :filters="filterLimitations"
                    />
                </div>
            </div>
            <input
                @click="filterTables"
                id="filter_table"
                type="button"
                value="Filter"
            />
            <input
                @click="clearFilters"
                id="clear_filters"
                type="button"
                value="Clear"
                style="margin-left: 0.5em"
            />
        </fieldset>
        <div class="ledgers-and-funds">
            <div class="page-section flex-table">
                <h2>{{ $__("Ledgers") }}</h2>
                <KohaTable
                    ref="ledgersTable"
                    v-bind="tableOptionsLedgers"
                ></KohaTable>
            </div>
            <div class="page-section flex-table" style="margin-top: 0px">
                <h2>{{ $__("Funds") }}</h2>
                <KohaTable
                    ref="fundsTable"
                    v-bind="tableOptionsFunds"
                ></KohaTable>
            </div>
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarLink from "../../ToolbarLink.vue"
import KohaTable from "../../KohaTable.vue"
import InfiniteScrollSelect from "../../InfiniteScrollSelect.vue"
import { inject, ref } from "vue"
import { storeToRefs } from "pinia"
import { APIClient } from "../../../fetch/api-client.js"

export default {
    setup() {
        const acquisitionsStore = inject("acquisitionsStore")
        const { isUserPermitted } = acquisitionsStore
        const { getOwners } = storeToRefs(acquisitionsStore)

        const AVStore = inject("AVStore")
        const { acquire_fund_types } = storeToRefs(AVStore)

        const ledgersTable = ref()
        const fundsTable = ref()

        return {
            isUserPermitted,
            ledgersTable,
            fundsTable,
            acquire_fund_types,
            getOwners,
        }
    },
    data() {
        return {
            tableOptionsLedgers: {
                columns: this.getTableColumns("ledger"),
                url: this.tableUrl("ledgers"),
                options: {
                    dom: '<"top pager"<"table_entries"ip>>tr<"bottom pager"ip>',
                },
                table_settings: null,
                add_filters: true,
            },
            tableOptionsFunds: {
                columns: this.getTableColumns("fund"),
                url: this.tableUrl("funds"),
                options: {
                    dom: '<"top pager"<"table_entries"ip>>tr<"bottom pager"ip>',
                },
                table_settings: null,
                add_filters: true,
            },
            filters: {
                status: null,
                fund_type: null,
                fund_group: null,
                owner_id: null,
                fiscal_period_id: null,
                ledger_id: null,
            },
            statusOptions: [
                { description: this.$__("Active"), value: true },
                { description: this.$__("Inactive"), value: false },
            ],
            fundGroups: [],
            initialized: false,
        }
    },
    computed: {
        filterLimitations() {
            const filterLimitations = {}
            Object.keys(this.filters)
                .filter(key => !["fund_type", "fund_group"].includes(key))
                .forEach(key => {
                    if (this.filters[key]) {
                        filterLimitations[key] = this.filters[key]
                    }
                })
            return filterLimitations
        },
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getFundGroups()
        })
    },
    methods: {
        async getFundGroups() {
            const client = APIClient.acquisition
            await client.fundGroups.getAll().then(
                fundGroups => {
                    this.fundGroups = fundGroups
                    this.initialized = true
                },
                error => {}
            )
        },
        tableUrl(type, query) {
            let url = `/api/v1/acquisitions/${type}`
            if (query) {
                url = url + "?q=" + JSON.stringify(query)
            }
            return url
        },
        getTableColumns: function (dataType) {
            return [
                {
                    title: __("Name"),
                    data: `name:${dataType}_id`,
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        const key = `${dataType}_id`
                        return (
                            `<a href="/cgi-bin/koha/fund_management/${dataType}/` +
                            row[key] +
                            '" class="show">' +
                            escape_str(`${row.name}`) +
                            "</a>"
                        )
                    },
                },
                {
                    title: __("Code"),
                    data: "code",
                    searchable: true,
                    orderable: true,
                },
            ]
        },
        filterTables() {
            const filters = JSON.parse(JSON.stringify(this.filters))
            Object.keys(filters).forEach(key => {
                if (filters[key] === null) {
                    delete filters[key]
                }
            })
            this.$refs.fundsTable.redraw(this.tableUrl("funds", filters))
            if (filters.hasOwnProperty("fund_type")) {
                delete filters.fund_type
            }
            if (filters.hasOwnProperty("fund_group")) {
                delete filters.fund_group
            }
            this.$refs.ledgersTable.redraw(this.tableUrl("ledgers", filters))
        },
        clearFilters() {
            this.filters = {
                status: null,
                fund_type: null,
                owner_id: null,
                fiscal_period_id: null,
                ledger_id: null,
            }
        },
    },
    components: {
        Toolbar,
        ToolbarLink,
        KohaTable,
        InfiniteScrollSelect,
    },
}
</script>

<style scoped>
.ledgers-and-funds {
    display: flex;
    gap: 1em;
    width: 100%;
}
.flex-table {
    margin-top: 0px;
    width: 50%;
}
.filters-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    padding: 1em;
    gap: 1em;
    width: 90%;
}
.filter-grid-cell {
    display: flex;
    gap: 1em;
    justify-content: centre;
    width: 100%;
}
.filter-label {
    min-width: 25%;
}
.v-select,
input:not([type="submit"]):not([type="search"]):not([type="button"]):not([type="checkbox"]),
textarea {
    border-color: rgba(60, 60, 60, 0.26);
    border-width: 1px;
    border-radius: 4px;
    min-width: 60%;
}
</style>
