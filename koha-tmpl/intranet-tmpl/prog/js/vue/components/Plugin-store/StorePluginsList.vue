<template>
    <div id="store_plugins_list">
        <div class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @install="doInstall"
            ></KohaTable>
        </div>
    </div>
</template>

<script>
import { APIClient } from "../../fetch/api-client.js"
import Toolbar from "../Toolbar.vue"
import ToolbarButton from "../ToolbarButton.vue"
import KohaTable from "../KohaTable.vue"

export default {
    data: function () {
        return {
            tableOptions: {
                columns: [
                    {
                        title: "Thumbnail",
                        data: "thumbnail",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row, meta) {
                            return (
                                '<img src = "http://localhost:3000/img/' +
                                row.thumbnail +
                                '" width="180"/>'
                            )
                        },
                    },
                    {
                        title: "Name",
                        data: "name",
                        searchable: false,
                        orderable: false,
                    },
                    {
                        title: "Description",
                        data: "description",
                        searchable: false,
                        orderable: false,
                    },
                    {
                        title: "Author",
                        data: "author",
                        searchable: false,
                        orderable: false,
                    },
                ],
                url: () => this.table_url(),
                // FIXME: Use table settings instead, something like:
                // [% TablesSettings.GetTableSettings( 'pluginstore', 'plugins', 'plugins', 'json' ) | $raw %];
                table_settings: {
                    columns: [
                        {
                            is_hidden: 0,
                            cannot_be_modified: 0,
                            cannot_be_toggled: 0,
                            columnname: "thumbnail",
                        },
                        {
                            is_hidden: 0,
                            cannot_be_modified: 0,
                            cannot_be_toggled: 0,
                            columnname: "name",
                        },
                        {
                            is_hidden: 0,
                            cannot_be_modified: 0,
                            cannot_be_toggled: 0,
                            columnname: "description",
                        },
                        {
                            is_hidden: 0,
                            cannot_be_modified: 0,
                            cannot_be_toggled: 0,
                            columnname: "author",
                        },
                    ],
                    default_display_length: null,
                    module: "store-plugins",
                    default_sort_order: null,
                    table: "store-plugins",
                    page: "store-plugins",
                },
                actions: {
                    "-1": [
                        {
                            install: {
                                text: this.$__("Install"),
                                icon: "fa fa-download",
                            },
                        },
                    ],
                },
                default_filters: {},
            },
            before_route_entered: false,
            building_table: false,
        }
    },
    methods: {
        doInstall: function (plugin, dt, event) {
            //FIXME: This is installing the first release, not checking any koha version or anything
            const client = APIClient.plugin_store
            client.plugins
                .create({
                    kpz_url: plugin.releases[0].kpz_url,
                })
                .then(
                    res => {
                        console.log(res)
                    },
                    error => {}
                )
        },
        table_url: function () {
            // FIXME: This is hardcoded
            return "http://localhost:3000/api/plugins"
        },
    },
    components: { Toolbar, ToolbarButton, KohaTable },
    name: "StorePluginsList",
}
</script>
