<script>
import { ref } from "vue";
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
    },
    setup(props, { emit }) {
        const removeWidget = () => {
            emit("removed", props);
        };

        const addWidget = () => {
            emit("added", props);
        };

        return {
            ...props,
            removeWidget,
            addWidget,
        };
    },
    emits: ["removed", "added"],
    components: {
        FormElement,
    },
};
</script>
