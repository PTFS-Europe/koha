import ERMAPIClient from "./erm-api-client";
import PatronAPIClient from "./patron-api-client";
import AcquisitionAPIClient from "./acquisition-api-client";
import AdditionalFieldsAPIClient from "./additional-fields-api-client";
import AVAPIClient from "./authorised-values-api-client";
import CashAPIClient from "./cash-api-client";
import ItemAPIClient from "./item-api-client";
import RecordSourcesAPIClient from "./record-sources-api-client";
import SysprefAPIClient from "./system-preferences-api-client";
import PreservationAPIClient from "./preservation-api-client";
import SIP2APIClient from "./sip2-api-client";

export const APIClient = {
    erm: new ERMAPIClient(),
    patron: new PatronAPIClient(),
    acquisition: new AcquisitionAPIClient(),
    additional_fields: new AdditionalFieldsAPIClient(),
    authorised_values: new AVAPIClient(),
    cash: new CashAPIClient(),
    item: new ItemAPIClient(),
    sysprefs: new SysprefAPIClient(),
    sip2: new SIP2APIClient(),
    preservation: new PreservationAPIClient(),
    record_sources: new RecordSourcesAPIClient(),
};
