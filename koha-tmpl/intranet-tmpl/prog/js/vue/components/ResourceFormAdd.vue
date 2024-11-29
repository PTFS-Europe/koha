<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="resources_add">
        <h2 v-if="resource.resource_id">
            {{
                $__("Edit") +
                " " +
                i18n.display_name +
                " #" +
                resource.resource_id
            }}
        </h2>
        <h2 v-else>{{ $__("New") + " " + i18n.display_name }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <fieldset class="rows">
                    <ol>
                        <li
                            v-for="(attr, index) in resource_attrs.filter(
                                attr => attr.type !== 'relationship'
                            )"
                            v-bind:key="index"
                        >
                            <FormElement
                                :resource="resource"
                                :attr="attr"
                                :index="index"
                            />
                        </li>
                    </ol>
                </fieldset>
                <template
                    v-for="(attr, index) in resource_attrs.filter(
                        attr => attr.type === 'relationship'
                    )"
                    v-bind:key="'rel-' + index"
                >
                    <FormElement :resource="resource" :attr="attr" />
                </template>
                <fieldset class="action">
                    <ButtonSubmit />
                    <router-link
                        :to="{ name: list_component }"
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
import FormElement from "./FormElement.vue"
import ButtonSubmit from "./ButtonSubmit.vue"

export default {
    data() {
        return {
            initialized: false,
        }
    },
    props: {
        id_attr: String,
        api_client: Object,
        i18n: Object,
        resource_attrs: Array,
        list_component: String,
        resource: Object,
        onSubmit: Function,
    },
    created() {
        if (this.$route.params.agreement_id) {
            this.getResource(this.$route.params.agreement_id)
        } else {
            this.initialized = true
        }
    },
    methods: {
        async getResource(resource_id) {
            this.api_client.get(resource_id).then(
                resource => {
                    this.resource = resource
                    this.initialized = true
                },
                error => {}
            )
        },
    },
    components: {
        ButtonSubmit,
        FormElement,
    },
    name: "ResourceFormAdd",
}
</script>
