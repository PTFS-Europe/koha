import { mount } from "@cypress/vue";

function get_institution() {
    return {
        checkin: true,
        checkout: true,
        implementation: "ILS",
        name: "kohalibrary2",
        offline: false,
        renewal: false,
        retries: 3,
        sip_institution_id: 119,
        status_update: false,
        timeout: 100
    };
}

describe("Institutions", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("List institutions", () => {
        // GET institutions returns 500
        cy.intercept("GET", "/api/v1/sip2/institutions*", {
            statusCode: 500,
            error: "Something went wrong",
        });
        cy.visit("/cgi-bin/koha/sip2/sip2.pl");
        cy.get("#navmenulist").contains("Institutions").click();
        cy.get("main div[class='alert alert-warning']").contains(
            /Something went wrong/
        );

        // GET institutions returns empty list
        cy.intercept("GET", "/api/v1/sip2/institutions*", []);
        cy.visit("/cgi-bin/koha/sip2/institutions");
        cy.get("#institution_list").contains("There are no institutions defined");

        // GET institutions returns something
        let institution = get_institution();
        let institutions = [institution];

        cy.intercept("GET", "/api/v1/sip2/institutions*", {
            statusCode: 200,
            body: institutions,
            headers: {
                "X-Base-Total-Count": "1",
                "X-Total-Count": "1",
            },
        });
        cy.intercept("GET", "/api/v1/sip2/institutions/*", institution);
        cy.visit("/cgi-bin/koha/sip2/institutions/");
        cy.get("#institution_list").contains("Showing 1 to 1 of 1 entries");
    });

    it("Add institution", () => {
        let institution = cy.get_institution();
        // No agreement, no license yet
        cy.intercept("GET", "/api/v1/erm/agreements*", {
            statusCode: 200,
            body: [],
        });
        cy.intercept("GET", "/api/v1/erm/licenses*", {
            statusCode: 200,
            body: [],
        });
        //Intercept vendors request
        cy.intercept("GET", "/api/v1/acquisitions/vendors*", {
            statusCode: 200,
            body: vendors,
        });

        cy.intercept("GET", "/api/v1/authorised_value_categories*", {
            statusCode: 200,
            body: av_cat_values,
        }).as("get-ERM-av-cats-values");

        // Click the button in the toolbar
        cy.visit("/cgi-bin/koha/sip2/institutions");
        cy.contains("New institution").click();
        cy.get("#agreements_add h2").contains("New agreement");
        cy.left_menu_active_item_is("Agreements");

        // Fill in the form for normal attributes
        cy.get("#agreements_add").contains("Submit").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length",
            2
        );
        cy.get("#agreement_name").type(agreement.name);
        cy.get("#agreement_description").type(agreement.description);
        cy.get("#agreements_add").contains("Submit").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length",
            1
        ); // name, description, status

        cy.get("#agreement_status .vs__search").type("closed" + "{enter}", {
            force: true,
        });

        cy.get("#agreement_closure_reason .vs__search").click();
        let closure_reasons = av_cat_values.find(
            av_cat => av_cat.category_name === "ERM_AGREEMENT_CLOSURE_REASON"
        );
        cy.get("#agreement_closure_reason #vs3__option-0").contains(
            closure_reasons.authorised_values[0].description
        );
        cy.get("#agreement_closure_reason #vs3__option-1").should("be.empty");

        cy.get("#agreement_status .vs__search").type(
            agreement.status + "{enter}",
            { force: true }
        );

        // vendors
        cy.get("#agreement_vendor_id .vs__selected").should("not.exist"); //no vendor pre-selected for new agreement

        cy.get("#agreement_vendor_id .vs__search").type(
            vendors[0].name + "{enter}",
            { force: true }
        );
        cy.get("#agreement_vendor_id .vs__selected").contains(vendors[0].name);

        // vendor aliases
        cy.get("#agreement_vendor_id .vs__search").click();
        cy.get("#agreement_vendor_id #vs1__option-1").contains(vendors[1].name);
        cy.get("#agreement_vendor_id #vs1__option-1 cite").contains(
            vendors[1].aliases[0].alias
        );

        cy.contains("Add new period").click();
        cy.get("#agreements_add").contains("Submit").click();
        cy.get("input:invalid,textarea:invalid,select:invalid").should(
            "have.length",
            1
        ); // Start date

        // Add new periods
        cy.contains("Add new period").click();
        cy.contains("Add new period").click();
        cy.get("#agreement_periods > fieldset").should("have.length", 3);

        cy.get("#agreement_period_1").contains("Remove this period").click();

        cy.get("#agreement_periods > fieldset").should("have.length", 2);
        cy.get("#agreement_period_0");
        cy.get("#agreement_period_1");

        // Selecting the flatpickr values is a bit tedious here...
        // We have 3 date inputs per period
        cy.get("#ended_on_0+input").click();
        // Second flatpickr => ended_on for the first period
        cy.get(".flatpickr-calendar")
            .eq(1)
            .find("span.today")
            .click({ force: true }); // select today. No idea why we should force, but there is a random failure otherwise

        cy.get("#started_on_0+input").click();
        cy.get(".flatpickr-calendar")
            .eq(0)
            .find("span.today")
            .next("span")
            .click(); // select tomorrow

        cy.get("#ended_on_0").should("have.value", ""); // Has been reset correctly

        cy.get("#started_on_0+input").click();
        cy.get(".flatpickr-calendar").eq(0).find("span.today").click(); // select today
        cy.get("#ended_on_0+input").click({ force: true }); // No idea why we should force, but there is a random failure otherwise
        cy.get(".flatpickr-calendar")
            .eq(1)
            .find("span.today")
            .next("span")
            .click(); // select tomorrow

        // Second period
        cy.get("#started_on_1+input").click({ force: true });
        cy.get(".flatpickr-calendar").eq(3).find("span.today").click(); // select today
        cy.get("#cancellation_deadline_1+input").click();
        cy.get(".flatpickr-calendar")
            .eq(5)
            .find("span.today")
            .next("span")
            .click(); // select tomorrow
        cy.get("#notes_1").type("this is a note");

        // TODO Add a new user
        // How to test a new window with cypresS?
        //cy.contains("Add new user").click();
        //cy.contains("Select user").click();

        cy.get("#agreement_licenses").contains(
            "There are no licenses created yet"
        );
        cy.get("#agreement_relationships").contains(
            "There are no other agreements created yet"
        );

        // Add new document
        cy.get("#documents").contains("Add new document").click();
        cy.get("#document_0 input[id=file_0]").click();
        cy.get("#document_0 input[id=file_0]").selectFile(
            "t/cypress/fixtures/file.json"
        );
        cy.get("#document_0 .file_information span").contains("file.json");
        cy.get("#document_0 input[id=file_description_0]").type(
            "file description"
        );
        cy.get("#document_0 input[id=physical_location_0]").type(
            "file physical location"
        );
        cy.get("#document_0 input[id=uri_0]").type("file URI");
        cy.get("#document_0 input[id=notes_0]").type("file notes");

        // Submit the form, get 500
        cy.intercept("POST", "/api/v1/erm/agreements", {
            statusCode: 500,
        });
        cy.get("#agreements_add").contains("Submit").click();
        cy.get("main div[class='alert alert-warning']").contains(
            "Something went wrong: Error: Internal Server Error"
        );

        // Submit the form, success!
        cy.intercept("POST", "/api/v1/erm/agreements", {
            statusCode: 201,
            body: agreement,
        });
        cy.get("#agreements_add").contains("Submit").click();
        cy.get("main div[class='alert alert-info']").contains(
            "Agreement created"
        );

        cy.intercept("GET", "/api/v1/erm/agreements*", {
            statusCode: 200,
            body: [{ agreement_id: 1, description: "an existing agreement" }],
        });

        // Add new license
        let licenses_to_relate = cy.get_licenses_to_relate();
        let related_license = agreement.agreement_licenses[0];
        let licenses_count = licenses_to_relate.length.toString();
        cy.intercept("GET", "/api/v1/erm/licenses*", {
            statusCode: 200,
            body: licenses_to_relate,
            headers: {
                "X-Base-Total-Count": licenses_count,
                "X-Total-Count": licenses_count,
            },
        });
        cy.visit("/cgi-bin/koha/erm/agreements/add");
        cy.get("#agreement_licenses").contains("Add new license").click();
        cy.get("#agreement_license_0").contains("Agreement license 1");
        cy.get("#agreement_license_0 #license_id_0 .vs__search").type(
            related_license.license.name
        );
        cy.get("#agreement_license_0 #license_id_0 .vs__dropdown-menu li")
            .eq(0)
            .click({ force: true }); //click first license suggestion
        cy.get("#agreement_license_0 #license_status_0 .vs__search").type(
            related_license.status + "{enter}",
            { force: true }
        );
        cy.get("#agreement_license_0 #license_location_0 .vs__search").type(
            related_license.physical_location + "{enter}",
            { force: true }
        );
        cy.get("#agreement_license_0 #license_notes_0").type(
            related_license.notes
        );
        cy.get("#agreement_license_0 #license_uri_0").type(related_license.uri);

        // Add new related agreement
        let related_agreement = agreement.agreement_relationships[0];
        cy.intercept("GET", "/api/v1/erm/agreements*", {
            statusCode: 200,
            body: cy.get_agreements_to_relate(),
        });
        cy.visit("/cgi-bin/koha/erm/agreements/add");
        cy.get("#agreement_relationships")
            .contains("Add new related agreement")
            .click();
        cy.get("#related_agreement_0").contains("Related agreement 1");
        cy.get("#related_agreement_0 #related_agreement_id_0 .vs__search").type(
            related_agreement.related_agreement.name
        );
        cy.get(
            "#related_agreement_0 #related_agreement_id_0 .vs__dropdown-menu li"
        )
            .eq(0)
            .click({ force: true }); //click first agreement suggestion
        cy.get("#related_agreement_0 #related_agreement_notes_0").type(
            related_agreement.notes
        );
        cy.get(
            "#related_agreement_0 #related_agreement_relationship_0 .vs__search"
        ).type(related_agreement.relationship + "{enter}", { force: true });
    });
});
