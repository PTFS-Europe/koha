function update_picker(periodPicker, biblionumber, itemnumber) {

    // Disable input whilst we fetch dates
    $("#period").prop('disabled', true);

    // Fetch dates and re-enable input
    if (itemnumber) {
        $.ajax({
            url: '/api/v1/bookings?item_id=' + itemnumber,
            async: true,
            success: function(data) {
                var dates_to_disable = [];
                for (booking of data) {
                    dates_to_disable.push({
                        from: booking.start_date,
                        to: booking.end_date
                    });
                }
                periodPicker.set('disable', dates_to_disable);
                $("#period").prop('disabled', false);
            }
        });
    } else {
        $.ajax({
            url: '/api/v1/bookings?biblio_id=' + biblionumber,
            async: true,
            success: function(data) {
                var dates_to_disable = [];
                for (booking of data) {
                    dates_to_disable.push({
                        from: booking.start_date,
                        to: booking.end_date
                    });
                }
                periodPicker.set('disable', dates_to_disable);
                $("#period").prop('disabled', false);
            }
        });
    }
};

$('#placeBookingModal').on('show.bs.modal', function(e) {
    var button = $(e.relatedTarget);
    var biblionumber = button.data('biblionumber');
    var itemnumber = button.data('itemnumber');
    $('#booking_biblio_id').val(biblionumber);

    $("#booking_patron_id").select2({
        dropdownParent: $(".modal-content", "#placeBookingModal"),
        width: '30%',
        dropdownAutoWidth: true,
        allowClear: true,
        minimumInputLength: 3,
        ajax: {
            url: '/api/v1/patrons',
            delay: 250,
            dataType: 'json',
            data: function(params) {
                var search_term = (params.term === undefined) ? '' : params.term;
                var query = {
                    'q': JSON.stringify({
                        "-or": [{
                                "firstname": {
                                    "-like": search_term + '%'
                                }
                            },
                            {
                                "surname": {
                                    "-like": search_term + '%'
                                }
                            },
                            {
                                "cardnumber": {
                                    "-like": search_term + '%'
                                }
                            }
                        ]
                    }),
                    '_order_by': 'firstname'
                };
                return query;
            },
            processResults: function(data) {
                var results = [];
                data.forEach(function(patron) {
                    results.push({
                        "id": patron.patron_id,
                        "text": escape_str(patron.firstname) + " " + escape_str(patron.surname) + " (" + escape_str(patron.cardnumber) + ")"
                    });
                });
                return {
                    "results": results
                };
            }
        },
        placeholder: "Search for a patron"
    });

    $("#booking_item_id").select2({
        dropdownParent: $(".modal-content", "#placeBookingModal"),
        width: '30%',
        dropdownAutoWidth: true,
        minimumResultsForSearch: 20,
        placeholder: "Select item"
    });

    $.ajax({
        url: '/api/v1/biblios/' + biblionumber + '/items',
        async: true,
        success: function(data) {
            for (item of data) {
                // Set the value, creating a new option if necessary
                if (!($('#booking_item_id').find("option[value='" + item.item_id + "']").length)) {
                    if (itemnumber && itemnumber == item.item_id) {
                        // Create a DOM Option and pre-select by default
                        var newOption = new Option(escape_str(item.external_id), item.item_id, true, true);
                        // Append it to the select
                        $('#booking_item_id').append(newOption);
                    } else {
                        // Create a DOM Option and de-select by default
                        var newOption = new Option(escape_str(item.external_id), item.item_id, false, false);
                        // Append it to the select
                        $('#booking_item_id').append(newOption);
                    }
                }
            }
            $('#booking_item_id').trigger('change');
        }
    });

    var periodPicker = $("#period").get(0)._flatpickr;
    periodPicker.set('mode', 'range');
    periodPicker.set('onChange', function(selectedDates, dateStr, instance) {
        var dateArr = selectedDates.map(function(date) {
            return instance.formatDate(date, 'Y-m-d');
        });
        $('#booking_start_date').val(dateArr[0]);
        $('#booking_end_date').val(dateArr[1]);
    });

    // Get blocked dates
    update_picker(periodPicker, biblionumber, itemnumber);

    // Listen for item selection
    $('#booking_item_id').on('select2:select', function(e) {
        // Refresh blocked dates
        update_picker(periodPicker, $("#booking_biblio_id").val(), e.params.data.id);
    });
});

$("#placeBookingForm").on('submit', function(e) {
    e.preventDefault();

    var url = '/api/v1/bookings';

    var start_date = $datetime($('#booking_start_date').val(), {
        dateformat: "rfc3339"
    });
    var end_date = $datetime($('#booking_end_date').val(), {
        dateformat: "rfc3339"
    });

    var posting = $.post(
        url,
        JSON.stringify({
            "start_date": start_date,
            "end_date": end_date,
            "biblio_id": $('#booking_biblio_id').val(),
            "item_id": $('#booking_item_id').val() ? $('#booking_item_id').val() : null,
            "patron_id": $('#booking_patron_id').find(':selected').val()
        })
    );

    posting.done(function(data) {
        $('#placeBookingModal').modal('hide');
    });

    posting.fail(function(data) {
        $('#result').replaceWith('<div id="result" class="alert alert-danger">Failure</div>');
    });
});
