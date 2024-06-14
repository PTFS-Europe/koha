import ERMAPIClient from "./erm-api-client";
import PatronAPIClient from "./patron-api-client";
import AcquisitionAPIClient from "./acquisition-api-client";
import AdditionalFieldsAPIClient from "./additional-fields-api-client";
import AVAPIClient from "./authorised-values-api-client";
import ItemAPIClient from "./item-api-client";
import RecordSourcesAPIClient from "./record-sources-api-client";
import SysprefAPIClient from "./system-preferences-api-client";
import PreservationAPIClient from "./preservation-api-client";
import PluginStoreAPIClient from "./plugin-store-api-client";

export const APIClient = {
    erm: new ERMAPIClient(),
    patron: new PatronAPIClient(),
    acquisition: new AcquisitionAPIClient(),
    additional_fields: new AdditionalFieldsAPIClient(),
    authorised_values: new AVAPIClient(),
    item: new ItemAPIClient(),
    sysprefs: new SysprefAPIClient(),
    plugin_store: new PluginStoreAPIClient(),
    preservation: new PreservationAPIClient(),
    record_sources: new RecordSourcesAPIClient(),
};
