<template>
    <a
        v-if="action === 'add'"
        @click="$emit('go-to-add-resource')"
        :class="class"
        ><font-awesome-icon icon="plus" /> {{ title }}</a
    >
    <a
        v-else-if="action === 'delete'"
        @click="$emit('delete-resource')"
        :class="class"
        ><font-awesome-icon icon="trash" /> {{ $__("Delete") }}</a
    >
    <a
        v-else-if="action === 'edit'"
        @click="$emit('go-to-edit-resource')"
        :class="class"
        ><font-awesome-icon icon="pencil" /> {{ $__("Edit") }}</a
    >
    <a
        v-else-if="callback"
        @click="typeof callback === 'string' ? redirect() : callback"
        :class="class"
        style="cursor: pointer"
    >
        <font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}
    </a>
    <router-link v-else-if="action === undefined && to" :to="to" :class="class"
        ><font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}</router-link
    >
    <span v-else>{{ $__("Unknown action %s").format(action) }}</span>
</template>

<script>
export default {
    props: {
        action: {
            type: String,
        },
        to: {
            type: [String, Object],
        },
        class: {
            type: String,
            default: "btn btn-default",
        },
        icon: {
            type: String,
            required: false,
        },
        title: {
            type: String,
        },
        callback: {
            type: [String, Function],
            required: false,
        },
    },
    methods: {
        redirect() {
            if (typeof this.to === "string")
                window.location.href = this.formatUrl(this.to)
            if (typeof this.to === "object") {
                let url = this.to.path
                if (this.to.hasOwnProperty("query")) {
                    url +=
                        "?" +
                        Object.keys(this.to.query)
                            .map(
                                queryParam =>
                                    `${queryParam}=${this.to.query[queryParam]}`
                            )
                            .join("&")
                }
                window.open(this.formatUrl(url, this.to.internal), "_blank")
            }
        },
        formatUrl(url) {
            if (url.includes("http://") || url.includes("https://")) return url
            if (url.includes("cgi-bin/koha"))
                return `//${window.location.host}/${url}`
            return `//${url}`
        },
    },
    emits: ["go-to-add-resource", "go-to-edit-resource", "delete-resource"],
    name: "Toolbar",
}
</script>
