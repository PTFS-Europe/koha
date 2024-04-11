import ERMAPIClient from "./erm-api-client";
import PatronAPIClient from "./patron-api-client";
import AcquisitionAPIClient from "./acquisition-api-client";
import AVAPIClient from "./authorised-values-api-client";
import ItemAPIClient from "./item-api-client";
import RecordSourcesAPIClient from "./record-sources-api-client";
import SysprefAPIClient from "./system-preferences-api-client";
import PreservationAPIClient from "./preservation-api-client";

export const APIClient = {
    erm: new ERMAPIClient(),
    patron: new PatronAPIClient(),
    acquisition: new AcquisitionAPIClient(),
    authorised_values: new AVAPIClient(),
    item: new ItemAPIClient(),
    sysprefs: new SysprefAPIClient(),
    preservation: new PreservationAPIClient(),
    record_sources: new RecordSourcesAPIClient(),
};
