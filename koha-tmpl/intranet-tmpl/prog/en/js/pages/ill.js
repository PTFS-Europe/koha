(function() {
    var app = angular.module('ill', [ ]);

    app.controller( 'searchController', [ '$scope', '$http', function($scope, $http){
        $scope.submit = function() {
            console.log($scope.query);
            $http.get('/cgi-bin/koha/svc/ill?query='+$scope.query).success( function(reply) {
                $scope.results = reply;
                console.log(reply);
            });
        };

        $scope.request = function(requestID) {
            console.log(requestID);

        };

    } ]);

})();
