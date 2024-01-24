<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="record_source_edit">
        <h1>{{ title }}</h1>
        <form @submit="processSubmit">
            <fieldset class="rows">
                <ol>
                    <li>
                        <label class="required" for="name">
                            {{ $__("Name") }}:
                        </label>
                        <input id="name" v-model="row.name" required />
                        <span class="required">{{ $__("Required") }}</span>
                    </li>
                    <li>
                        <label :for="`user_id`">
                            {{ $__("Can be edited") }}:
                        </label>
                        <input
                            id="can_be_edited"
                            type="checkbox"
                            v-model="row.can_be_edited"
                        />
                    </li>
                </ol>
            </fieldset>
            <fieldset class="action">
                <input type="submit" :value="$__('Submit')" />
                <router-link
                    to="../record_sources"
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
import { RecordSourcesAPIClient } from "../../../fetch/record_sources-api-client"

export default {
    name: "Edit",
    setup() {
        const { record_source } = new RecordSourcesAPIClient()
        const { setMessage } = inject("mainStore")
        return {
            setMessage,
            api: record_source,
        }
    },
    data() {
        return {
            row: {
                name: "",
            },
            initialized: false,
        }
    },
    methods: {
        processSubmit(event) {
            event.preventDefault()
            const _hasValue = value => {
                return value !== undefined && value !== null && value !== ""
            }
            if (!_hasValue(this.row.name)) return false
            let response
            if (this.row.record_source_id) {
                const { record_source_id: id, ...row } = this.row
                response = this.api
                    .update({ id, row })
                    .then(() => this.$__("Record source updated!"))
            } else {
                response = this.api
                    .create({ row: this.row })
                    .then(() => this.$__("Record source created!"))
            }
            return response.then(responseMessage => {
                this.setMessage(responseMessage)
                return this.$router.push({ path: "../record_sources" })
            })
        },
    },
    created() {
        const { id } = this.$route.params
        if (id !== undefined) {
            this.api
                .get({
                    id,
                })
                .then(response => {
                    Object.keys(response).forEach(key => {
                        this.row[key] = response[key]
                    })
                    this.initialized = true
                })
        } else {
            this.initialized = true
        }
    },
    computed: {
        title() {
            if (!this.row || !this.row.record_source_id)
                return this.$__("Add record source")
            return this.$__("Edit '%s'").format(this.row.name)
        },
    },
}
</script>
