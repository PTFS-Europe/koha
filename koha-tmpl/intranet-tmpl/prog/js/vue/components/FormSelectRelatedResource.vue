<template>
    <v-select
        label="name"
        :options="relatedResourcesOptions"
        :filter-by="filterRelatedResourcesOptions"
    >
        <template v-slot:option="v">
            {{ v.name }}
            <br />
            <cite>{{ v.aliases.map(a => a.alias).join(", ") }}</cite>
        </template>
    </v-select>
</template>

<script>
export default {
    props: {
        related_api_client: Object | null,
    },
    data() {
        return { relatedResources: null }
    },
    mounted() {
        const relatedResources = this.related_api_client
        relatedResources.getAll().then(
            relatedResources => {
                this.relatedResources = relatedResources
            },
            error => {}
        )
    },
    computed: {
        relatedResourcesOptions() {
            return this.relatedResources
        },
    },
    methods: {
        filterRelatedResourcesOptions(relatedResource, label, search) {
            return 1
            // return (
            //     (relatedResource.full_search || "")
            //         .toLocaleLowerCase()
            //         .indexOf(search.toLocaleLowerCase()) > -1
            // )
        },
    },
}
</script>
