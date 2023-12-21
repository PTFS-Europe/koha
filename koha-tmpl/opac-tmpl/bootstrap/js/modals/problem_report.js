$(document).ready(function() {

    // Detect that we were redirected here after login and re-open modal
    let urlParams = new URLSearchParams(window.location.search);
    if (urlParams.has('modal')) {
        let modal = urlParams.get('modal');
        history.replaceState && history.replaceState(
            null, '', location.pathname + location.search.replace(/[\?&]modal=[^&]+/, '').replace(/^&/, '?')
        );
        if (modal == 'problem') {
            $("#reportProblemModal").modal('show');
        }
    }

    $('#reportProblemModal').on('show.bs.modal', function(e) {
        // Redirect to login modal if not logged in
        if (logged_in_user_id === "") {
            $('#modalAuth').append('<input type="hidden" name="return" value="' + window.location.pathname + window.location.search + '&modal=problem" />');
            $('#loginModal').modal('show');
            return false;
        }

        $('.addConfirm').prop('disabled', false);
    });

    $('#reportProblemModal').on('click', '.addConfirm', function(e) {
        let problem_title = $('#problem_subject').val();
        let problem_body = $('#problem_body').val();
        let reporter_id = $('#problem_reporter').val();

        params = {
            source: 'opac_problem',
            title: problem_title,
            body: problem_body,
            biblio_id: null,
            reporter_id: reporter_id,
            extended_attributes: [
                { 
                    field_id: 1,
                    value: window.location.pathname + window.location.search
                }
            ]
        };

        $('#problem-submit-spinner').show();
        $('.addConfirm').prop('disabled', true);
        $.ajax({
            url: '/api/v1/public/tickets',
            type: 'POST',
            data: JSON.stringify(params),
            success: function(data) {
                $('#problem-submit-spinner').hide();
                $('#reportProblemModal').modal('hide');
                $('#problem_body').val('');
                $('#problem_title').val('');
                $('h1:first').before('<div class="alert alert-success">' + __("Your problem was sucessfully submitted.") + '</div>');
            },
            error: function(data) {
                $('#problem-submit-spinner').hide();
                $('#reportProblemModal').modal('hide');
                $('h1:first').before('<div class="alert alert-error">' + __("There was an error when submitting your problem, please contact a librarian.") + '</div>');
            },
            contentType: "json"
        });
    });
});
