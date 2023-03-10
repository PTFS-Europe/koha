<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="harvester_show">
        <h2>
            {{ $__("Harvester") }}
            <span v-if="harvester" class="action_links">
                <router-link
                    to=""
                    @click="this.$emit('change_harvester_tab', 'add')"
                    :title="$__('Edit')"
                    ><i class="fa fa-pencil"></i
                ></router-link>
                <!-- <router-link
                    :to="`/cgi-bin/koha/erm/harvesters/delete/${harvester.erm_harvester_id}`"
                    :title="$__('Delete')"
                    ><i class="fa fa-trash"></i
                ></router-link> -->
            </span>
        </h2>
        <div v-if="harvester" class="harvester_detail">
            <fieldset class="rows">
                <ol>
                    <li>
                        <label>{{ $__("Harvester Id") }}:</label>
                        <span>
                            {{ harvester.erm_harvester_id }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Status") }}:</label>
                        <span>
                            {{ harvester.status }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Method") }}:</label>
                        <span>
                            {{ harvester.method }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Aggregator") }}:</label>
                        <span>
                            {{ harvester.aggregator }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Service Type") }}:</label>
                        <span>
                            {{ harvester.service_type }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Service URL") }}:</label>
                        <span>
                            {{ harvester.service_url }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Report Release") }}:</label>
                        <span>
                            {{ harvester.report_release }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Harvest Start") }}:</label>
                        <span>
                            {{ harvester.begin_date }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Harvest End") }}:</label>
                        <span>
                            {{ harvester.end_date }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Customer Id") }}:</label>
                        <span>
                            {{ harvester.customer_id }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Requestor Id") }}:</label>
                        <span>
                            {{ harvester.requestor_id }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("API Key") }}:</label>
                        <span>
                            {{ harvester.api_key }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Platform") }}:</label>
                        <span>
                            {{ harvester.platform }}
                            <!-- TODO: When adding a harvester this should default to the platform name -->
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Requestor Name") }}:</label>
                        <span>
                            {{ harvester.requestor_name }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Requestor Email") }}:</label>
                        <span>
                            {{ harvester.requestor_email }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Report types") }}:</label>
                        <span>
                            {{ harvester.report_types }}
                            <!-- TODO: Define structure of report types and how to display them -->
                        </span>
                    </li>
                </ol>
            </fieldset>
        </div>
        <div v-else>
            <UsageStatisticsHarvesterToolbar
                @add_harvester="this.$emit('change_harvester_tab', 'add')"
            />
            <div class="dialog message">
                {{ $__("There is no harvester defined for this platform") }}
            </div>
        </div>
    </div>
</template>

<script>
import { inject } from "vue"
import { APIClient } from "../../fetch/api-client.js"
import UsageStatisticsHarvesterToolbar from "./UsageStatisticsHarvesterToolbar.vue"

export default {
    setup() {
        const AVStore = inject("AVStore")
        const { get_lib_from_av } = AVStore

        return {
            get_lib_from_av,
        }
    },
    data() {
        return {
            harvester: {},
            initialized: false,
        }
    },
    methods: {
        async getHarvester(platform_id) {
            const client = APIClient.erm
            const query = `platform_id=${platform_id}`
            await client.harvesters.getAll(query).then(
                harvesters => {
                    this.harvester = harvesters[0]
                    this.initialized = true
                },
                error => {}
            )
        },
    },
    mounted() {
        this.getHarvester(this.$route.params.platform_id)
    },
    name: "UsageStatisticsHarvesterShow",
    components: { UsageStatisticsHarvesterToolbar },
    emits: ["change_harvester_tab"],
}
</script>
<style scoped>
.action_links a {
    padding-left: 0.2em;
    font-size: 11px;
}
.active {
    cursor: pointer;
}
.rows {
    float: none;
}
</style>
