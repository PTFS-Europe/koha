<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="platforms_show">
        <h2>
            {{ $__("Platform #%s").format(platform.erm_platform_id) }}
            <span class="action_links">
                <router-link
                    :to="{
                        name: 'UsageStatisticsPlatformsFormAddEdit',
                        params: { platform_id: platform.erm_platform_id },
                    }"
                    :title="$__('Edit')"
                    ><i class="fa fa-pencil"></i
                ></router-link>

                <router-link
                    :to="`/cgi-bin/koha/erm/platforms/delete/${platform.erm_platform_id}`"
                    :title="$__('Delete')"
                    ><i class="fa fa-trash"></i
                ></router-link>
            </span>
        </h2>
        <div id="platformstabs" class="toptabs numbered">
            <ul class="nav nav-tabs" role="tablist">
                <li
                    role="presentation"
                    v-bind:class="tab_content === 'detail' ? 'active' : ''"
                >
                    <a
                        href="#"
                        role="tab"
                        data-content="detail"
                        @click="change_tab_content"
                        >Detail</a
                    >
                </li>
                <li
                    role="presentation"
                    v-bind:class="tab_content === 'harvester' ? 'active' : ''"
                >
                    <a
                        href="#"
                        role="tab"
                        data-content="harvester"
                        @click="change_tab_content"
                        >Harvester</a
                    >
                </li>
                <li
                    role="presentation"
                    v-bind:class="tab_content === 'titles' ? 'active' : ''"
                >
                    <a
                        href="#"
                        role="tab"
                        data-content="titles"
                        @click="change_tab_content"
                        >Titles</a
                    >
                </li>
                <li
                    role="presentation"
                    v-bind:class="tab_content === 'imports' ? 'active' : ''"
                >
                    <a
                        href="#"
                        role="tab"
                        data-content="imports"
                        @click="change_tab_content"
                        >Imports</a
                    >
                </li>
            </ul>
        </div>
        <div class="tab-content">
            <div v-if="tab_content === 'detail'" class="platform_detail">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label>{{ $__("Platform name") }}:</label>
                            <span>
                                {{ platform.name }}
                            </span>
                        </li>
                        <li>
                            <label>{{ $__("Description") }}:</label>
                            <span>
                                {{ platform.description }}
                            </span>
                        </li>
                    </ol>
                </fieldset>
            </div>
            <div v-if="tab_content === 'harvester'">
                <UsageStatisticsHarvesterShow
                    v-if="harvester_tab === 'detail'"
                    @change_harvester_tab="this.harvester_tab = $event"
                />
                <UsageStatisticsHarvesterFormAdd
                    v-if="harvester_tab === 'add'"
                    @change_harvester_tab="this.harvester_tab = $event"
                />
            </div>
            <div v-if="tab_content === 'titles'">
                <UsageStatisticsTitlesList />
            </div>
            <div v-if="tab_content === 'imports'">
                <UsageStatisticsPlatformsFileImport />
            </div>
        </div>
        <fieldset class="action">
            <router-link
                :to="{ name: 'UsageStatisticsPlatformsList' }"
                role="button"
                class="cancel"
                >{{ $__("Close") }}</router-link
            >
        </fieldset>
    </div>
</template>

<script>
import { inject } from "vue"
import { APIClient } from "../../fetch/api-client.js"
import UsageStatisticsTitlesList from "./UsageStatisticsTitlesList.vue"
import UsageStatisticsHarvesterShow from "./UsageStatisticsHarvesterShow.vue"
import UsageStatisticsHarvesterFormAdd from "./UsageStatisticsHarvesterFormAdd.vue"
import UsageStatisticsPlatformsFileImport from "./UsageStatisticsPlatformsFileImport.vue"

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
            platform: {
                erm_platform_id: null,
                name: "",
                description: "",
            },
            initialized: false,
            tab_content: "detail",
            harvester_tab: "detail",
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            vm.getPlatform(to.params.platform_id)
        })
    },
    beforeRouteUpdate(to, from) {
        this.platform = this.getPlatform(to.params.platform_id)
    },
    methods: {
        async getPlatform(platform_id) {
            const client = APIClient.erm
            client.platforms.get(platform_id).then(
                platform => {
                    this.platform = platform
                    this.initialized = true
                },
                error => {}
            )
        },
        change_tab_content(e) {
            this.initialized = false
            this.tab_content = e.target.getAttribute("data-content")
        },
    },
    name: "UsageStatisticsPlatformsShow",
    components: {
        UsageStatisticsTitlesList,
        UsageStatisticsHarvesterShow,
        UsageStatisticsHarvesterFormAdd,
        UsageStatisticsPlatformsFileImport,
    },
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
