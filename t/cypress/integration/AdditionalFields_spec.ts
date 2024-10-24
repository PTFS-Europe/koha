import { mount } from "@cypress/vue";
const dayjs = require("dayjs"); /* Cannot use our calendar JS code, it's in an include file (!)
                                   Also note that moment.js is deprecated */

const dates = {
    today_iso: dayjs().format("YYYY-MM-DD"),
    today_us: dayjs().format("MM/DD/YYYY"),
    tomorrow_iso: dayjs().add(1, "day").format("YYYY-MM-DD"),
    tomorrow_us: dayjs().add(1, "day").format("MM/DD/YYYY"),
};
function get_no_additional_fields_license() {
    return {
        license_id: 1,
        name: "license 1",
        description: "my first license",
        type: "local",
        status: "active",
        started_on: dates["today_iso"],
        ended_on: dates["tomorrow_iso"],
        user_roles: [],
        vendor_id: 1,
        vendor: [cy.get_vendors_to_relate()[0]],
        documents: [
            {
                license_id: 1,
                file_description: "file description",
                file_name: "file.json",
                notes: "file notes",
                physical_location: "file physical location",
                uri: "file uri",
                uploaded_on: "2022-10-27T11:57:02+00:00",
            },
        ],
        extended_attributes: [],
        _strings: {
            additional_field_values: [],
        },
    };
}
function get_license() {
    return {
        license_id: 1,
        name: "license 1",
        description: "my first license",
        type: "local",
        status: "active",
        started_on: dates["today_iso"],
        ended_on: dates["tomorrow_iso"],
        user_roles: [],
        vendor_id: 1,
        vendor: [cy.get_vendors_to_relate()[0]],
        documents: [
            {
                license_id: 1,
                file_description: "file description",
                file_name: "file.json",
                notes: "file notes",
                physical_location: "file physical location",
                uri: "file uri",
                uploaded_on: "2022-10-27T11:57:02+00:00",
            },
        ],
        extended_attributes: [
            {
                field_id: 1,
                id: "1",
                record_id: "1",
                value: "REF",
            },
            {
                field_id: 1,
                id: "2",
                record_id: "1",
                value: "NFIC",
            },
            {
                field_id: 2,
                id: "3",
                record_id: "1",
                value: "some text",
            },
            {
                field_id: 3,
                id: "4",
                record_id: "1",
                value: "some repeatable text",
            },
            {
                field_id: 4,
                id: "5",
                record_id: "1",
                value: "AF",
            },
        ],
        _strings: {
            additional_field_values: [
                {
                    field_id: 1,
                    field_label: "AV Repeatable",
                    type: "av",
                    value_str: "Reference, Non-fiction",
                },
                {
                    field_id: 2,
                    field_label: "Text non-repeatable",
                    type: "text",
                    value_str: "some text",
                },
                {
                    field_id: 3,
                    field_label: "Text repeatable",
                    type: "text",
                    value_str: "some repeatable text",
                },
                {
                    field_id: 4,
                    field_label: "AV Searchable",
                    type: "av",
                    value_str: "Afghanistan",
                },
            ],
        },
    };
}

function get_licenses_additional_fields() {
    return [
        {
            authorised_value_category_name: "CCODE",
            extended_attribute_type_id: 1,
            marcfield: "",
            marcfield_mode: "get",
            name: "AV Repeatable",
            repeatable: true,
            searchable: true,
            resource_type: "license",
        },
        {
            authorised_value_category_name: null,
            extended_attribute_type_id: 2,
            marcfield: "",
            marcfield_mode: "get",
            name: "Text non-repeatable",
            repeatable: false,
            searchable: false,
            resource_type: "license",
        },
        {
            authorised_value_category_name: null,
            extended_attribute_type_id: 3,
            marcfield: "",
            marcfield_mode: "get",
            name: "Text repeatable",
            repeatable: true,
            searchable: false,
            resource_type: "license",
        },
        {
            authorised_value_category_name: "COUNTRY",
            extended_attribute_type_id: 4,
            marcfield: "",
            marcfield_mode: "get",
            name: "AV Searchable",
            repeatable: false,
            searchable: true,
            resource_type: "license",
        },
    ];
}

