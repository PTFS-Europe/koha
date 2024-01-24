<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="record_sources_list">
        <Toolbar>
            <ToolbarButton
                :to="{ name: 'Add' }"
                icon="plus"
                :title="$__('New record source')"
            />
        </Toolbar>
        <h1>{{ title }}</h1>
        <div v-if="record_sources_count > 0" class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @edit="doEdit"
                @delete="doDelete"
            ></KohaTable>
        </div>
        <div v-else class="dialog message">
            {{ $__("There are no record sources defined") }}
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue"
import ToolbarButton from "../../ToolbarButton.vue"
import { inject } from "vue"
import { RecordSourcesAPIClient } from "../../../fetch/record_sources-api-client"
import KohaTable from "../../KohaTable.vue"
export default {
    name: "List",
    data() {
        return {
            title: this.$__("Record sources"),
            tableOptions: {
                columns: [
                    {
                        title: this.$__("ID"),
                        data: "record_source_id",
                        searchable: true,
                    },
                    {
                        title: this.$__("Name"),
                        data: "name",
                        searchable: true,
                    },
                    {
                        title: __("Can be edited"),
                        data: "can_be_edited",
                        searchable: true,
                        orderable: true,
                        render: function (data, type, row, meta) {
                            return escape_str(
                                row.can_be_edited ? __("Yes") : __("No")
                            )
                        },
                    },
                ],
                actions: {
                    "-1": ["edit", "delete"],
                },
                url: "/api/v1/record_sources",
            },
            initialized: false,
            record_sources_count: 0,
        }
    },
    setup() {
        const { setWarning, setMessage, setError, setConfirmationDialog } =
            inject("mainStore")
        const { record_source } = new RecordSourcesAPIClient()
        return {
            setWarning,
            setMessage,
            setError,
            setConfirmationDialog,
            api: record_source,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getRecordSourcesCount().then(() => (vm.initialized = true))
        })
    },
    methods: {
        async getRecordSourcesCount() {
            const count = await this.api.count()
            this.record_sources_count = count
        },
        newRecordSource() {
            this.$router.push({ path: "record_sources/add" })
        },
        doEdit(data) {
            this.$router.push({
                path: `record_sources/${data.record_source_id}`,
                props: {
                    data,
                },
            })
        },
        doDelete(data, dt) {
            this.setConfirmationDialog(
                {
                    title: this.$__(
                        "Are you sure you want to remove this record source?"
                    ),
                    message: data.name,
                    accept_label: this.$__("Yes, remove"),
                    cancel_label: this.$__("No, do not remove"),
                },
                () => {
                    this.api
                        .delete({
                            id: data.record_source_id,
                        })
                        .then(response => {
                            if (response) {
                                this.setMessage(
                                    this.$__(
                                        "Record source '%s' removed"
                                    ).format(data.name),
                                    true
                                )
                                dt.draw()
                            }
                        })
                }
            )
        },
    },
    components: {
        KohaTable,
        Toolbar,
        ToolbarButton,
    },
}
</script>
