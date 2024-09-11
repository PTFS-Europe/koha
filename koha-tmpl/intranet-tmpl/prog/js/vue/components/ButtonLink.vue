<template>
    <a
        v-if="callback"
        @click="typeof callback === 'string' ? redirect() : callback"
        :class="class"
        style="cursor: pointer"
    >
        <font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}
    </a>
    <router-link v-else :to="to" :class="class"
        ><font-awesome-icon v-if="icon" :icon="icon" /> {{ title }}</router-link
    >
</template>

<script>
export default {
    props: {
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
                window.location.href = this.formatUrl(url, this.to.internal)
            }
        },
        formatUrl(url) {
            if (url.includes("http://") || url.includes("https://")) return url
            if (url.includes("cgi-bin/koha"))
                return `//${window.location.host}/${url}`
            return `//${url}`
        },
    },
    name: "ButtonLink",
}
</script>
