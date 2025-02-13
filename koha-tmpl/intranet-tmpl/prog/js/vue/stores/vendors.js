import { defineStore } from "pinia";
import {
    loadAuthorisedValues,
    get_lib_from_av_handler,
    map_av_dt_filter_handler,
} from "../composables/authorisedValues";

export const useVendorStore = defineStore("vendors", {
    state: () => ({
        vendors: [],
        currencies: [],
        gstValues: [],
        config: {
            settings: {
                edifact: false,
            },
        },
        authorisedValues: {
            av_vendor_types: "VENDOR_TYPE",
            av_vendor_interface_types: "VENDOR_INTERFACE_TYPE",
        },
    }),
    actions: {
        loadAuthorisedValues,
        get_lib_from_av(arr_name, av) {
            return get_lib_from_av_handler(arr_name, av, this);
        },
        map_av_dt_filter(arr_name) {
            return map_av_dt_filter_handler(arr_name, this);
        },
    },
});
