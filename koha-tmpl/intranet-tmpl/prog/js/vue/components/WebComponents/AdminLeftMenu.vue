<template>
    <div id="navmenu">
        <div id="navmenulist">
            <div v-if="canUserParametersManageSysprefs">
                <h5>System preferences</h5>
                <ul>
                    <li>
                        <a href="/cgi-bin/koha/admin/preferences.pl"
                            >System preferences</a
                        >
                    </li>
                </ul>
            </div>
        </div>
    </div>
</template>

<script>
export default {
    props: {
        canUserParametersManageSysprefs: Number,
    },
}
</script>

<style></style>
