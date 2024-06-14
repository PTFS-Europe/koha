<template>
    <div>
        <div id="sub-header">
            <Breadcrumbs />
            <Help />
        </div>
        <div class="main container-fluid">
            <div class="row">
                <div class="col-sm-10 col-sm-push-2">
                    <main>
                        <router-view />
                    </main>
                </div>

                <div class="col-sm-2 col-sm-pull-10">
                    <LeftMenu :title="$__('Plugins store')"></LeftMenu>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import Breadcrumbs from "../Breadcrumbs.vue"
import Help from "../Help.vue"
import LeftMenu from "../LeftMenu.vue"

export default {
    components: {
        Breadcrumbs,
        Help,
        LeftMenu,
    },
}
</script>
