<template>
    <div class="page-section data-display">
        <fieldset class="rows">
            <ol>
                <DataField
                    v-for="(item, key) in fields"
                    v-bind:key="key"
                    :item="item"
                />
            </ol>
        </fieldset>
        <fieldset v-if="showClose" class="action">
            <router-link :to="{ name: homeRoute }" role="button" class="cancel"
                >Close</router-link
            >
        </fieldset>
    </div>
</template>

<script>
import schema from "../data/schemaToUI.json"
import DataField from "./DataField.vue"
import { inject } from "vue"

export default {
    props: {
        data: Object,
        dataType: String,
        homeRoute: String,
        showClose: {
            type: Boolean,
            default: true,
        },
    },
    setup() {
        const AVStore = inject("AVStore")
        const { get_lib_from_av } = AVStore

        return {
            get_lib_from_av,
        }
    },
    data() {
        const fields = this.mapValueToField(schema, this.dataType)
        return {
            fields,
        }
    },
    methods: {
        mapValueToField(schema, type) {
            const fields = schema[type]
            const result = Object.keys(fields).map(key => {
                const value = this.data[key]
                fields[key].value = value
                if (fields[key].type === "owner") {
                    fields[key].value = this.data.owner
                }
                if (fields[key].type === "link") {
                    const value = this.data[fields[key].dataType]
                    if (value) {
                        const linkParam =
                            typeof value === "string"
                                ? value
                                : value[fields[key].linkId]
                        fields[key].href =
                            "/acquisitions/fund_management/" +
                            fields[key].linkSlug +
                            "/" +
                            linkParam
                        fields[key].linkText = fields[key].isAV
                            ? this.get_lib_from_av(fields[key].av_type, value)
                            : value[fields[key].linkName]
                    } else {
                        fields[key].type = "string"
                        fields[key].value = ""
                    }
                }
                if (fields[key].type === "creator") {
                    fields[key].value = this.data.created_by
                }
                if (fields[key].type === "av") {
                    fields[key].value = this.get_lib_from_av(
                        fields[key].av_type,
                        value
                    )
                    fields[key].type = "string"
                }
                if (fields[key].type === "table") {
                    const value = this.data[fields[key].dataType]
                    if (Array.isArray(value)) {
                        fields[key].value = value
                    } else {
                        fields[key].value = [value]
                    }
                }
                return fields[key]
            })
            return result
        },
    },
    components: {
        DataField,
    },
}
</script>

<style scoped>
.data-display {
    min-width: 50%;
}
</style>
