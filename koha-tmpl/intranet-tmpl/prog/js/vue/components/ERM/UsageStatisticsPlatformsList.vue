<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else-if="platforms" id="platforms_list">
        <Toolbar v-if="before_route_entered" />
        <div v-if="platforms.length" class="page-section">
            <table :id="table_id"></table>
        </div>
        <div v-else-if="initialized" class="dialog message">
            {{ $__("There are no platforms defined") }}
        </div>
    </div>
</template>

<script>
import Toolbar from "./UsageStatisticsPlatformsToolbar.vue"
import { inject, createVNode, render } from "vue"
import { APIClient } from "../../fetch/api-client.js"
import { useDataTable } from "../../composables/datatables"

export default {
    setup() {
        const AVStore = inject("AVStore") // Left in for future permissions fixes
        const { get_lib_from_av, map_av_dt_filter } = AVStore

        const table_id = "platform_list"
        useDataTable(table_id)

        return {
            get_lib_from_av,
            map_av_dt_filter,
            table_id,
        }
    },
    data: function () {
        return {
            platforms: [],
            initialized: false,
            before_route_entered: false,
            building_table: false,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.before_route_entered = true // FIXME This is ugly, but we need to distinguish when it's used as main component or child component (from EHoldingsEBSCOPAckagesShow for instance)
            if (!vm.building_table) {
                vm.building_table = true
                vm.getPlatforms().then(() => vm.build_datatable())
            }
        })
    },
    computed: {
        datatable_url() {
            let url = "/api/v1/erm/platforms"
            return url
        },
    },
    methods: {
        async getPlatforms() {
            const client = APIClient.erm
            await client.platforms.getAll().then(
                platforms => {
                    this.platforms = platforms
                    this.initialized = true
                },
                error => {}
            )
        },
        show_platform: function (platform_id) {
            this.$router.push({
                name: "UsageStatisticsPlatformsShow",
                params: { platform_id },
            })
        },
        edit_platform: function (platform_id) {
            this.$router.push({
                name: "UsageStatisticsPlatformsFormAddEdit",
                params: { platform_id },
            })
        },
        delete_platform: function (platform_id) {
            this.$router.push(
                "/cgi-bin/koha/erm/platforms/delete/" + platform_id
            )
        },
        select_platform: function (platform_id) {
            this.$emit("select-platform", platform_id)
            this.$emit("close")
        },
        run_harvester_now: function () {
            // TODO: Harvesting code to go here
        },
        table_url: function () {},
        build_datatable: function () {
            let show_platform = this.show_platform
            let edit_platform = this.edit_platform
            let delete_platform = this.delete_platform
            let select_platform = this.select_platform
            let get_lib_from_av = this.get_lib_from_av // Left in for permissions
            let datatable_url = this.datatable_url
            let default_search = this.$route.query.q
            let actions = this.before_route_entered ? "edit_delete" : "select"
            let table_id = this.table_id

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
                            targets: [0, 2],
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
                            title: __("Name"),
                            data: "me.erm_platform_id:me.name",
                            searchable: true,
                            orderable: true,
                            render: function (data, type, row, meta) {
                                // Rendering done in drawCallback
                                return ""
                            },
                        },
                        {
                            title: __("Description"),
                            data: "description",
                            searchable: true,
                            orderable: true,
                        },
                        {
                            title: __("Run now"),
                            render: function (row, type, val, meta) {
                                return '<div class="run_now"></div>'
                            },
                            className: "run_now noExport",
                            searchable: false,
                            orderable: false,
                        },
                        {
                            title: __("Actions"),
                            data: function (row, type, val, meta) {
                                return '<div class="actions"></div>'
                            },
                            className: "actions noExport",
                            searchable: false,
                            orderable: false,
                        },
                    ],
                    drawCallback: function (settings) {
                        var api = new $.fn.dataTable.Api(settings)

                        if (actions == "edit_delete") {
                            $.each(
                                $(this).find("td .actions"),
                                function (index, e) {
                                    let tr = $(this).parent().parent()
                                    let platform_id = api
                                        .row(tr)
                                        .data().erm_platform_id
                                    let editButton = createVNode(
                                        "a",
                                        {
                                            class: "btn btn-default btn-xs",
                                            role: "button",
                                            onClick: () => {
                                                edit_platform(platform_id)
                                            },
                                        },
                                        [
                                            createVNode("i", {
                                                class: "fa fa-pencil",
                                                "aria-hidden": "true",
                                            }),
                                            __("Edit"),
                                        ]
                                    )

                                    let deleteButton = createVNode(
                                        "a",
                                        {
                                            class: "btn btn-default btn-xs",
                                            role: "button",
                                            onClick: () => {
                                                delete_platform(platform_id)
                                            },
                                        },
                                        [
                                            createVNode("i", {
                                                class: "fa fa-trash",
                                                "aria-hidden": "true",
                                            }),
                                            __("Delete"),
                                        ]
                                    )

                                    let n = createVNode("span", {}, [
                                        editButton,
                                        " ",
                                        deleteButton,
                                    ])
                                    render(n, e)
                                }
                            )
                        } else {
                            $.each(
                                $(this).find("td .actions"),
                                function (index, e) {
                                    let tr = $(this).parent().parent()
                                    let platform_id = api
                                        .row(tr)
                                        .data().platform_id
                                    let selectButton = createVNode(
                                        "a",
                                        {
                                            class: "btn btn-default btn-xs",
                                            role: "button",
                                            onClick: () => {
                                                select_platform(platform_id)
                                            },
                                        },
                                        [
                                            createVNode("i", {
                                                class: "fa fa-check",
                                                "aria-hidden": "true",
                                            }),
                                            __("Select"),
                                        ]
                                    )

                                    let n = createVNode("span", {}, [
                                        selectButton,
                                    ])
                                    render(n, e)
                                }
                            )
                        }

                        $.each(
                            $(this).find("tbody tr td:first-child"),
                            function (index, e) {
                                let tr = $(this).parent()
                                let row = api.row(tr).data()
                                if (!row) return // Happen if the table is empty
                                let n = createVNode(
                                    "a",
                                    {
                                        role: "button",
                                        onClick: () => {
                                            show_platform(row.erm_platform_id)
                                        },
                                    },
                                    `${row.name} (#${row.erm_platform_id})`
                                )
                                render(n, e)
                            }
                        )

                        $.each(
                            $(this).find("td .run_now"),
                            function (index, e) {
                                let runNowButton = createVNode(
                                    "a", // This will depend on how harvester functionality works/whether we want to redirect to another window
                                    {
                                        class: "btn btn-default btn-xs",
                                        role: "button",
                                        onClick: () => {
                                            run_harvester_now()
                                        },
                                    },
                                    [__("Run now")]
                                )
                                let n = createVNode("span", {}, [runNowButton])
                                render(n, e)
                            }
                        )
                    },
                },
                platform_table_settings,
                1
            )
        },
    },
    mounted() {
        if (!this.building_table) {
            this.building_table = true
            this.getPlatforms().then(() => this.build_datatable())
        }
    },
    components: { Toolbar },
    name: "PlatformsList",
    emits: ["select-platform", "close"],
}
</script>

<style scoped>
#platform_list {
    display: table;
}
</style>