function get_av_cats() {
    return [
        {
            authorised_values: [
                {
                    authorised_value_id: 1012,
                    category_name: "CCODE",
                    description: "Fiction",
                    image_url: null,
                    opac_description: null,
                    value: "FIC",
                },
                {
                    authorised_value_id: 1013,
                    category_name: "CCODE",
                    description: "Reference",
                    image_url: null,
                    opac_description: null,
                    value: "REF",
                },
                {
                    authorised_value_id: 1014,
                    category_name: "CCODE",
                    description: "Non-fiction",
                    image_url: null,
                    opac_description: null,
                    value: "NFIC",
                },
            ],
            category_name: "CCODE",
            is_system: true,
        },
        {
            authorised_values: [
                {
                    authorised_value_id: 111,
                    category_name: "COUNTRY",
                    description: "Andorra",
                    image_url: null,
                    opac_description: "Andorra",
                    value: "AD",
                },
                {
                    authorised_value_id: 112,
                    category_name: "COUNTRY",
                    description: "United Arab Emirates",
                    image_url: null,
                    opac_description: "United Arab Emirates",
                    value: "AE",
                },
                {
                    authorised_value_id: 113,
                    category_name: "COUNTRY",
                    description: "Afghanistan",
                    image_url: null,
                    opac_description: "Afghanistan",
                    value: "AF",
                },
            ],
            category_name: "COUNTRY",
            is_system: false,
        },
    ];
}

function get_description_from_av_value(av_cats, av_value): string {
    return av_cats
        .find(av_cat =>
            av_cat.authorised_values.find(av => av.value == av_value.value)
        )
        ?.authorised_values.find(av => av.value == av_value.value)?.description;
}

