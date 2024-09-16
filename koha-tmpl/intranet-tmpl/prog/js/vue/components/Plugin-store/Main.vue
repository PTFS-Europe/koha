<template>
    <div v-if="initialized">
        <div id="sub-header">
            <Breadcrumbs />
            <Help />
        </div>
        <div class="main container-fluid">
            <div class="row">
                <div class="col-md-10 order-md-2 order-sm-1">
                    <main>
                        <Dialog />
                        <router-view />
                    </main>
                </div>

                <div class="col-md-2 order-sm-2 order-md-1">
                    <LeftMenu :title="$__('Plugins store')"></LeftMenu>
                </div>
            </div>
        </div>
    </div>
    <div v-else class="main container-fluid">
        <Dialog />
    </div>
</template>

<script>
import { APIClient } from "../../fetch/api-client.js"
import { inject } from "vue"
import Breadcrumbs from "../Breadcrumbs.vue"
import Help from "../Help.vue"
import LeftMenu from "../LeftMenu.vue"
import Dialog from "../Dialog.vue"

export default {
    setup() {
        const { setError } = inject("mainStore")

        return {
            koha_version,
            setError,
        }
    },
    data() {
        return {
            initialized: false,
        }
    },
    components: {
        Breadcrumbs,
        Help,
        Dialog,
        LeftMenu,
    },
    beforeCreate() {
        //TODO Check if plugin store is reachable instead of fetching plugins
        const client = APIClient.plugin_store
        client.plugins.getStoreAll(this.koha_version.release).then(
            res => {
                this.initialized = true
            },
            error => {
                return this.setError(
                    this.$__(
                        "The plugin store could not be reached. Please check your internet connection and try again."
                    ),
                    false
                )
            }
        )
    },
}
</script>
