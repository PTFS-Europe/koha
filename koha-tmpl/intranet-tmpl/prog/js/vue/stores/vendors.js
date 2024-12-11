import { defineStore } from "pinia";

export const useVendorStore = defineStore("vendors", {
    state: () => ({
        vendors: [],
        currencies: [],
        gstValues: [],
        libraryGroups: null,
        visibleGroups: null,
        config: {
            settings: {
                edifact: false,
            },
        },
    }),
});
