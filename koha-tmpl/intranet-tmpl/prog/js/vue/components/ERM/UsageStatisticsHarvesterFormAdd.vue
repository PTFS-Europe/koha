<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="harvesters_add">
        <h2 v-if="harvester.erm_harvester_id">
            {{ $__("Edit harvester #%s").format(harvester.erm_harvester_id) }}
        </h2>
        <h2 v-else>{{ $__("New harvester") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <!-- <div class="page-section"> This is on other components such as AgreementsFormAdd.vue and just makes it look messy - what purpose is it serving?-->
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label for="harvester_status"
                                >{{ $__("Harvester status") }}:</label
                            >
                            <input
                                id="harvester_status"
                                v-model="harvester.status"
                            />
                        </li>
                        <li>
                            <label for="harvester_method"
                                >{{ $__("Method") }}:
                            </label>
                            <input
                                id="harvester_method"
                                v-model="harvester.method"
                            />
                        </li>
                        <li>
                            <label for="harvester_aggregator"
                                >{{ $__("Aggregator") }}:
                            </label>
                            <input
                                id="harvester_aggregator"
                                v-model="harvester.aggregator"
                            />
                        </li>
                        <li>
                            <label for="harvester_service_type"
                                >{{ $__("Service type") }}:
                            </label>
                            <input
                                id="harvester_service_type"
                                v-model="harvester.service_type"
                            />
                        </li>
                        <li>
                            <label class="required" for="harvester_service_url"
                                >{{ $__("Service URL") }}:
                            </label>
                            <input
                                id="harvester_service_url"
                                v-model="harvester.service_url"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label
                                class="required"
                                for="harvester_report_release"
                                >{{ $__("Report release") }}:
                            </label>
                            <input
                                id="harvester_report_release"
                                v-model="harvester.report_release"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="harvester_begin_date"
                                >{{ $__("Harvest start date") }}:
                            </label>
                            <input
                                id="harvester_begin_date"
                                v-model="harvester.begin_date"
                                type="date"
                            />
                        </li>
                        <li>
                            <label for="harvester_end_date"
                                >{{ $__("Harvest end date") }}:
                            </label>
                            <input
                                id="harvester_end_date"
                                v-model="harvester.end_date"
                                type="date"
                            />
                        </li>
                        <li>
                            <label class="required" for="harvester_customer_id"
                                >{{ $__("Customer Id") }}:
                            </label>
                            <input
                                id="harvester_customer_id"
                                v-model="harvester.customer_id"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label class="required" for="harvester_requestor_id"
                                >{{ $__("Requestor Id") }}:
                            </label>
                            <input
                                id="harvester_requestor_id"
                                v-model="harvester.requestor_id"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label class="required" for="harvester_api_key"
                                >{{ $__("API key") }}:
                            </label>
                            <input
                                id="harvester_api_key"
                                v-model="harvester.api_key"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="harvester_requestor_name"
                                >{{ $__("Requestor name") }}:
                            </label>
                            <input
                                id="harvester_requestor_name"
                                v-model="harvester.requestor_name"
                            />
                        </li>
                        <li>
                            <label for="harvester_requestor_email"
                                >{{ $__("Requestor email") }}:
                            </label>
                            <input
                                id="harvester_requestor_email"
                                v-model="harvester.requestor_email"
                            />
                        </li>
                        <li>
                            <label class="required" for="harvester_report_types"
                                >{{ $__("Report types") }}:
                            </label>
                            <v-select
                                id="report_type"
                                v-model="harvester.report_types"
                                label="description"
                                :reduce="av => av.value"
                                :options="av_report_types"
                                multiple
                            />
                            <!-- TODO: This needs to be a dropdown based on the authorised values -->
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                    </ol>
                </fieldset>
                <!-- </div> -->
                <fieldset class="action">
                    <ButtonSubmit />
                    <router-link
                        @click="this.$emit('change_harvester_tab', 'detail')"
                        to=""
                        role="button"
                        class="cancel"
                        >{{ $__("Cancel") }}
                    </router-link>
                </fieldset>
            </form>
        </div>
    </div>
</template>

<script>
import ButtonSubmit from "../ButtonSubmit.vue"
import { setMessage, setError, setWarning } from "../../messages"
import { APIClient } from "../../fetch/api-client.js"
import { inject } from "vue"
import { storeToRefs } from "pinia"

export default {
    setup() {
        const AVStore = inject("AVStore")
        const { av_report_types } = storeToRefs(AVStore)

        return {
            av_report_types,
        }
    },
    data() {
        return {
            platform: null,
            harvester: {
                erm_harvester_id: null,
                platform_id: null,
                status: "",
                method: "",
                aggregator: "",
                service_type: "",
                service_url: "",
                report_release: "",
                begin_date: null,
                end_date: null,
                customer_id: "",
                requestor_id: "",
                api_key: "",
                platform: "",
                requestor_name: "",
                requestor_email: "",
                report_types: [],
            },
            initialized: false,
        }
    },
    mounted() {
        this.getPlatform(this.$route.params.platform_id)
        this.getHarvester(this.$route.params.platform_id)
    },
    methods: {
        async getPlatform(platform_id) {
            const client = APIClient.erm
            await client.platforms.get(platform_id).then(
                data => {
                    this.platform = data
                },
                error => {}
            )
        },
        async getHarvester(platform_id) {
            const client = APIClient.erm
            const query = `platform_id=${platform_id}`
            await client.harvesters.getAll(query).then(
                harvesters => {
                    if (harvesters.length !== 0) {
                        this.harvester = harvesters[0]
                    }
                    this.initialized = true
                },
                error => {}
            )
        },
        formatReportTypes(array) {
            let report_types_string = ""
            array.forEach(item => {
                report_types_string += item
                report_types_string += ";"
            })
            return report_types_string
        },
        onSubmit(e) {
            e.preventDefault()

            //let harvester= Object.assign( {} ,this.harvester); // copy
            let harvester = JSON.parse(JSON.stringify(this.harvester)) // copy
            let erm_harvester_id = harvester.erm_harvester_id

            delete harvester.erm_harvester_id

            harvester.report_types = this.formatReportTypes(
                harvester.report_types
            )

            const client = APIClient.erm
            if (erm_harvester_id) {
                client.harvesters.update(harvester, erm_harvester_id).then(
                    success => {
                        setMessage(this.$__("Harvester updated"))
                        this.$emit("change_harvester_tab", "detail")
                    },
                    error => {}
                )
            } else {
                harvester.platform_id = this.platform.erm_platform_id
                harvester.platform = this.platform.name

                client.harvesters.create(harvester).then(
                    success => {
                        setMessage(this.$__("Harvester created"))
                        this.$emit("change_harvester_tab", "detail")
                    },
                    error => {}
                )
            }
        },
    },
    components: {
        ButtonSubmit,
    },
    name: "UsageStatisticsHarvesterFormAdd",
    emits: ["change_harvester_tab"],
}
</script>
