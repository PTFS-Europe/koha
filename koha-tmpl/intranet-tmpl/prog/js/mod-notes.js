$(document).ready(function() {

    // Populate all ordernumbers
    var all = {};
    $('.edit_note').each(function() {
        var ordernumber = $(this).data('ordernumber');
        all[ordernumber] = 1;
    });
    $('#orders_all_vendor').val(Object.keys(all).join(','));
    $('#orders_all_internal').val(Object.keys(all).join(','));

    // Populate checkboxes
    $('#orders tbody tr').each(function() {
        var el = $(this).find('>:first-child');
        var val = el.text().replace(/\D/g, '');
        el.prepend('<input class="order-select" type="checkbox" value="'+val+'" />');
    });

    // Add select / deselect all buttons
    var afterTarget = $('#acqui_basket_content h2');
    var afterContent = $('<div><button id="select_all_orders" type="button">Select all</button> <button id="deselect_all_orders" type="button">Deselect all</button></div>');
    afterContent.insertAfter(afterTarget);
    $('#select_all_orders').click(function() {
        $('.order-select').prop('checked', true);
        populateSelected();        
    });
    $('#deselect_all_orders').click(function() {
        $('.order-select').prop('checked', false);
        populateSelected();        
    });

    // Event listeners for checkboxes
    $('.order-select').click(function() {
        populateSelected();        
    });

    var populateSelected = function() {
        var selected = [];
        $('.order-select').each(function() {
            if ($(this).prop('checked')) {
                selected.push($(this).val());
            }
        });
        $('#orders_modified_vendor').val(selected.join(','));
        $('#orders_modified_internal').val(selected.join(','));
        showHideSubmit(selected);
    };

    // Show and hide our action buttons as appropriate
    var showHideSubmit = function(list) {
        if (list.length > 0) {
            $('.btn_add_notes').show();
            $('.btn_clear_notes').hide();
        } else {
            $('.btn_add_notes').hide();
            $('.btn_clear_notes').show();
        }
    };

});
