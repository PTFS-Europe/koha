import { APIClient } from "../fetch/api-client.js";

export const get_lib_from_av_handler = (arr_name, av, store) => {
    if (store.authorisedValues[arr_name] === undefined) {
        console.warn(
            "The authorised value category for '%s' is not defined.".format(
                arr_name
            )
        );
        return;
    }
    let o = store.authorisedValues[arr_name].find(e => e.value == av);
    return o ? o.description : av;
};
export const map_av_dt_filter_handler = (arr_name, store) => {
    return store.authorisedValues[arr_name].map(e => {
        e["_id"] = e["value"];
        e["_str"] = e["description"];
        return e;
    });
};
export const loadAuthorisedValues = async (authorisedValues, targetStore) => {
    const AVsToFetch = Object.keys(authorisedValues).reduce((acc, avKey) => {
        if (Array.isArray(authorisedValues[avKey])) return acc;
        acc[avKey] = authorisedValues[avKey];
        return acc;
    }, {});

    const AVCatArray = Object.keys(AVsToFetch).map(avCat => {
        return '"' + AVsToFetch[avCat] + '"';
    });

    const promises = [];
    const AVClient = APIClient.authorised_values;
    promises.push(
        AVClient.values
            .getCategoriesWithValues(AVCatArray)
            .then(AVCategories => {
                Object.entries(AVsToFetch).forEach(([AVName, AVCat]) => {
                    const AVMatch = AVCategories.find(
                        element => element.category_name == AVCat
                    );
                    targetStore.authorisedValues[AVName] =
                        AVMatch.authorised_values;
                });
            })
    );

    return Promise.all(promises);
};
