<template>
    <div>
        <div id="sub-header">
            <Breadcrumbs />
            <Help />
        </div>
        <div class="main container-fluid">
            <div class="row">
                <div class="col-md-10 order-md-2 order-sm-1">
                    <main>
                        <router-view />
                    </main>
                </div>

                <div class="col-md-2 order-sm-2 order-md-1">
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
