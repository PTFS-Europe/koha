<template>
    <div id="store_plugins_list">
        <div class="btn-toolbar" id="toolbar">
            <a
                href="/cgi-bin/koha/plugins/plugins-home.pl"
                class="btn btn-default"
                ><i class="fa-solid fa-eye"></i> View installed plugins</a
            >
        </div>
        <div class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @install="doInstall"
                @update="doUpdate"
            ></KohaTable>
        </div>
    </div>
</template>

<script>
import { APIClient } from "../../fetch/api-client.js"
import { inject, ref } from "vue"
import Toolbar from "../Toolbar.vue"
import ToolbarButton from "../ToolbarButton.vue"
import KohaTable from "../KohaTable.vue"

export default {
    setup() {
        const { setConfirmationDialog, setMessage, setWarning } =
            inject("mainStore")

        return {
            koha_version,
            installed_plugins,
            setConfirmationDialog,
            setMessage,
            setWarning,
        }
    },
    data: function () {
        let component = this
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
                                '<img style="display:block; margin: 0 auto;" src = "http://localhost:3000/img/' +
                                row.thumbnail +
                                '" width="250px"/>'
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
                    {
                        title: "Latest release",
                        data: "releases",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row, meta) {
                            if (component.pluginHasNoReleases(row)) {
                                return '<span class="badge text-bg-warning"> No releases available for this Koha version!</span>'
                            }
                            if (!data || data.length === 0) return "N/A"
                            let most_recent_release =
                                component.getMostRecentRelease(row)
                            return most_recent_release.version
                        },
                    },
                    {
                        title: "Installed release",
                        data: "releases",
                        searchable: false,
                        orderable: false,
                        render: function (data, type, row, meta) {
                            let installed = component.installed_plugins.find(
                                ip => ip.class === row.class_name
                            )
                            if (!installed) return "N/A"
                            let returnHTML = installed.metadata.version
                            if (
                                !component.installedPluginVersionIsLatest(
                                    installed,
                                    row
                                )
                            ) {
                                returnHTML +=
                                    ' <span class="badge text-bg-warning"> Update available</span>'
                            } else {
                                returnHTML +=
                                    ' <span class="badge text-bg-success"> Up to date!</span>'
                            }
                            return returnHTML
                        },
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
                        {
                            is_hidden: 0,
                            cannot_be_modified: 0,
                            cannot_be_toggled: 0,
                            columnname: "latest_release",
                        },
                        {
                            is_hidden: 0,
                            cannot_be_modified: 0,
                            cannot_be_toggled: 0,
                            columnname: "installed_release",
                        },
                    ],
                    default_display_length: null,
                    module: "store-plugins",
                    default_sort_order: null,
                    table: "store-plugins",
                    page: "store-plugins",
                },
                actions: this.getTableActions(),
                default_filters: {},
            },
            before_route_entered: false,
            building_table: false,
        }
    },
    methods: {
        getTableActions: function () {
            let component = this
            //FIXME: Can't figure out how to get kohatable to wait for installed_plugins before rendering
            return {
                "-1": [
                    {
                        install: {
                            text: this.$__("Install"),
                            icon: "fa fa-download",
                            should_display: function (row) {
                                let installed =
                                    component.installed_plugins.find(
                                        ip => ip.class === row.class_name
                                    )
                                let no_releases =
                                    component.pluginHasNoReleases(row)

                                return installed || no_releases ? 0 : 1
                            },
                        },
                    },
                    {
                        update: {
                            text: this.$__("Update"),
                            icon: "fa fa-refresh",
                            should_display: function (row) {
                                let installed =
                                    component.installed_plugins.find(
                                        ip => ip.class === row.class_name
                                    )
                                if (!installed) return 0
                                if (
                                    !component.installedPluginVersionIsLatest(
                                        installed,
                                        row
                                    )
                                ) {
                                    return 1
                                }
                                return 0
                            },
                        },
                    },
                ],
            }
        },
        doInstall: function (plugin, dt, event) {
            //FIXME: This is installing the most recent release, not checking any koha version or anything
            let most_recent_release = this.getMostRecentRelease(plugin)
            const client = APIClient.plugin_store
            client.plugins
                .create({
                    kpz_url: most_recent_release.kpz_url,
                })
                .then(
                    res => {
                        this.setMessage(
                            this.$__(
                                'Plugin has been installed. <a href="/cgi-bin/koha/plugins/plugins-home.pl">Manage plugins</a>'
                            )
                        )
                    },
                    error => {}
                )
        },
        doUpdate: function (plugin, dt, event) {
            //FIXME: This is installing the first release, not checking any koha version or anything
            let most_recent_release = this.getMostRecentRelease(plugin)
            const client = APIClient.plugin_store
            client.plugins
                .create({
                    kpz_url: most_recent_release.kpz_url,
                })
                .then(
                    res => {
                        this.setMessage(
                            this.$__(
                                'Plugin has been updated. <a href="/cgi-bin/koha/plugins/plugins-home.pl">Manage plugins</a>'
                            )
                        )
                    },
                    error => {}
                )
        },
        installedPluginVersionIsLatest: function (
            installed_plugin,
            candidate_plugin
        ) {
            if (!installed_plugin) {
                return 0
            }
            let most_recent_release =
                this.getMostRecentRelease(candidate_plugin)
            if (
                installed_plugin.metadata.version ===
                most_recent_release.version
            ) {
                return 1
            }
            return 0
        },
        getMostRecentRelease: function (candidate_plugin) {
            return candidate_plugin.releases.reduce(
                (most_recent, release) => {
                    const most_recent_date = new Date(most_recent.date_released)
                    const release_date = new Date(release.date_released)
                    return release_date > most_recent_date
                        ? release
                        : most_recent
                },
                { date_released: 0 }
            )
        },
        pluginHasNoReleases: function (plugin) {
            return !plugin.releases || plugin.releases.length === 0
        },
        table_url: function () {
            // FIXME: This is hardcoded
            return (
                "http://localhost:3000/api/plugins?koha_version_release=" +
                this.koha_version.release
            )
        },
    },
    components: { Toolbar, ToolbarButton, KohaTable },
    name: "StorePluginsList",
}
</script>
<style>
td {
    vertical-align: middle;
}
</style>
