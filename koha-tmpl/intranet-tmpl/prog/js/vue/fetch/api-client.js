import ERMAPIClient from "./erm-api-client";
import PatronAPIClient from "./patron-api-client";
import LibraryAPIClient from "./library-api-client";
import AcquisitionAPIClient from "./acquisition-api-client";
import AdditionalFieldsAPIClient from "./additional-fields-api-client";
import AVAPIClient from "./authorised-values-api-client";
import ItemAPIClient from "./item-api-client";
import SysprefAPIClient from "./system-preferences-api-client";
import PreservationAPIClient from "./preservation-api-client";
import CircRuleAPIClient from "./circulation-rules-api-client";

export const APIClient = {
    erm: new ERMAPIClient(),
    patron: new PatronAPIClient(),
    library: new LibraryAPIClient(),
    acquisition: new AcquisitionAPIClient(),
    additional_fields: new AdditionalFieldsAPIClient(),
    authorised_values: new AVAPIClient(),
    item: new ItemAPIClient(),
    sysprefs: new SysprefAPIClient(),
    preservation: new PreservationAPIClient(),
    circRule: new CircRuleAPIClient(),
};