describe("Additional Fields operations", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept(
            "GET",
            "/api/v1/erm/config",
            '{"settings":{"ERMModule":"1","ERMProviders":["local"]}}'
        );
    });

    it("Additional Fields display - Table (licenses)", () => {
        let license = get_license();
        let licenses = [license];
        let license_additional_fields = get_licenses_additional_fields();
        let av_cats = get_av_cats();

        cy.intercept("GET", "/api/v1/extended_attribute_types*", {
            body: license_additional_fields,
            statusCode: 200,
        });

        cy.intercept("GET", "/api/v1/erm/licenses*", {
            statusCode: 200,
            body: licenses,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/erm/licenses/*", license);
        cy.visit("/cgi-bin/koha/erm/licenses");
        cy.get("#licenses_list").contains("Showing 1 to 1 of 1 entries");

        cy.get("#licenses_list table tbody tr:first").contains(
            get_description_from_av_value(
                av_cats,
                license.extended_attributes[4]
            )
        );
        cy.get("#licenses_list table tbody tr:first").contains(
            get_description_from_av_value(
                av_cats,
                license.extended_attributes[0]
            ) +
                ", " +
                get_description_from_av_value(
                    av_cats,
                    license.extended_attributes[1]
                )
        );
    });

    it("Additional Fields display - Show (licenses)", () => {
        let empty_license = get_no_additional_fields_license();
        let license = get_license();
        let licenses = [license];
        let vendors = cy.get_vendors_to_relate();
        let license_additional_fields = get_licenses_additional_fields();
        let av_cats = get_av_cats();

        // Click the 'Edit' button from the list
        cy.intercept("GET", "/api/v1/erm/licenses*", {
            statusCode: 200,
            body: licenses,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/erm/licenses/*", empty_license).as(
            "get-empty-license"
        );

        //Intercept vendors request
        cy.intercept("GET", "/api/v1/acquisitions/vendors*", {
            statusCode: 200,
            body: vendors,
        });
        cy.intercept("GET", "/api/v1/extended_attribute_types*", {
            body: [],
            statusCode: 200,
        }).as("empty-additional-fields");

        //Empty additional fields, should not display
        cy.visit("/cgi-bin/koha/erm/licenses");
        cy.get("#licenses_list table tbody tr:first td:first a").click();
        cy.wait("@get-empty-license");
        cy.get("#licenses_show #additional_fields").should("not.exist");

        cy.intercept("GET", "/api/v1/extended_attribute_types*", {
            body: license_additional_fields,
            statusCode: 200,
        }).as("existing-additional-fields");

        cy.intercept(
            {
                pathname: "/api/v1/authorised_value_categories",
                query: {
                    q: '{"me.category_name":["CCODE", "COUNTRY"]}',
                },
            },
            {
                body: av_cats,
                statusCode: 200,
            }
        ).as("avcategories");

        cy.intercept("GET", "/api/v1/erm/licenses/*", license).as(
            "get-license"
        );

        // There are additional fields, fieldset should exist
        cy.visit("/cgi-bin/koha/erm/licenses");
        cy.get("#licenses_list table tbody tr:first td:first a").click();
        cy.wait("@get-license");
        cy.get("#licenses_show #additional_fields").should("exist");

        // All fields are presented correctly
        cy.get(
            "#licenses_show #additional_fields label[for='additional_field_1']"
        ).contains(license_additional_fields[0].name);
        cy.get(
            "#licenses_show #additional_fields label[for='additional_field_1']"
        )
            .parent()
            .children("span")
            .contains(
                get_description_from_av_value(
                    av_cats,
                    license.extended_attributes[0]
                ) +
                    ", " +
                    get_description_from_av_value(
                        av_cats,
                        license.extended_attributes[1]
                    )
            );

        cy.get(
            "#licenses_show #additional_fields label[for='additional_field_2']"
        ).contains(license_additional_fields[1].name);
        cy.get(
            "#licenses_show #additional_fields label[for='additional_field_2']"
        )
            .parent()
            .children("span")
            .contains(license.extended_attributes[2].value);

        cy.get(
            "#licenses_show #additional_fields label[for='additional_field_3']"
        ).contains(license_additional_fields[2].name);
        cy.get(
            "#licenses_show #additional_fields label[for='additional_field_3']"
        )
            .parent()
            .children("span")
            .contains(license.extended_attributes[3].value);

        cy.get(
            "#licenses_show #additional_fields label[for='additional_field_4']"
        ).contains(license_additional_fields[3].name);
        cy.get(
            "#licenses_show #additional_fields label[for='additional_field_4']"
        )
            .parent()
            .children("span")
            .contains(
                get_description_from_av_value(
                    av_cats,
                    license.extended_attributes[4]
                )
            );
    });

    it("Additional Fields entry - Add (licenses)", () => {
        let vendors = cy.get_vendors_to_relate();
        let license_additional_fields = get_licenses_additional_fields();
        let av_cats = get_av_cats();

        //Intercept vendors request
        cy.intercept("GET", "/api/v1/acquisitions/vendors*", {
            statusCode: 200,
            body: vendors,
        });
        cy.intercept("GET", "/api/v1/extended_attribute_types*", {
            body: [],
            statusCode: 200,
        }).as("empty-additional-fields");

        // No additional fields, fieldset should not exist
        cy.visit("/cgi-bin/koha/erm/licenses/add");
        cy.get("#licenses_add form #additional_fields").should("not.exist");

        cy.intercept("GET", "/api/v1/extended_attribute_types*", {
            body: license_additional_fields,
            statusCode: 200,
        }).as("existing-additional-fields");

        cy.intercept(
            {
                pathname: "/api/v1/authorised_value_categories",
                query: {
                    q: '{"me.category_name":["CCODE", "COUNTRY"]}',
                },
            },
            {
                body: av_cats,
                statusCode: 200,
            }
        ).as("avcategories");
        // There are additional fields, fieldset should exist
        cy.visit("/cgi-bin/koha/erm/licenses/add");
        cy.get("#licenses_add form #additional_fields").should("exist");

        // All additional fields should be listed
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_1']"
        ).contains(license_additional_fields[0].name);
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_2']"
        ).contains(license_additional_fields[1].name);
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_3']"
        ).contains(license_additional_fields[2].name);
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_4']"
        ).contains(license_additional_fields[3].name);

        cy.get("#additional_fields #additional_field_1 .vs__selected").should(
            "not.exist"
        ); //new license, no pre-selected value

        // Pick one value
        cy.get("#additional_fields #additional_field_1 .vs__search").click();
        cy.get(
            "#additional_fields #additional_field_1 #vs4__option-0"
        ).contains(av_cats[0].authorised_values[0].description);
        cy.get("#additional_fields #additional_field_1 #vs4__option-0").click();
        cy.get("#additional_fields #additional_field_1 .vs__selected").contains(
            av_cats[0].authorised_values[0].description
        );
        cy.get("#additional_fields #additional_field_1 .vs__selected").should(
            "have.length",
            1
        );

        // Pick a second value for the same repeatable AV field
        cy.get("#additional_fields #additional_field_1 .vs__search").click();
        cy.get(
            "#additional_fields #additional_field_1 #vs4__option-1"
        ).contains(av_cats[0].authorised_values[1].description);
        cy.get("#additional_fields #additional_field_1 #vs4__option-1").click();
        cy.get("#additional_fields #additional_field_1 .vs__selected").contains(
            av_cats[0].authorised_values[1].description
        );
        cy.get("#additional_fields #additional_field_1 .vs__selected").should(
            "have.length",
            2
        );

        // Attempt to pick the same value again - should not be possible
        cy.get("#additional_fields #additional_field_1 .vs__search").click();
        cy.get(
            "#additional_fields #additional_field_1 #vs4__option-1"
        ).contains(av_cats[0].authorised_values[1].description);
        cy.get("#additional_fields #additional_field_1 #vs4__option-1").click();
        cy.get("#additional_fields #additional_field_1 .vs__selected").should(
            "have.length",
            2
        );

        // Remove the second selected value
        cy.get(
            "#additional_fields #additional_field_1 .vs__selected button[title='Deselect " +
                av_cats[0].authorised_values[1].description +
                "'"
        ).click();
        cy.get("#additional_fields #additional_field_1 .vs__selected").should(
            "have.length",
            1
        );
        cy.get("#additional_fields #additional_field_1 .vs__selected").contains(
            av_cats[0].authorised_values[0].description
        );
    });

    it("Additional Fields entry - Edit (licenses)", () => {
        let license = get_license();
        let licenses = [license];
        let vendors = cy.get_vendors_to_relate();
        let license_additional_fields = get_licenses_additional_fields();
        let av_cats = get_av_cats();

        // Click the 'Edit' button from the list
        cy.intercept("GET", "/api/v1/erm/licenses*", {
            statusCode: 200,
            body: licenses,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/erm/licenses/*", license).as(
            "get-license"
        );

        //Intercept vendors request
        cy.intercept("GET", "/api/v1/acquisitions/vendors*", {
            statusCode: 200,
            body: vendors,
        });

        cy.intercept("GET", "/api/v1/extended_attribute_types*", {
            body: license_additional_fields,
            statusCode: 200,
        }).as("existing-additional-fields");

        cy.intercept(
            {
                pathname: "/api/v1/authorised_value_categories",
                query: {
                    q: '{"me.category_name":["CCODE", "COUNTRY"]}',
                },
            },
            {
                body: av_cats,
                statusCode: 200,
            }
        ).as("avcategories");

        cy.visit("/cgi-bin/koha/erm/licenses");
        cy.get("#licenses_list table tbody tr:first").contains("Edit").click();
        cy.wait("@get-license");
        cy.wait(500); // Cypress is too fast! Vue hasn't populated the form yet!

        // All additional fields should be pre-populated
        cy.get("#additional_fields #additional_field_1 .vs__selected").contains(
            get_description_from_av_value(
                av_cats,
                license.extended_attributes[0]
            )
        );
        cy.get("#additional_fields #additional_field_1 .vs__selected").contains(
            get_description_from_av_value(
                av_cats,
                license.extended_attributes[1]
            )
        );

        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_2']"
        )
            .parent()
            .children("input")
            .should("have.value", license.extended_attributes[2].value);

        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_3']"
        )
            .parent()
            .children("input")
            .should("have.value", license.extended_attributes[3].value);

        cy.get("#additional_fields #additional_field_4 .vs__selected").contains(
            get_description_from_av_value(
                av_cats,
                license.extended_attributes[4]
            )
        );

        // Clear text field works
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_2']"
        )
            .parent()
            .children(".clear_attribute")
            .click();
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_2']"
        )
            .parent()
            .children("input")
            .should("have.value", "");

        // "+New" text field works
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_3']"
        ).should("have.length", 1);
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_3']"
        )
            .parent()
            .children(".clone_attribute")
            .click();
        cy.get(
            "#licenses_add form #additional_fields label[for='additional_field_3']"
        ).should("have.length", 2);
    });
});
