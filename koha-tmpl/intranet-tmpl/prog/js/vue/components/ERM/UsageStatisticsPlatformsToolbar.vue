<template>
    <div id="toolbar" class="btn-toolbar">
        <router-link
            :to="{ name: 'UsageStatisticsPlatformsFormAdd' }"
            class="btn btn-default"
            ><font-awesome-icon icon="plus" />
            {{ $__("New platform") }}</router-link
        >
    </div>
</template>

<script>
export default {
    name: "UsageStatisticsPlatformsToolbar",
}
</script>
