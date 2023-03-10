<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else-if="titles" id="titles_list">
        <div v-if="titles.length" class="page-section">
            <table :id="table_id"></table>
        </div>
        <div v-else-if="initialized" class="dialog message">
            {{ $__("There are no titles defined") }}
        </div>
    </div>
</template>

<script>
import { APIClient } from "../../fetch/api-client.js"
import { useDataTable } from "../../composables/datatables"

export default {
    setup() {
        const table_id = "title_list"
        useDataTable(table_id)

        return {
            table_id,
        }
    },
    data: function () {
        return {
            titles: [],
            initialized: false,
            before_route_entered: false,
            building_table: false,
        }
    },
    computed: {
        datatable_url() {
            let url = `/api/v1/erm/yearly_usage?platform_id=${this.$route.params.platform_id}`
            return url
        },
    },
    methods: {
        async getTitles() {
            const client = APIClient.erm
            await client.titles.getAll().then(
                titles => {
                    this.titles = titles
                    this.initialized = true
                },
                error => {}
            )
        },
        table_url: function () {},
        build_datatable: function () {
            let datatable_url = this.datatable_url
            let default_search = this.$route.query.q
            let table_id = this.table_id
            let titles = this.titles

            const table = $("#" + table_id).kohaTable(
                {
                    ajax: {
                        url: datatable_url,
                    },
                    order: [[0, "asc"]],
                    autoWidth: false,
                    search: { search: default_search },
                    columnDefs: [
                        {
                            targets: [0, 1],
                            render: function (data, type, row, meta) {
                                if (type == "display") {
                                    return escape_str(data)
                                }
                                return data
                            },
                        },
                    ],
                    columns: [
                        {
                            title: __("Id"),
                            data: "title_id",
                            searchable: true,
                            orderable: true,
                        },
                        {
                            title: __("Title"),
                            render: function (data, type, row, meta) {
                                const row_id = row.title_id
                                const matched_title_id = titles.find(
                                    title => title.title_id === row_id
                                )
                                return matched_title_id.title
                            },
                            searchable: true,
                            orderable: true,
                        },
                    ],
                },
                title_table_settings,
                1
            )
        },
    },
    mounted() {
        if (!this.building_table) {
            this.building_table = true
            this.getTitles().then(() => this.build_datatable())
        }
    },
    name: "UsageStatisticsTitlesList",
}
</script>

<style scoped>
#title_list {
    display: table;
}
</style>
