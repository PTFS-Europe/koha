<script>
import { ref } from "vue";
import VueCookies from "vue-cookies";
import FormElement from "../FormElement.vue";
export default {
    props: {
        display: {
            type: String,
            required: true,
        },
        alreadyAdded: {
            type: Boolean,
            required: false,
            default: false,
        },
        dashboardColumn: {
            type: String,
            required: false,
        },
    },
    setup(props) {
        const loading = ref(props.loading !== undefined ? props.loading : true);
        const settings = ref(props.settings || {});
        const settings_definitions = ref(props.settings_definitions || []);

        return {
            ...props,
            loading,
            settings,
            settings_definitions,
        };
    },
    provide() {
        return {
            removeWidget: this.removeWidget,
            addWidget: this.addWidget,
            moveWidget: this.moveWidget,
        };
    },
    mounted: function () {
        if (this.display === "dashboard") {
            if (
                this.onDashboardMounted &&
                typeof this.onDashboardMounted === "function"
            ) {
                this.onDashboardMounted();
            }
        }
    },
    created: function () {
        if (this.display === "dashboard") {
            const cookie = this.getWidgetSavedSettings();
            if (cookie) {
                this.settings = cookie;
            }
        }
    },
    computed: {
        widgetWrapperProps() {
            return {
                id: this.id,
                display: this.display,
                alreadyAdded: this.alreadyAdded,
                dashboardColumn: this.dashboardColumn,
                name: this.name,
                loading: this.loading,
                description: this.description,
                settings: this.settings,
                settings_definitions: this.settings_definitions,
            };
        },
    },
    methods: {
        removeWidget() {
            this.$emit("removed", this.props);
        },
        addWidget() {
            this.$emit("added", this.props);
        },
        moveWidget: function () {
            this.$emit("moveWidget", {
                componentName: this.id,
                currentColumn: this.dashboardColumn,
            });
        },
        getWidgetSavedSettings: function () {
            const cookie = VueCookies.get("widget-" + this.id + "-settings");
            return cookie || null;
        },
    },
    watch: {
        settings: {
            handler(settings) {
                if (this.display === "dashboard" && settings !== null) {
                    VueCookies.set(
                        "widget-" + this.id + "-settings",
                        JSON.stringify(settings),
                        "30d"
                    );
                }
            },
            deep: true,
        },
    },
    emits: ["removed", "added", "moveWidget"],
    components: {
        FormElement,
    },
    name: "BaseWidget",
};
</script>
