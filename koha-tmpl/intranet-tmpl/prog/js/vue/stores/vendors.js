import { defineStore } from "pinia";

export const useVendorStore = defineStore("vendors", {
    state: () => ({
        vendors: [],
        authorisedValues: {
            vendor_types: "VENDOR_TYPE",
            vendor_interface_types: "VENDOR_INTERFACE_TYPE",
        },
    }),
});
