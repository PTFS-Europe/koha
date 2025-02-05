<script>
import BaseResource from "../BaseResource.vue"
import { APIClient } from "../../fetch/api-client.js"

export default {
    extends: BaseResource,
    props: {
        routeAction: String,
    },
    setup(props) {
        return {
            ...BaseResource.setup({
                resourceName: "account",
                nameAttr: "login_id",
                idAttr: "sip_account_id",
                showComponent: "SIP2AccountsShow",
                listComponent: "SIP2AccountsList",
                addComponent: "SIP2AccountsFormAdd",
                editComponent: "SIP2AccountsFormAddEdit",
                apiClient: APIClient.sip2.accounts,
                resourceTableUrl: APIClient.sip2._baseURL + "accounts",
                formGroupsDisplayMode: "accordion", // or default 'groups'
                i18n: {
                    displayName: __("Account"),
                    displayNameLowerCase: __("account"),
                    displayNamePlural: __("accounts"),
                },
            }),
        }
    },
    data() {
        return {
            resourceAttrs: [
                {
                    name: "login_id",
                    required: true,
                    type: "text",
                    label: __("Account login id"),
                    group: "Details",
                },
                {
                    name: "login_password",
                    required: true,
                    type: "text",
                    label: __("Account login password"),
                    group: "Details",
                },
                {
                    name: "sip_institution_id",
                    type: "relationshipSelect",
                    label: __("Institution"),
                    required: true,
                    showElement: {
                        type: "text",
                        value: "institution.name",
                        link: {
                            href: "/cgi-bin/koha/sip2/institutions/1",
                            // params: {
                            //     bookseller_id: "vendor_id",
                            // },
                        },
                    },
                    relationshipAPIClient: APIClient.sip2.institutions,
                    relationshipOptionLabelAttr: "name", // attr of the related resource used for display
                    group: "Details",
                },
                {
                    name: "allow_additional_materials_checkout",
                    type: "boolean",
                    label: __("Allow additional materials checkout"),
                    group: "Details",
                    toolTip: __(
                        "If enabled, allows patrons to check out items via SIP even if the item has additional materials"
                    ),
                },
                {
                    name: "allow_empty_passwords",
                    type: "boolean",
                    label: __("Allow empty passwords"),
                    group: "Details",
                },
                {
                    name: "allow_fields",
                    type: "text",
                    label: __("Allow fields"),
                    placeholder: "AO,AA,AE",
                    group: "Details",
                    toolTip: __(
                        "Hides all fields not in the list, it is the inverse of hide_fields ( hide_fields takes precedence )"
                    ),
                },
                {
                    name: "blocked_item_types",
                    type: "text",
                    label: __("Blocked item types"),
                    placeholder: "VM|MU",
                    group: "Details",
                    toolTip: __(
                        "List of item types that are blocked from being issued at this SIP account"
                    ),
                },
                {
                    name: "checked_in_ok",
                    type: "boolean",
                    label: __("Checked in OK"),
                    group: "Details",
                },
                {
                    name: "convert_nonprinting_characters",
                    type: "text",
                    label: __("Convert nonprinting characters"),
                    group: "Details",
                    toolTip: __(
                        "Convert control and non-space separator characters into the given string"
                    ),
                },
                {
                    name: "cr_item_field",
                    type: "text",
                    label: __("CR item field"),
                    placeholder: "shelving_location",
                    group: "Details",
                    toolTip: __(
                        "Arbitrary item field to be used as the value for the CR field. Defaults to 'collection_code'"
                    ),
                },
                {
                    name: "ct_always_send",
                    type: "boolean",
                    label: __("CT always send"),
                    group: "Details",
                    toolTip: __(
                        "Always send the CT field, even if it is empty"
                    ),
                },
                {
                    name: "cv_send_00_on_success",
                    type: "boolean",
                    label: __("CV always send 00 on success"),
                    group: "Details",
                    toolTip: __(
                        'Checkin success message to return a CV field of value "00" rather than no CV field at all'
                    ),
                },
                {
                    name: "cv_triggers_alert",
                    type: "boolean",
                    label: __("CV triggers alert"),
                    group: "Details",
                    toolTip: __(
                        "Only set the alert flag if a value in the CV field is sent"
                    ),
                },
                {
                    name: "delimiter",
                    type: "text",
                    label: __("Delimiter"),
                    placeholder: "|",
                    group: "Details",
                },
                {
                    name: "encoding",
                    type: "text",
                    label: __("Encoding"),
                    placeholder: "utf-8",
                    group: "Details",
                },
                {
                    name: "error_detect",
                    type: "boolean",
                    label: __("Error detect"),
                    group: "Details",
                },
                {
                    name: "format_due_date",
                    type: "boolean",
                    label: __("Format due date"),
                    group: "Details",
                },
                {
                    name: "hide_fields",
                    type: "text",
                    label: __("Hide fields"),
                    placeholder: "BD,BE,BF,PB",
                    group: "Details",
                },
                {
                    name: "holds_block_checkin",
                    type: "boolean",
                    label: __("Holds block checkin"),
                    group: "Details",
                },
                {
                    name: "holds_get_captured",
                    type: "boolean",
                    label: __("Holds get captured"),
                    group: "Details",
                },
                {
                    name: "inhouse_item_types",
                    type: "text",
                    label: __("Inhouse item types"),
                    placeholder: "VM|MU",
                    group: "Details",
                },
                {
                    name: "inhouse_patron_categories",
                    type: "text",
                    label: __("Inhouse patron categories"),
                    placeholder: "S|ST|T",
                    group: "Details",
                },
                {
                    name: "lost_status_for_missing",
                    type: "text",
                    label: __("Lost status for missing"),
                    placeholder: "4",
                    group: "Details",
                    toolTip: __(
                        "Defines which Koha lost status will return the circulation status 13 ( i.e. missing ) for this account"
                    ),
                },
                {
                    name: "overdues_block_checkout",
                    type: "boolean",
                    label: __("Overdues block checkout"),
                    group: "Details",
                },
                {
                    name: "prevcheckout_block_checkout",
                    type: "boolean",
                    label: __("Previous checkout block checkout"),
                    group: "Details",
                },
                {
                    name: "register_id",
                    type: "text",
                    label: __("Cash register id"),
                    placeholder: __(
                        "TODO: Add relationship select to cash registers"
                    ),
                    group: "Details",
                },
                {
                    name: "seen_on_item_information",
                    type: "text",
                    label: __("Seen on item information"),
                    placeholder:
                        "'mark_found' or 'keep_lost'. Empty to disable",
                    group: "Details",
                },
                {
                    name: "send_patron_home_library_in_af",
                    type: "boolean",
                    label: __("Send patron home library in AF"),
                    group: "Details",
                },
                {
                    name: "show_checkin_message",
                    type: "boolean",
                    label: __("Show checkin message"),
                    group: "Details",
                    toolTip: __(
                        "If enabled, successful checking responses will contain an AF screen message"
                    ),
                },
                {
                    name: "show_outstanding_amount",
                    type: "boolean",
                    label: __("Show outstanding amount"),
                    group: "Details",
                    toolTip: __(
                        "If enabled, if the patron has outstanding charges, the total outstanding amount is displayed on SIP checkout"
                    ),
                },
                {
                    name: "terminator",
                    type: "select",
                    options: [
                        { value: "CRLF", description: "CRLF" },
                        { value: "CR", description: "CR" },
                        { value: null, description: __("Empty") },
                    ],
                    requiredKey: "value",
                    selectLabel: "description",
                    label: __("Terminator"),
                    placeholder: "CRLF",
                    group: "Details",
                },
                {
                    name: "custom_patron_fields",
                    type: "relationshipWidget",
                    showElement: {
                        type: "table",
                        columnData: "custom_patron_fields",
                        hidden: account =>
                            !!account.custom_patron_fields?.length,
                        columns: [
                            {
                                name: __("Field"),
                                value: "field",
                            },
                            {
                                name: __("Template"),
                                value: "template",
                            },
                        ],
                    },
                    group: __("SIP response mappings"),
                    componentProps: {
                        resourceRelationships: {
                            resourceProperty: "custom_patron_fields",
                        },
                        relationshipStrings: {
                            nameLowerCase: __("custom patron field"),
                            nameUpperCase: __("Custom patron field"),
                            namePlural: __("custom patron fields"),
                        },
                        newRelationshipDefaultAttrs: {
                            type: "object",
                            value: {
                                field: null,
                                template: null,
                            },
                        },
                    },
                    relationshipFields: [
                        {
                            name: "field",
                            required: true,
                            type: "text",
                            placeholder: "XY",
                            label: __("Field"),
                        },
                        {
                            name: "template",
                            required: true,
                            type: "text",
                            placeholder: "[% patron.dateexpiry %]",
                            label: __("Template"),
                        },
                    ],
                },
                {
                    name: "patron_attributes",
                    type: "relationshipWidget",
                    showElement: {
                        type: "table",
                        columnData: "patron_attributes",
                        hidden: account => !!account.patron_attributes?.length,
                        columns: [
                            {
                                name: __("Field"),
                                value: "field",
                            },
                            {
                                name: __("Code"),
                                value: "code",
                            },
                        ],
                    },
                    group: __("SIP response mappings"),
                    componentProps: {
                        resourceRelationships: {
                            resourceProperty: "patron_attributes",
                        },
                        relationshipStrings: {
                            nameLowerCase: __("patron attribute"),
                            nameUpperCase: __("Patron attribute"),
                            namePlural: __("patron attributes"),
                        },
                        newRelationshipDefaultAttrs: {
                            type: "object",
                            value: {
                                field: null,
                                code: null,
                            },
                        },
                    },
                    relationshipFields: [
                        {
                            name: "field",
                            required: true,
                            type: "text",
                            placeholder: "XY",
                            label: __("Field"),
                        },
                        {
                            name: "code",
                            required: true,
                            type: "text",
                            placeholder: "CODE",
                            label: __("Code"),
                        },
                    ],
                },
                {
                    name: "custom_item_fields",
                    type: "relationshipWidget",
                    showElement: {
                        type: "table",
                        columnData: "custom_item_fields",
                        hidden: account => !!account.custom_item_fields?.length,
                        columns: [
                            {
                                name: __("Field"),
                                value: "field",
                            },
                            {
                                name: __("Template"),
                                value: "template",
                            },
                        ],
                    },
                    group: __("SIP response mappings"),
                    componentProps: {
                        resourceRelationships: {
                            resourceProperty: "custom_item_fields",
                        },
                        relationshipStrings: {
                            nameLowerCase: __("custom item field"),
                            nameUpperCase: __("Custom item field"),
                            namePlural: __("custom item fields"),
                        },
                        newRelationshipDefaultAttrs: {
                            type: "object",
                            value: {
                                field: null,
                                template: null,
                            },
                        },
                    },
                    relationshipFields: [
                        {
                            name: "field",
                            required: true,
                            type: "text",
                            placeholder: "IN",
                            label: __("Field"),
                        },
                        {
                            name: "template",
                            required: true,
                            type: "text",
                            placeholder: "[% item.itemnumber %]",
                            label: __("Template"),
                        },
                    ],
                },
                {
                    name: "item_fields",
                    type: "relationshipWidget",
                    showElement: {
                        type: "table",
                        columnData: "item_fields",
                        hidden: account => !!account.item_fields?.length,
                        columns: [
                            {
                                name: __("Field"),
                                value: "field",
                            },
                            {
                                name: __("Code"),
                                value: "code",
                            },
                        ],
                    },
                    group: __("SIP response mappings"),
                    componentProps: {
                        resourceRelationships: {
                            resourceProperty: "item_fields",
                        },
                        relationshipStrings: {
                            nameLowerCase: __("item field"),
                            nameUpperCase: __("Item field"),
                            namePlural: __("item fields"),
                        },
                        newRelationshipDefaultAttrs: {
                            type: "object",
                            value: {
                                field: null,
                                code: null,
                            },
                        },
                    },
                    relationshipFields: [
                        {
                            name: "field",
                            required: true,
                            type: "text",
                            placeholder: "XY",
                            label: __("Field"),
                        },
                        {
                            name: "code",
                            required: true,
                            type: "text",
                            placeholder: "permanent_location",
                            label: __("Code"),
                        },
                    ],
                },
                {
                    name: "system_preference_overrides",
                    type: "relationshipWidget",
                    showElement: {
                        type: "table",
                        columnData: "system_preference_overrides",
                        hidden: account =>
                            !!account.system_preference_overrides?.length,
                        columns: [
                            {
                                name: __("Variable"),
                                value: "variable",
                            },
                            {
                                name: __("Value"),
                                value: "value",
                            },
                        ],
                    },
                    group: __("Syspref overrides"),
                    componentProps: {
                        resourceRelationships: {
                            resourceProperty: "system_preference_overrides",
                        },
                        relationshipStrings: {
                            nameLowerCase: __("system preference override"),
                            nameUpperCase: __("System preference override"),
                            namePlural: __("system preference overrides"),
                        },
                        newRelationshipDefaultAttrs: {
                            type: "object",
                            value: {
                                variable: null,
                                value: null,
                            },
                        },
                    },
                    relationshipFields: [
                        {
                            name: "variable",
                            required: true,
                            type: "text",
                            placeholder: "AllFinesNeedOverride",
                            label: __("Variable"),
                        },
                        {
                            name: "value",
                            required: true,
                            type: "text",
                            placeholder: "1",
                            label: __("Value"),
                        },
                    ],
                },
                {
                    name: "ae_field_template",
                    type: "textarea",
                    label: __("AE field template"),
                    placeholder:
                        "[% patron.surname %][% IF patron.firstname %], [% patron.firstname %][% END %]",
                    group: "Templates",
                },
                {
                    name: "av_field_template",
                    type: "textarea",
                    label: __("AV field template"),
                    placeholder:
                        "[% accountline.description %] [% accountline.amountoutstanding | format('%.2f') %]",
                    group: "Templates",
                },
                {
                    name: "da_field_template",
                    type: "textarea",
                    label: __("DA field template"),
                    placeholder:
                        "[% patron.surname %][% IF patron.firstname %], [% patron.firstname %][% END %]",
                    group: "Templates",
                },
            ],
            tableOptions: {
                columns: this.getTableColumns(),
                url: () => this.resourceTableUrl,
                options: { embed: "institution" },
                table_settings: this.accounts_table_settings,
                actions: {
                    0: ["show"],
                    "-1": this.embedded
                        ? [
                              {
                                  select: {
                                      text: this.$__("Select"),
                                      icon: "fa fa-check",
                                  },
                              },
                          ]
                        : ["edit", "delete"],
                },
            },
        }
    },
    methods: {
        getTableColumns: function () {
            return [
                {
                    title: __("Login"),
                    data: "login_id:sip_account_id",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return (
                            '<a role="button" class="show">' +
                            escape_str(
                                `${row.login_id} (#${row.sip_account_id})`
                            ) +
                            "</a>"
                        )
                    },
                },
                {
                    title: __("Institution"),
                    data: "sip_institution_id",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return row.sip_institution_id != undefined
                            ? '<a href="/cgi-bin/koha/sip2/institutions/' +
                                  row.sip_institution_id +
                                  '">' +
                                  escape_str(row.institution.name) +
                                  "</a>"
                            : ""
                    },
                },
                {
                    title: __("Delimiter"),
                    data: "delimiter",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: __("Encoding"),
                    data: "encoding",
                    searchable: true,
                    orderable: true,
                },
                {
                    title: __("Error detect"),
                    data: "error_detect",
                    searchable: true,
                    orderable: true,
                    render: function (data, type, row, meta) {
                        return escape_str(
                            row.error_detect ? __("Yes") : __("No")
                        )
                    },
                },
                {
                    title: __("Terminator"),
                    data: "terminator",
                    searchable: true,
                    orderable: true,
                },
            ]
        },
        onSubmit(e, accountToSave) {
            e.preventDefault()

            let account = JSON.parse(JSON.stringify(accountToSave)) // copy
            let sip_account_id = account.sip_account_id

            delete account.sip_account_id

            if (!account.terminator) {
                account.terminator = null
            }

            account.item_fields = account.item_fields.map(
                ({ account_id, account_item_field_id, ...keepAttrs }) =>
                    keepAttrs
            )

            account.patron_attributes = account.patron_attributes.map(
                ({ account_id, account_patron_attribute_id, ...keepAttrs }) =>
                    keepAttrs
            )

            const client = APIClient.sip2
            if (sip_account_id) {
                client.accounts.update(account, sip_account_id).then(
                    success => {
                        this.setMessage(this.$__("Account updated"))
                        this.$router.push({ name: "SIP2AccountsList" })
                    },
                    error => {}
                )
            } else {
                client.accounts.create(account).then(
                    success => {
                        this.setMessage(this.$__("Account created"))
                        this.$router.push({ name: "SIP2AccountsList" })
                    },
                    error => {}
                )
            }
        },
    },
    name: "SIP2AccountResource",
}
</script>
