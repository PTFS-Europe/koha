$('#editBookingModal').on('show.bs.modal', function(e) {
    var button = $(e.relatedTarget);
    var booking_id = button.data(booking);

    var booking = $.ajax({
        url: '/api/v1/bookings/' + booking_id,
        dataType: 'json',
        type: 'GET'
    });

    $.when(booking).then(

    );

    // Item select2
    $("#booking_item_id").select2({
        dropdownParent: $(".modal-content", "#editBookingModal"),
        width: '30%',
        dropdownAutoWidth: true,
        minimumResultsForSearch: 20,
        editholder: "Select item"
    });

    // Adopt flatpickr and update mode and onClose
    var periodPicker = $("#period").get(0)._flatpickr;
    periodPicker.set('mode', 'range');
    periodPicker.set('onClose', function(selectedDates, dateStr, instance) {
        var dateArr = selectedDates.map(function(date) {
            return date.toISOString();
        });
        $('#booking_start_date').val(dateArr[0]);
        $('#booking_end_date').val(dateArr[1]);
    });

    // Fetch list of bookable items
    var items = $.ajax({
        url: '/api/v1/biblios/' + biblionumber + '/items?bookable=1' + '&_per_page=-1',
        dataType: 'json',
        type: 'GET'
    });

    // Fetch list of existing bookings
    var bookings = $.ajax({
        url: '/api/v1/bookings?biblio_id=' + biblionumber,
        dataType: 'json',
        type: 'GET'
    });

    // Update item select2 and period flatpickr
    $.when(items, bookings).then(
        function(items,bookings){
            var bookable = 0;
            for (item of items[0]) {
                bookable++;
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

            // Redraw select with new options
            $('#booking_item_id').trigger('change');

            // Set disabled dates in datepicker
            periodPicker.set('disable', [ function(date) {
                var booked = 0;
                for (booking of bookings[0]) {
                    var start_date = flatpickr.parseDate(booking.start_date);
                    var end_date = flatpickr.parseDate(booking.end_date);
                    // continue if booking wont overlap
                    if ( date >= end_date ) {
                        continue;
                    }

                    // booking overlaps
                    if ( date >= start_date && date <= end_date ) {
                        // same item, disable date
                        if ( itemnumber == booking.item_id ) {
                            return true;
                        }
                        // different item, count
                        else {
                            booked++;
                            if ( booked = bookable ) {
                                return true;
                            }
                        }
                    }
                }
            } ]);

            // Enable flatpickr now we have date function populated
            $("#period").prop('disabled', false);

            // Setup listener for item select2
            $('#booking_item_id').on('select2:select', function(e) {
                itemnumber = e.params.data.id ? e.params.data.id : null;
                periodPicker.redraw();
            });
        },
        function(jqXHR, textStatus, errorThrown){
            console.log("Fetch failed");
        }
    );
});

$("#editBookingForm").on('submit', function(e) {
    e.preventDefault();

    var url = '/api/v1/bookings';

    var start_date = $('#booking_start_date').val();
    var end_date = $('#booking_end_date').val();
    var item_id = $('#booking_item_id').val();

    var posting = $.post(
        url,
        JSON.stringify({
            "start_date": start_date,
            "end_date": end_date,
            "biblio_id": $('#booking_biblio_id').val(),
            "item_id": item_id != 0 ? item_id : null,
            "patron_id": $('#booking_patron_id').find(':selected').val()
        })
    );

    posting.done(function(data) {
        $('#editBookingModal').modal('hide');
    });

    posting.fail(function(data) {
        $('#booking_result').reeditWith('<div id="booking_result" class="alert alert-danger">Failure</div>');
    });
});
