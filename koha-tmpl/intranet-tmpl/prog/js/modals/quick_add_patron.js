$(document).ready(function() {
 $("#quick_add_user_button").on("click", function () {
     if (!$("#libraries_quick_add").children("option").length) {
         _GETLibraries();
     }
     if (!$("#categorycode_entry_quick_add").children("optgroup").length) {
         _GETPatronCategories();
     }
     $("#addQuickAddUserModal").modal("show");
     $(".dialog.alert").remove();
 });

 $("#addQuickAddUserModal").on("click", "#addConfirm", function (e) {
     e.preventDefault();
     if (!$("#quick_add_user_form").get(0).checkValidity()) {
         $("#quick_add_user_form").get(0).reportValidity();
     } else {
         $("#user-submit-spinner").show();
         _POSTPatron({
             surname: $("#surname_quick_add").val(),
             cardnumber: $("#cardnumber_quick_add").val(),
             library_id: $("#libraries_quick_add").val(),
             category_id: $("#categorycode_entry_quick_add").val(),
         });
     }
 });

 /**
  * Sends a GET request to the /api/v1/patron_categories endpoint to fetch patron categories
  *
  * Upon success, adds the categories to the category dropdown
  */
 function _GETPatronCategories() {
     $.ajax({
         url: "/api/v1/patron_categories",
         type: "GET",
         success: function (data) {
             let groupedCategories = Object.groupBy(
                 data,
                 ({ category_type }) => category_type
             );

             // Add <optgroup>
             $.each(groupedCategories, function (category_code, categories) {
                 $("#categorycode_entry_quick_add").append(
                     $(
                         '<optgroup id="' +
                             category_code +
                             '"label="' +
                             _getCategoryTypeName(category_code) +
                             '"></optgroup>'
                     )
                 );

                 // Add <option>
                 $.each(categories, function (i, category) {
                     $(
                         "#categorycode_entry_quick_add #" + category_code
                     ).append(
                         $("<option></option>")
                             .val(category.patron_category_id)
                             .html(category.name)
                     );
                 });
             });
         },
         error: function (data) {
             console.log(data);
         },
     });
 }

 /**
  * Sends a GET request to the /api/v1/libraries endpoint to fetch libraries
  *
  * Upon success, adds the libraries to the library dropdown
  */
 function _GETLibraries() {
     $.ajax({
         url: "/api/v1/libraries",
         type: "GET",
         success: function (data) {
             $.each(data, function (val, text) {
                 $("#libraries_quick_add").append(
                     $("<option></option>").val(text.library_id).html(text.name)
                 );
             });
         },
         error: function (data) {
             console.log(data);
         },
     });
 }

 /**
  * Sends a POST request to the /api/v1/patrons endpoint to add a new patron
  *
  * Upon completion, show a dialog with appropriate message
  * Upon success, add new patron's cardnumber to the cardnumber input
  *
  * @param {Object}   params           Patron's data to be posted.
  */
 function _POSTPatron(params) {
     $.ajax({
         url: "/api/v1/patrons",
         type: "POST",
         headers: { "Content-Type": "application/json;charset=utf-8" },
         data: JSON.stringify(params),
         success: function (data) {
             $("#user-submit-spinner").hide();
             $("#addQuickAddUserModal").modal("hide");
             $("#surname_quick_add").val("");
             $("#cardnumber_quick_add").val("");
             $("#toolbar").before(
                 '<div class="dialog message">' +
                     __(
                         'Patron sucessfully created: </br> <strong><a target="_blank" href="/cgi-bin/koha/members/moremember.pl?borrowernumber=' +
                             data.patron_id +
                             '">' +
                             data.surname +
                             "(" +
                             data.cardnumber +
                             ")"
                     ) +
                     "</div>"
             );
            //  create_form_cardnumber_input.val(data.cardnumber);
         },
         error: function (data) {
             console.log(data);
             $("#user-submit-spinner").hide();
             $("#addQuickAddUserModal").modal("hide");
             $("#interlibraryloans").before(
                 '<div class="dialog alert">' +
                     __(
                         "There was an error creating the patron: </br> <strong>" +
                             (data.responseJSON.error
                                 ? data.responseJSON.error
                                 : data.responseJSON.errors
                                       .map((e) => e.path + " " + e.message)
                                       .join("</br>")) +
                             "</strong>"
                     ) +
                     "</div>"
             );
         },
     });
 }
});
