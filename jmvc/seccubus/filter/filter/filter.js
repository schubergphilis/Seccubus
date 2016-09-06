/*
 * Copyright 2016 Frank Breedijk, Petr
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
steal(	'jquery/controller',
	'jquery/view/ejs',
	'jquery/controller/view',
	'seccubus/models' )
.then(	'./views/init.ejs',
	'./views/error.ejs',
function($){

/**
 * @class Seccubus.Finding.Filter
 * @parent Finding
 * @inherits jQuery.Controller
 * This controller renders a filter from the findings model and rerenders itself
 * on changes to the model
 */
$.Controller('Seccubus.Filter.Filter',
/** @Static */
{
	/*
	 * @attribute options
	 * Object that holds the options
	 */
	defaults : {
		/*
		 * @attribute options.workspace
		 * Determines which workspace is selected
		 * - Default value: -1
		 * - Special value: -1 - No workspace selected
		 */
		workspace	: -1,
		/*
		 * @attribute options.scans
		 * Array of selected scans
		 * - Default value: null
		 * - Special value: null - no scans selected
		 */
		scans		: null,
		/*
		 * @attribute options.status
		 * Integer that determines the current status of the gui
		 * - Default value: 1
		 */
		status		: 1,
		/*
		 * @attribute options.host
		 * Value of the host filter
		 */
		host		: "*",
		/*
		 * @attribute options.hostName
		 * Value of the hostName filter
		 */
		hostName	: "*",
		/*
		 * @attribute options.port
		 * Value of the port filter
		 */
		port		: "*",
		/*
		 * @attribute options.plugin
		 * Value of the plugin filter
		 */
		plugin		: "*",
		/*
		 * @attribute options.severity
		 * Value of the severity filter
		 */
		severity	: "*",
		/*
		 * @attribute options.finding
		 * Value of the finding filter
		 */
		finding		: "",
		/*
		 * @attribute options.remark
		 * Value of the remark filter
		 */
		remark		: "",		
		/*
		 * @attribute options.issue
		 * Value of the issue filter
		 */
		issue		: "*",		
		/* @attribute options.limit
		 * Value of the limit filter
		 */
		limit 		: 200,
		/*
		 * @attribute options.onChange
		 * Function to be executed when the filter changes
		 */
		onChange 	: function(filter) { },
		/*
		 * @attribute options.updateOnChange
		 * Boolean that indicates is the control should update itself 
		 * when its value changes.
		 */
		updateOnChange	: true
	}
},
/** @Prototype */
{
	init : function(){
		this.updateView();
	},
	'.clearFilter click' : function() {
		$('select.filter').val("*");
		$('input.filter').val("");
		this.options.host = "*";
		this.options.hostName = "*";
		this.options.port = "*";
		this.options.plugin = "*";
		this.options.severity = "*";
		this.options.finding = "";
		this.options.remark = "";
		this.options.issue = "*";
		this.options.limit = 200;
		this.options.onChange({
			host		: this.options.host,
			hostName	: this.options.hostName,
			port		: this.options.port,
			plugin		: this.options.plugin,
			severity	: this.options.severity,
			finding		: this.options.finding,
			remark		: this.options.remark,
			issue		: this.options.issue,
			limit       : this.options.limit
		});
		if ( this.options.updateOnChange ) {
			this.updateView();
		}
	},
	'.filter change' : function(el) {
		console.log("Change" + el.attr("filter"));
		this.options[el.attr("filter")] = el.val();
		this.options.onChange({
			host		: this.options.host,
			hostName	: this.options.hostName,
			port		: this.options.port,
			plugin		: this.options.plugin,
			severity	: this.options.severity,
			finding		: this.options.finding,
			remark		: this.options.remark,
			issue		: this.options.issue,
			limit       : this.options.limit
		});
		if ( this.options.updateOnChange ) {
			this.updateView();
		}
	},
	updateView : function() {
		if ( this.options.workspace < 0  ) {
			this.element.html(
				this.view('error', {sStatus : this.options.status})
			);
		} else if ( this.options.scans == null && this.options.assets == null ) {
			this.element.html(
				this.view('error', {sStatus : this.options.status})
			);
		} else {
			this.element.html(
				this.view(
					'init',
					Seccubus.Models.Filter.findAll({
						workspaceId	: this.options.workspace,
						scanIds		: this.options.scans,
						assetIds	: this.options.assets,
						Status		: this.options.status,
						Host		: this.options.host,
						HostName	: this.options.hostName,
						Port		: this.options.port,
						Plugin		: this.options.plugin,
						Severity	: this.options.severity,
						Finding		: this.options.finding,
						Remark		: this.options.remark,
						Issue 		: this.options.issue
					}), 
					{
						fScans 		: this.options.scans,
						fStatus 	: this.options.status,
						fHost 		: this.options.host,
						fHostName 	: this.options.hostName,
						fPort 		: this.options.port,
						fPlugin 	: this.options.plugin,
						fSeverity 	: this.options.severity,
						fFinding 	: this.options.finding,
						fRemark 	: this.options.remark,
						fIssue 		: this.options.issue,
						fLimit      : this.options.limit
					}
				)
			);
		}
	},
	"{Seccubus.Models.Finding} created" : function(Finding, ev, finding) {
		this.updateView();
	},
	"{Seccubus.Models.Finding} updated" : function(Finding, ev, finding) {
		if ( ! finding.bulk ) {
			this.updateView();
		}
	},
	"{Seccubus.Models.Finding} destroyed" : function(Finding, ev, finding) {
		this.updateView();
	},
	update : function(options){
		this._super(options);
		this.updateView();
	},
	getStatus : function() {
		return this.options.status;
	}
}) // Controller

}); // Steal
