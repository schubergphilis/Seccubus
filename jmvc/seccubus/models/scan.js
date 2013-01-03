steal('jquery/model', function(){

/**
 * @class Seccubus.Models.Scan
 * @parent Scan
 * @inherits jQuery.Model
 * Wraps backend scan services.  
 */
$.Model('Seccubus.Models.Scan',
/* @Static */
{
	/*
	 * @function findAll
	 * @param {Object} params
	 * Parameters of the API call
	 * @param {Function} success
	 * Callback funciton in case of success
	 * @param {Function} error
	 * Callback function in case of error
	 * @return {Deferred} A deferred Scans (Scan.List)
	 */
	findAll : function(params,success,error){
		return $.ajax({
			url	: "json/getScans.pl",
			type	: "POST",
			dataType: "json scan.models",
			data	: params,
			success	: success,
			error	: error
		});
	},
  	// Not implemented
	//findOne	: "/scans/{id}.json", 
  	create	: "POST json/createScan.pl",
	update	: "POST json/updateScan.pl"
  	// Not implemented yet
	//destroy	: "/scans/{id}.json"
},
/* @Prototype */
{});

})
