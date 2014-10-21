(function() {
    var app = angular.module('ill', [ 'preloaded' ]);

    app.factory( 'requestFactory', [ '$http', function($http){
        var requestFactory = {};
        var urlBase = '/cgi-bin/koha/svc/ill';

        requestFactory.getRequests = function(borrowernumber){
            return $http.get(urlBase, { params: { 'borrowernumber': borrowernumber } });
        };

        requestFactory.getRequest = function(id){
            return $http.get(urlBase + '/' + id);
        };

        requestFactory.insertRequest = function(request){
            return $http.post(urlBase, request);
        };

        requestFactory.updateRequest = function(request){
            return $http.put(urlBase + '/' + request.id, request);

        };

        requestFactory.deleteRequest = function(id){
            return $http.delete(urlBase + '/' + request.id);

        };

        requestFactory.searchProvider = function(query){
            return $http.get(urlBase + '?query=' + query);
        };

        return requestFactory;

    } ]);

    app.controller( 'requestController', [ '$scope', 'requestFactory', 'preloaded', function($scope, requestFactory, preloaded){
        $scope.borrowernumber = preloaded.borrowernumber;
        $scope.requests = [];
        $scope.status;

        console.log($scope.borrowernumber);

        getRequests();

        function getRequests() {
            console.log("getRequests");
            requestFactory.getRequests($scope.borrowernumber)
            .success(function (requests) {
                console.log(requests);
                $scope.requests = requests;
            })
            .error(function (error) {
                console.log("error")
                $scope.status = 'Unable to load request data: ' + error.message;
            });
        }

        $scope.search = function() {
            console.log("search");
            console.log($scope.query);
            requestFactory.searchProvider($scope.query).success( function(reply) {
                $scope.results = reply;
                console.log(reply);
            });
        };

        $scope.submit = function(requestID) {
            console.log("submit");
            console.log(requestID);

            var request;
            for (var i = 0; i < $scope.results.length; i++) {
                var currResult = $scope.results[i];
                if (currResult.uin[1] === requestID) {
                    request = currResult;
                    // remove once api is working
                    $scope.requests.push(request);
                    console.log($scope.requests);
                    // end remove
                    break;
                }
            }

            requestFactory.insertRequest(request)
                .success(function () {
                    $scope.status = 'Inserted Request! Refreshing request list.';
                    $scope.requests.push(request);
                })
                .error(function(error) {
                    $scope.status = 'Unable to insert request: ' + error.message;
                });

        };

    } ]);

})();
