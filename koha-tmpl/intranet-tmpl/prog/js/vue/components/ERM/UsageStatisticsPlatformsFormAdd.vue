<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="platforms_add">
        <h2 v-if="platform.erm_platform_id">
            {{ $__("Edit platform #%s").format(platform.erm_platform_id) }}
        </h2>
        <h2 v-else>{{ $__("New platform") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <!-- <div class="page-section"> This is on other components such as AgreementsFormAdd.vue and just makes it look messy - what purpose is it serving?-->
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label class="required" for="platform_name"
                                >{{ $__("Platform name") }}:</label
                            >
                            <input
                                id="platform_name"
                                v-model="platform.name"
                                :placeholder="$__('Platform name')"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="platform_description"
                                >{{ $__("Description") }}:
                            </label>
                            <textarea
                                id="platform_description"
                                v-model="platform.description"
                                :placeholder="$__('Description')"
                                rows="10"
                                cols="50"
                            />
                        </li>
                    </ol>
                </fieldset>
                <!-- </div> -->
                <fieldset class="action">
                    <ButtonSubmit />
                    <router-link
                        v-if="previous_route === 'platforms_show'"
                        :to="{ name: 'UsageStatisticsPlatformsShow' }"
                        role="button"
                        class="cancel"
                        >{{ $__("Cancel") }}</router-link
                    >
                    <router-link
                        v-else
                        :to="{ name: 'UsageStatisticsPlatformsList' }"
                        role="button"
                        class="cancel"
                        >{{ $__("Cancel") }}</router-link
                    >
                </fieldset>
            </form>
        </div>
    </div>
</template>

<script>
import ButtonSubmit from "../ButtonSubmit.vue"
import { setMessage, setError, setWarning } from "../../messages"
import { APIClient } from "../../fetch/api-client.js"
// import { storeToRefs } from "pinia"

export default {
    setup() {
        // const AVStore = inject("AVStore")
        // const {} = storeToRefs(AVStore)

        return {} // Left as placeholder for permissions
    },
    data() {
        return {
            platform: {
                erm_platform_id: null,
                name: "",
                description: "",
            },
            initialized: false,
            previous_route: "",
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            if (to.params.platform_id) {
                vm.getPlatform(to.params.platform_id)
            } else {
                vm.initialized = true
            }
            if (from.params.platform_id) {
                vm.previous_route = "platforms_show"
            } else {
                vm.previous_route = "platforms_list"
            }
        })
    },
    methods: {
        async getPlatform(erm_platform_id) {
            const client = APIClient.erm
            client.platforms.get(erm_platform_id).then(
                data => {
                    this.platform = data
                    this.initialized = true
                },
                error => {}
            )
        },
        onSubmit(e) {
            e.preventDefault()

            //let platform= Object.assign( {} ,this.platform); // copy
            let platform = JSON.parse(JSON.stringify(this.platform)) // copy
            let erm_platform_id = platform.erm_platform_id

            delete platform.erm_platform_id

            const client = APIClient.erm
            if (erm_platform_id) {
                client.platforms.update(platform, erm_platform_id).then(
                    success => {
                        setMessage(this.$__("Platform updated"))
                        this.$router.push({
                            name: "UsageStatisticsPlatformsList",
                        })
                    },
                    error => {}
                )
            } else {
                client.platforms.create(platform).then(
                    success => {
                        setMessage(this.$__("Platform created"))
                        this.$router.push({
                            name: "UsageStatisticsPlatformsList",
                        })
                    },
                    error => {}
                )
            }
        },
    },
    components: {
        ButtonSubmit,
    },
    name: "UsageStatisticsPlatformsFormAdd",
}
</script>
