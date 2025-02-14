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
});
