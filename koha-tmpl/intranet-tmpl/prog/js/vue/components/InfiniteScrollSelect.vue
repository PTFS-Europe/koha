<template>
    <v-select
        :id="id"
        v-model="model"
        :label="label"
        :options="paginationRequired ? paginated : data"
        :reduce="item => item[dataIdentifier]"
        @open="onOpen"
        @close="onClose"
        @option:selected="onSelected"
        @search="searchFilter($event)"
        ref="select"
        :disabled="disabled"
    >
        <template v-if="required" #search="{ attributes, events }">
            <input
                :required="!model"
                class="vs__search"
                v-bind="attributes"
                v-on="events"
            />
        </template>
        <template #selected-option="option">
            {{ selectedOptionLabel }}
        </template>
        <template #list-footer>
            <li v-show="hasNextPage && !this.search" ref="load">
                {{ $__("Loading more options...") }}
            </li>
        </template>
    </v-select>
</template>

<script>
import { APIClient } from "../fetch/api-client.js"

export default {
    props: {
        id: String,
        selectedData: Object,
        dataType: String,
        modelValue: Number,
        dataIdentifier: String,
        label: String,
        required: Boolean,
        apiClient: String,
        filters: Object,
        headers: Object,
        disabled: Boolean,
    },
    emits: ["update:modelValue"],
    data() {
        const data = this.selectedData ? [this.selectedData] : []
        const selectedOptionLabel = this.selectedData
            ? this.selectedData[this.label]
            : ""
        return {
            observer: null,
            limit: null,
            search: "",
            scrollPage: null,
            data,
            paginationRequired: false,
            selectedOptionLabel,
        }
    },
    computed: {
        model: {
            get() {
                return this.modelValue
            },
            set(value) {
                this.$emit("update:modelValue", value)
            },
        },
        filtered() {
            return this.data.filter(item =>
                item[this.label].includes(this.search)
            )
        },
        paginated() {
            return this.filtered.slice(0, this.limit)
        },
        hasNextPage() {
            return this.paginated.length < this.filtered.length
        },
    },
    mounted() {
        this.observer = new IntersectionObserver(this.infiniteScroll)
    },
    methods: {
        async fetchInitialData(dataType, filters) {
            const filterOptions = filters ? filters : {}
            const headers = this.headers ? this.headers : []
            const client = APIClient[this.apiClient]
            await client[dataType]
                .getAll(
                    filterOptions,
                    {
                        _page: 1,
                        _per_page: 20,
                        _match: "contains",
                    },
                    headers
                )
                .then(
                    items => {
                        this.data = items
                        this.search = ""
                        this.limit = 19
                        this.scrollPage = 1
                    },
                    error => {}
                )
        },
        async searchFilter(e) {
            if (e) {
                this.paginationRequired = false
                this.observer.disconnect()
                this.data = []
                this.search = e
                const client = APIClient[this.apiClient]
                const attribute = "me." + this.label
                const headers = this.headers ? this.headers : []
                const q = this.filters ? this.filters : {}
                q[attribute] = { like: `%${e}%` }
                await client[this.dataType]
                    .getAll(
                        q,
                        {
                            _per_page: -1,
                        },
                        headers
                    )
                    .then(
                        items => {
                            this.data = [...items]
                        },
                        error => {}
                    )
            } else {
                this.resetSelect()
            }
        },
        async onOpen() {
            this.paginationRequired = true
            await this.fetchInitialData(this.dataType, this.filters)
            if (this.hasNextPage) {
                await this.$nextTick()
                this.observer.observe(this.$refs.load)
            }
        },
        onClose() {
            this.observer.disconnect()
        },
        onSelected(option) {
            this.selectedOptionLabel = option[this.label]
        },
        async infiniteScroll([{ isIntersecting, target }]) {
            setTimeout(async () => {
                if (isIntersecting) {
                    const ul = target.offsetParent
                    const scrollTop = target.offsetParent.scrollTop
                    this.limit += 20
                    this.scrollPage++
                    await this.$nextTick()
                    const client = APIClient[this.apiClient]
                    ul.scrollTop = scrollTop
                    const filterOptions = this.filters ? this.filters : {}
                    const headers = this.headers ? this.headers : []
                    await client[this.dataType]
                        .getAll(
                            filterOptions,
                            {
                                _page: this.scrollPage,
                                _per_page: 20,
                                _match: "contains",
                            },
                            headers
                        )
                        .then(
                            items => {
                                const existingData = [...this.data]
                                this.data = [...existingData, ...items]
                            },
                            error => {}
                        )
                    ul.scrollTop = scrollTop
                }
            }, 250)
        },
        async resetSelect() {
            if (this.$refs.select.open) {
                await this.fetchInitialData(this.dataType)
                if (this.hasNextPage) {
                    await this.$nextTick()
                    this.observer.observe(this.$refs.load)
                }
            } else {
                this.paginationRequired = false
            }
        },
    },
    name: "InfiniteScrollSelect",
}
</script>
