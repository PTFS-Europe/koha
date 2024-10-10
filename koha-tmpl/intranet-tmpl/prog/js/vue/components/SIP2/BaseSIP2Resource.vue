<script>
import { inject } from "vue";
import BaseResource from "../BaseResource.vue";
import { APIClient } from "../../fetch/api-client.js";

export default {
    extends: BaseResource,
    setup(props) {
        const SIP2Store = inject("SIP2Store");
        const { config } = SIP2Store;

        return {
            ...BaseResource.setup({
                ...props,
                config,
            }),
        };
    },
    methods: {
        doResourceDelete(resource, callback) {
            const deleteCallback = () => {
                this.restartSIPServer()
                    .then(() => {
                        if (callback) {
                            callback.ajax.reload();
                        }
                    })
                    .then(() => {
                        this.goToResourceList();
                    });
            };
            BaseResource.methods.doResourceDelete.call(
                this,
                resource,
                deleteCallback
            );
        },

        async restartSIPServer() {
            const sipserver = APIClient.sip2;
            sipserver.sip_server.restart({ confirm: 1 }).then(
                success => {},
                error => {
                    this.setError(this.$__("Could not restart SIP server"));
                }
            );
        },
        onSubmit(e, resourceToSave) {
            e.preventDefault();

            if (!this.config.displayRestartSIPDialog) {
                const onSubmitCallback = this.onSubmitCallback;
                if (onSubmitCallback) {
                    onSubmitCallback(e, resourceToSave);
                }
            } else {
                this.setConfirmationDialog(
                    {
                        title: this.$__(
                            "The SIP server needs to be restarted for these changes to apply"
                        ),
                        message: this.$__(
                            "Are you sure you want to restart the SIP server now?"
                        ),
                        accept_label: this.$__("Yes, restart"),
                        cancel_label: this.$__("No, do not restart"),
                        inputs: [
                            {
                                id: "dontShowThisAgain",
                                type: "Checkbox",
                                value: false,
                                label: this.$__("Don't show this again"),
                            },
                        ],
                    },
                    callback_result => {
                        let dontShowThisAgain = callback_result.inputs.find(
                            input => {
                                return input.id == "dontShowThisAgain";
                            }
                        ).value;
                        this.config.displayRestartSIPDialog =
                            !dontShowThisAgain;
                        const onSubmitCallback = this.onSubmitCallback;
                        if (onSubmitCallback) {
                            onSubmitCallback(e, resourceToSave);
                        }
                    }
                );
            }
        },
    },
    name: " BaseSIP2Resource",
};
</script>
