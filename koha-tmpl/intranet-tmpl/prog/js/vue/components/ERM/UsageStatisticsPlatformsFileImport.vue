<template>
    <div class="page-section" id="files">
        <form @submit="addDocument($event)" class="file_upload">
            <h2>Manual import:</h2>
            <label>{{ $__("File") }}:</label>
            <div class="file_information">
                <span v-if="!file.filename">
                    {{ $__("Select a file") }}
                    <input
                        type="file"
                        @change="selectFile($event)"
                        :id="`import_file`"
                        :name="`import_file`"
                    />
                </span>
                <ol>
                    <li v-show="file.filename">
                        {{ $__("File name") }}:
                        <span>{{ file.filename }}</span>
                    </li>
                    <li v-show="file.file_type">
                        {{ $__("File type") }}:
                        <span>{{ file.file_type }}</span>
                    </li>
                </ol>
            </div>
            <label>{{ $__("Report type") }}:</label>
            <v-select
                id="report_type"
                v-model="file.file_type"
                label="description"
                :reduce="av => av.description"
                :options="av_report_types"
            />
            <fieldset class="action">
                <ButtonSubmit />
                <router-link
                    :to="{ name: 'UsageStatisticsPlatformsShow' }"
                    role="button"
                    class="cancel"
                    >{{ $__("Cancel") }}</router-link
                >
            </fieldset>
        </form>
    </div>
</template>

<script>
import { inject } from "vue"
import ButtonSubmit from "../ButtonSubmit.vue"
import { storeToRefs } from "pinia"
import { APIClient } from "../../fetch/api-client.js"

export default {
    setup() {
        const AVStore = inject("AVStore")
        const { av_report_types } = storeToRefs(AVStore)

        return {
            AVStore,
            av_report_types,
        }
    },
    data() {
        return {
            file: {
                filename: null,
                harvester_id: null,
                file_type: null,
                file_content: null,
                date: null,
                date_uploaded: null,
            },
        }
    },
    methods: {
        selectFile(e) {
            let files = e.target.files
            if (!files) return
            let file = files[0]
            const reader = new FileReader()
            reader.onload = e => this.loadFile(file.name, e.target.result)
            reader.readAsBinaryString(file)
        },
        loadFile(filename, content) {
            this.file.filename = filename
            this.file.file_content = btoa(content)
        },
        addDocument(e) {
            e.preventDefault()
            // Harvesting and import to happen here
        },
        async getHarvester(platform_id) {
            const client = APIClient.erm
            const query = `platform_id=${platform_id}`
            await client.harvesters.getAll(query).then(
                harvesters => {
                    this.file.harvester_id = harvesters[0].erm_harvester_id
                },
                error => {}
            )
        },
    },
    mounted() {
        this.getHarvester(this.$route.params.platform_id)
    },
    components: {
        ButtonSubmit,
    },
    name: "UsageStatisticsPlatformsFileImport",
}
</script>

<style scoped>
label {
    margin: 0px 10px 0px 0px;
}
</style>
